import 'dart:convert';

import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_repository_test.dart' show session;

void main() {
  for (final selected in [false, true]) {
    test(
      'method HTTP authorization and stable retry: selected=$selected',
      () async {
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
            jsonEncode({'status': 'pending'}),
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
          'kind': 'method',
          'key': '00000000-0000-4000-8000-000000000003',
          'revision': 7,
          'consent_version': guardianConsent,
          if (selected) 'selected_method_id': 'pm_saved_fixture',
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
          'action': selected ? 'default_method' : 'method',
          if (selected) 'payment_method_id': 'pm_saved_fixture',
          'key': intent['key'],
          'revision': 7,
          'consent': true,
          'consent_version': guardianConsent,
        });
        expect(jsonDecode(requests.last.body), body);
      },
    );
  }
}
