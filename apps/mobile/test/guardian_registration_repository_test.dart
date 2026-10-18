import 'dart:convert';

import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_repository_test.dart' show session;

const registrationId = '72000000-0000-4000-8000-000000000001';
const registrationKey = '72000000-0000-4000-8000-000000000002';
const setupSecret = 'seti_synthetic_secret_synthetic';

Map<String, dynamic> projection(String status) => {
  'id': registrationId,
  'key': registrationKey,
  'status': status,
  'gross_cents': 2000,
  'revision': 1,
  'registered_at': '2026-10-15T12:00:00Z',
  'next_evaluation_at': status == 'canceled' ? null : '2026-11-15T12:00:00Z',
  'consent_version': guardianRegistrationConsent,
  'payment': {
    'state': 'not_evaluated',
    'attempt_id': null,
    'allocated_cents': 0,
    'refund_cents': 0,
  },
};
Map<String, dynamic> receipt() => {
  'id': registrationId,
  'key': registrationKey,
  'gross_cents': 2000,
  'status': 'method_pending',
  'method_status': 'requires_payment_method',
  'setup_client_secret': setupSecret,
};
Map<String, dynamic> draft() => {
  'key': registrationKey,
  'gross_cents': 2000,
  'consent': true,
  'method_consent': true,
  'owner_id': 'foreign',
  'customer_id': 'foreign',
};

void main() {
  Future<SupabaseClient> clientFor(
    Object? Function(http.Request) response,
  ) async {
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
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
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
    return client;
  }

  test('legal snapshot reads only owner RPC even with pending setup', () async {
    final requests = <http.Request>[];
    final client = await clientFor((request) {
      requests.add(request);
      return projection('method_pending');
    });
    final snapshot = await GuardianRepository(client).registrationSnapshot();
    expect(snapshot!.status, 'method_pending');
    expect(requests, hasLength(1));
    expect(
      requests.single.url.path,
      '/rest/v1/rpc/dopmi_guardian_registration_cancellation_state',
    );
    expect(requests.single.headers['authorization'], startsWith('Bearer '));
    expect(
      requests.any((request) => request.url.path.contains('/functions/')),
      isFalse,
    );
    expect(requests.single.method, 'POST');
    expect(requests.single.url.queryParameters, isEmpty);
    expect(jsonDecode(requests.single.body), isNull);
  });

  test('native registration returns only transient setup secret and owner-scoped request', () async {
    final requests = <http.Request>[];
    final client = await clientFor((request) {
      requests.add(request);
      return {
        ...receipt(),
        'customer_id': 'cus_private',
        'owner_id': 'foreign',
      };
    });
    final repo = GuardianRepository(client);
    for (var i = 0; i < 2; i++) {
      final value = await repo.submitRegistration(draft());
      expect(value['setup_client_secret'], setupSecret);
      expect(value['method_status'], 'requires_payment_method');
      expect(value.containsKey('customer_id'), false);
      expect(value.containsKey('owner_id'), false);
    }
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.headers['authorization'], startsWith('Bearer '));
      expect(jsonDecode(request.body), {
        'action': 'register',
        'key': registrationKey,
        'gross_cents': 2000,
        'consent': true,
        'consent_version': guardianRegistrationConsent,
        'method_consent': true,
        'method_consent_version': savedCardConsent,
      });
    }
  });

  test(
    'mismatched native or ambiguous hosted receipt cannot open a sheet',
    () async {
      Map<String, dynamic> value = receipt();
      final client = await clientFor((_) => value);
      final repo = GuardianRepository(client);
      for (final delta in [
        {'setup_client_secret': 'pi_synthetic_secret_synthetic'},
        {'setup_client_secret': 'secret'},
        {'method_status': 'processing'},
        {'method_status': 'succeeded'},
        {'method_status': 'invented'},
        {'status': 'registered'},
        {'checkout_url': 'https://checkout.stripe.com/synthetic'},
        {'key': 'foreign'},
        {'gross_cents': 5000},
      ]) {
        value = {...receipt(), ...delta};
        await expectLater(
          repo.submitRegistration(draft()),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'processing and legacy hosted receipts stay pending without an SDK secret',
    () async {
      Map<String, dynamic> value = receipt();
      final client = await clientFor((_) => value);
      final repo = GuardianRepository(client);
      for (final status in ['processing', 'succeeded', 'canceled', 'expired']) {
        value = {
          ...receipt(),
          'method_status': status,
          'setup_client_secret': null,
        };
        expect(
          (await repo.submitRegistration(draft()))['setup_client_secret'],
          isNull,
        );
      }
      value = {
        ...receipt(),
        'method_status': 'pending',
        'setup_client_secret': null,
        'checkout_url': 'https://checkout.stripe.com/synthetic',
      };
      expect(
        (await repo.submitRegistration(draft()))['checkout_url'],
        value['checkout_url'],
      );
    },
  );

  test('pending method reconciles existing server intent then reads complete projection', () async {
    final requests = <http.Request>[];
    var reads = 0;
    final client = await clientFor((request) {
      requests.add(request);
      if (request.url.path.endsWith('/dopmi_guardian_registration_state')) {
        reads++;
        return projection(reads == 1 ? 'method_pending' : 'registered');
      }
      expect(jsonDecode(request.body), {
        'action': 'registration_status',
        'id': registrationId,
      });
      return {
        'id': registrationId,
        'status': 'registered',
        'setup_client_secret': 'must-not-retain',
      };
    });
    final result = await GuardianRepository(client).registrationState();
    expect(reads, 2);
    expect(requests, hasLength(3));
    expect(result!.status, 'registered');
    expect(result.hasConfirmedImpact, false);
  });

  test(
    'foreign reconciliation receipt fails closed without a fallback projection',
    () async {
      var reads = 0;
      final client = await clientFor((request) {
        if (request.url.path.endsWith('/dopmi_guardian_registration_state')) {
          reads++;
          return projection('method_pending');
        }
        return {'id': 'foreign', 'status': 'registered'};
      });
      await expectLater(
        GuardianRepository(client).registrationState(),
        throwsFormatException,
      );
      expect(reads, 1);
    },
  );
}
