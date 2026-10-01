import 'dart:convert';

import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const actor = '4687b936-6d19-4d6e-8b2b-dbe47b5f639c';
const expense = '00000000-0000-4000-8000-000000000002';
const attempt = '00000000-0000-4000-8000-000000000003';
Map<String, dynamic> session() => {
  'access_token': [
    base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))),
    base64Url.encode(
      utf8.encode(jsonEncode({'sub': actor, 'exp': 1893456000})),
    ),
    'synthetic-signature',
  ].join('.'),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'synthetic-refresh',
  'user': {
    'id': actor,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'fixture@example.test',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-10-01T00:00:00Z',
  },
};
void main() {
  for (final mode in ['found', 'missing', 'forbidden']) {
    test(
      'outcome is filtered to authenticated donor, expense and key: $mode',
      () async {
        final requests = <http.Request>[];
        final transport = MockClient((request) async {
          if (request.url.path.startsWith('/auth/')) {
            return http.Response(
              jsonEncode(session()),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          requests.add(request);
          if (mode == 'forbidden') {
            return http.Response(
              jsonEncode({'code': '42501', 'message': 'access denied'}),
              403,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode(
              mode == 'missing'
                  ? []
                  : [
                      {
                        'idempotency_key': attempt,
                        'expense_id': expense,
                        'donor_id': actor,
                        'payment_status': 'confirmed',
                        'gross_cents': 7525,
                      },
                    ],
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
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
        final repo = PaymentRepository(client);
        if (mode == 'forbidden') {
          await expectLater(
            repo.outcome(expense, attempt),
            throwsA(isA<PostgrestException>()),
          );
        } else {
          final result = await repo.outcome(expense, attempt);
          expect(result?['gross_cents'], mode == 'found' ? 7525 : isNull);
        }
        expect(requests.length, 1);
        expect(requests.single.url.path, '/rest/v1/dopmi_donations');
        expect(requests.single.url.queryParameters['donor_id'], 'eq.$actor');
        expect(
          requests.single.url.queryParameters['expense_id'],
          'eq.$expense',
        );
        expect(
          requests.single.url.queryParameters['idempotency_key'],
          'eq.$attempt',
        );
        expect(
          requests.single.url.queryParameters.containsKey('offset'),
          isFalse,
        );
      },
    );
  }
  test('anonymous outcome is rejected before any request', () async {
    var calls = 0;
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    await expectLater(
      PaymentRepository(client).outcome(expense, attempt),
      throwsFormatException,
    );
    expect(calls, 0);
  });
}
