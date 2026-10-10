import 'dart:convert';

import 'package:dopmi_mobile/features/payments/native_wallet_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_repository_test.dart' show session;

void main() {
  const key = '00000000-0000-4000-8000-000000000003';
  for (final provider in ['apple_pay', 'google_pay']) {
    test(
      '$provider preserves authenticated intent and separates transient secret',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic-key',
          httpClient: MockClient((request) async {
            final auth = request.url.path.startsWith('/auth/');
            if (!auth) requests.add(request);
            return http.Response(
              jsonEncode(
                auth
                    ? session()
                    : {
                        'key': key,
                        'wallet_type': provider,
                        'status': 'pending',
                        'card_id': null,
                        'setup_client_secret': 'seti_fixture_secret_fixture',
                        'customer_id': 'must-not-retain',
                      },
              ),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: 'fixture@example.test',
          password: 'synthetic-password',
        );
        final repo = NativeWalletRepository(client);
        final intent = <String, dynamic>{
          'key': key,
          'wallet_type': provider,
          'consent_version': savedCardConsent,
          'owner_id': 'foreign',
          'customer_id': 'foreign',
        };
        final result = await repo.submit(intent);
        expect(result['setup_client_secret'], 'seti_fixture_secret_fixture');
        expect(result.containsKey('customer_id'), false);
        await repo.submit(intent);
        for (final request in requests) {
          expect(request.headers['authorization'], startsWith('Bearer '));
          expect(jsonDecode(request.body), {
            'action': 'add_wallet',
            'key': key,
            'wallet_type': provider,
            'consent': true,
            'consent_version': savedCardConsent,
          });
        }
        final receipt = await repo.state();
        expect(receipt, {
          'key': key,
          'wallet_type': provider,
          'status': 'pending',
          'card_id': null,
        });
        expect(requests.last.url.path, '/rest/v1/rpc/dopmi_saved_wallet_state');
      },
    );
  }
  test(
    'owner receipt rejects invented outcomes and does not retain secrets',
    () {
      final base = {
        'key': key,
        'wallet_type': 'google_pay',
        'status': 'pending',
        'card_id': null,
      };
      expect(
        nativeWalletReceipt({...base, 'setup_client_secret': 'secret'}),
        base,
      );
      for (final change in [
        {'key': 'invalid'},
        {'wallet_type': 'card'},
        {'status': 'succeeded'},
        {'status': 'saved'},
        {'card_id': 'pm_unconfirmed'},
        {'status': 'saved', 'card_id': 'foreign'},
      ]) {
        expect(
          () => nativeWalletReceipt({...base, ...change}),
          throwsFormatException,
        );
      }
      expect(
        nativeWalletReceipt({
          ...base,
          'status': 'saved',
          'card_id': 'pm_fixture',
        })['card_id'],
        'pm_fixture',
      );
    },
  );
}
