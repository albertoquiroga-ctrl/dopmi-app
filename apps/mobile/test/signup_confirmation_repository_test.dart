import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final recovery in [false, true]) {
    test(
      'confirmation returns its Auth response actor (recovery: $recovery)',
      () async {
        SharedPreferences.setMockInitialValues({});
        const actor = '00000000-0000-4000-8000-000000000001';
        final client = SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(request.url.path, '/auth/v1/verify');
            expect(
              jsonDecode(request.body)['type'],
              recovery ? 'recovery' : 'signup',
            );
            return http.Response(
              jsonEncode({
                'id': actor,
                'aud': 'authenticated',
                'email': 'fixture@example.test',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-11-24T00:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseIdentityRepository(
          client,
          const AppConfig(url: '', key: '', redirect: ''),
          await SharedPreferences.getInstance(),
        );
        expect(
          await repository.confirmCode(
            'fixture@example.test',
            '123456',
            recovery: recovery,
          ),
          actor,
        );
        // No session was returned: proof must come from this response, rather
        // than reading whatever account is current after an asynchronous hop.
        expect(repository.current, isNull);
      },
    );
  }
}
