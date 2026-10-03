import 'dart:convert';

import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_repository_test.dart' show session;

void main() {
  for (final action in ['default', 'remove']) {
    test(
      'independent $action HTTP preserves intent and minimizes receipt',
      () async {
        const key = '00000000-0000-4000-8000-000000000003';
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic-key',
          httpClient: MockClient((request) async {
            if (request.url.path.startsWith('/auth/')) {
              return http.Response(
                jsonEncode(session()),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            requests.add(request);
            return http.Response(
              jsonEncode({
                'key': key,
                'action': action,
                'status': 'pending',
                'card_id': 'pm_savedFixture',
                'customer_id': 'must-not-retain',
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: 'fixture@example.test',
          password: 'synthetic-password',
        );
        final repo = GuardianRepository(client);
        final intent = <String, dynamic>{
          'kind': 'saved_card_method',
          'action': action,
          'key': key,
          'selected_method_id': 'pm_savedFixture',
          'consent_version': savedCardMethodConsent,
          'revision': 99,
          'owner_id': 'foreign',
          'customer_id': 'foreign',
        };
        expect(await repo.submit(intent), {
          'key': key,
          'action': action,
          'status': 'pending',
          'card_id': 'pm_savedFixture',
        });
        await repo.submit(intent);
        expect(requests, hasLength(2));
        final expected = {
          'action': action == 'remove'
              ? 'saved_card_remove'
              : 'saved_card_default',
          'key': key,
          'payment_method_id': 'pm_savedFixture',
          'consent': true,
          'consent_version': savedCardMethodConsent,
        };
        for (final request in requests) {
          expect(request.url.path, '/functions/v1/guardian-client');
          expect(request.headers['authorization'], startsWith('Bearer '));
          expect(jsonDecode(request.body), expected);
        }
        expect(await repo.savedCardMethodState(), {
          'key': key,
          'action': action,
          'status': 'pending',
          'card_id': 'pm_savedFixture',
        });
        expect(
          requests.last.url.path,
          '/rest/v1/rpc/dopmi_saved_card_method_state',
        );
        expect(jsonDecode(requests.last.body), isNull);
      },
    );
  }
  test('independent receipt rejects incompatible or invented results', () {
    const key = '00000000-0000-4000-8000-000000000003';
    final base = {
      'key': key,
      'action': 'default',
      'status': 'pending',
      'card_id': 'pm_fixture',
    };
    for (final patch in [
      {'key': 'bad'},
      {'action': 'setup'},
      {'status': 'paid'},
      {'card_id': null},
      {'card_id': 'bad'},
      {'status': 'removed'},
      {'action': 'remove', 'status': 'applied'},
    ]) {
      expect(
        () => savedCardMethodReceipt({...base, ...patch}),
        throwsFormatException,
      );
    }
    expect(savedCardMethodReceipt({...base, 'customer_id': 'secret'}), base);
  });
  for (final mode in ['setup', 'default', 'remove', 'restored-remove', 'add']) {
    final selected = mode == 'default' || mode == 'remove';
    test('method HTTP authorization and stable retry: mode=$mode', () async {
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        if (request.url.path.startsWith('/auth/')) {
          return http.Response(
            jsonEncode(session()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        requests.add(request);
        return http.Response(
          jsonEncode(
            mode == 'add'
                ? {
                    'key': '00000000-0000-4000-8000-000000000003',
                    'status': 'pending',
                    'card_id': null,
                    'checkout_url': 'https://checkout.stripe.com/setup',
                  }
                : {'status': 'pending'},
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        'synthetic-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.test',
        password: 'synthetic-password',
      );
      final repository = GuardianRepository(client);
      final intent = <String, dynamic>{
        'kind': mode == 'add' ? 'add_card' : 'method',
        'key': '00000000-0000-4000-8000-000000000003',
        'revision': 7,
        'consent_version': mode == 'add' ? savedCardConsent : guardianConsent,
        if (selected) 'selected_method_id': 'pm_savedFixture',
        if (mode.contains('remove')) 'remove_saved': true,
        'donor_id': 'untrusted-local-owner',
        'customer_id': 'untrusted-local-customer',
      };
      await repository.submit(intent);
      await repository.submit(intent);
      expect(requests, hasLength(2));
      expect(requests.first.url.path, '/functions/v1/guardian-client');
      expect(requests.first.headers['authorization'], startsWith('Bearer '));
      final body = jsonDecode(requests.first.body);
      expect(body, {
        'action': mode == 'add'
            ? 'add_card'
            : selected
            ? mode == 'remove'
                  ? 'remove_method'
                  : 'default_method'
            : 'method',
        if (selected) 'payment_method_id': 'pm_savedFixture',
        'key': intent['key'],
        if (mode != 'add') 'revision': 7,
        'consent': true,
        'consent_version': mode == 'add' ? savedCardConsent : guardianConsent,
      });
      expect(jsonDecode(requests.last.body), body);
    });
  }
  test('saved-card receipt validates status and card details and omits extra fields', () {
    const key = '00000000-0000-4000-8000-000000000003';
    for (final invalid in [
      null,
      {'key': 'bad', 'status': 'pending'},
      {'key': key, 'status': 'saved'},
      {'key': key, 'status': 'pending', 'card_id': 'pm_added'},
      {'key': key, 'status': 'paid'},
    ]) {
      expect(() => savedCardReceipt(invalid), throwsFormatException);
    }
    expect(
      savedCardReceipt({
        'key': key,
        'status': 'saved',
        'card_id': 'pm_added',
        'client_secret': 'must-not-leave-boundary',
      }),
      {'key': key, 'status': 'saved', 'card_id': 'pm_added'},
    );
  });
}
