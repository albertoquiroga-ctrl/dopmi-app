import 'dart:convert';

import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_repository_test.dart' show session;

void main() {
  const id = '72000000-0000-4000-8000-000000000001',
      key = '72000000-0000-4000-8000-000000000002';
  final draft = {
    'id': id,
    'key': key,
    'revision': 1,
    'consent': true,
    'consent_version': savedCardConsent,
  };
  test('registration method request preserves the same authorized key and rejects mismatched receipts', () async {
    final requests = <http.Request>[];
    Map<String, dynamic> receipt = {
      'id': id,
      'key': key,
      'status': 'pending',
      'registration_revision': 1,
      'method_status': 'requires_payment_method',
      'setup_client_secret': 'seti_synthetic_secret_synthetic',
    };
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (!request.url.path.startsWith('/auth/')) requests.add(request);
        return http.Response(
          jsonEncode(
            request.url.path.startsWith('/auth/') ? session() : receipt,
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic',
    );
    final repo = GuardianRepository(client);
    await repo.submitRegistrationMethod(draft);
    await repo.registrationMethodStatus(draft);
    expect(jsonDecode(requests[0].body), {
      'action': 'registration_method',
      ...draft,
    });
    expect(jsonDecode(requests[1].body), {
      'action': 'registration_method_status',
      'id': id,
      'key': key,
    });
    final original = Map<String, dynamic>.from(receipt);
    for (final mutation in [
      {'key': 'foreign'},
      {'id': 'foreign'},
      {'registration_revision': 2},
      {'setup_client_secret': 'pi_synthetic_secret_synthetic'},
      {'method_status': 'processing'},
      {'status': 'applied', 'registration_revision': 2},
    ]) {
      receipt = {...original, ...mutation};
      await expectLater(
        repo.submitRegistrationMethod(draft),
        throwsFormatException,
      );
    }
    final before = requests.length;
    await expectLater(
      repo.submitRegistrationMethod({...draft, 'consent': false}),
      throwsFormatException,
    );
    expect(requests.length, before);
  });
}
