import 'dart:convert';

import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_repository_test.dart' show session;

void main() {
  const caseId = '72000000-0000-4000-8000-000000000011';
  const key = '72000000-0000-4000-8000-000000000012';
  const donationId = '72000000-0000-4000-8000-000000000013';
  Future<SupabaseClient> clientFor(
    Object? Function(http.Request request) response,
  ) async {
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.startsWith('/auth/')
                ? session()
                : response(request),
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic',
    );
    return client;
  }

  for (final config in [
    (mode: 'test', consent: 'oneoff-test-2026-10-15'),
    (mode: 'production', consent: 'oneoff-live-2026-10-28'),
  ]) {
    test(
      '${config.mode} case checkout sends one case and gross amount without client allocation instructions',
      () async {
        final requests = <http.Request>[];
        final client = await clientFor((request) {
          requests.add(request);
          return {
            'donation_id': donationId,
            'status': 'pending',
            'payment_client_secret': 'pi_synthetic_secret_synthetic',
          };
        });
        await PaymentRepository(
          client,
          paymentEnvironment: PaymentEnvironment(environment: config.mode),
        ).caseCheckout(caseId, 1000, key);
        expect(jsonDecode(requests.single.body), {
          'action': 'native_case_checkout',
          'case_id': caseId,
          'gross_cents': 1000,
          'key': key,
          'consent': true,
          'consent_version': config.consent,
        });
      },
    );
  }

  test('case receipt remains owner-scoped and reads private allocation snapshots without public context', () async {
    final requests = <http.Request>[];
    final client = await clientFor((request) {
      requests.add(request);
      if (request.url.path.endsWith('/rpc/dopmi_case_payment_allocations')) {
        return [
          {
            'expense_id': 'expense-a',
            'title': 'Consulta',
            'allocated_cents': 6000,
            'reversed_cents': 0,
          },
          {
            'expense_id': 'expense-b',
            'title': 'Medicina',
            'allocated_cents': 3200,
            'reversed_cents': 0,
          },
        ];
      }
      return {
        'id': donationId,
        'case_id': caseId,
        'contribution_scope': 'case',
        'idempotency_key': key,
        'payment_status': 'confirmed',
        'gross_cents': 10000,
        'platform_fee_cents': 200,
        'stripe_fee_cents': 600,
        'allocated_cents': 9200,
      };
    });
    final result = await PaymentRepository(client).caseOutcome(caseId, key);
    final query = requests.first.url.queryParameters;
    expect(query['case_id'], 'eq.$caseId');
    expect(query['contribution_scope'], 'eq.case');
    expect(query['donor_id'], isNotNull);
    expect(query.containsKey('expense_id'), false);
    expect(result!['allocated_cents'], 9200);
    expect((result['case_allocations'] as List).map((row) => row['title']), [
      'Consulta',
      'Medicina',
    ]);
    expect(
      requests.where((request) => request.url.path.contains('/functions/')),
      isEmpty,
    );
  });
}
