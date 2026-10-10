import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const actor = '4687b936-6d19-4d6e-8b2b-dbe47b5f639c';
  const target = 'new@example.test';
  final user = <String, dynamic>{
    'id': actor,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'old@example.test',
    'email_confirmed_at': '2026-09-29T21:00:00Z',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-09-29T21:00:00Z',
  };
  for (final outcome in [
    'pending',
    'confirmed',
    'missing',
    'denied',
    'foreign',
    'accepted_pending',
    'unacknowledged',
  ]) {
    test('email transport $outcome never repeats the update', () async {
      SharedPreferences.setMockInitialValues({});
      var puts = 0, reads = 0;
      final jwt = [
        base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))),
        base64Url.encode(
          utf8.encode(jsonEncode({'sub': actor, 'exp': 1893456000})),
        ),
        'signature',
      ].join('.');
      http.Response jsonResponse(Object data, [int status = 200]) =>
          http.Response(
            jsonEncode(data),
            status,
            headers: {'content-type': 'application/json'},
          );
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        'test',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MemoryPkceStorage(),
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            return jsonResponse({
              'access_token': jwt,
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'refresh',
              'user': user,
            });
          }
          if (request.method == 'PUT') {
            puts++;
            expect(jsonDecode(request.body)['email'], target);
            expect(
              request.url.queryParameters['redirect_to'],
              'com.mycompany.dopmi://auth/callback',
            );
            if (outcome == 'denied') {
              return jsonResponse({
                'msg': 'denied',
                'code': 'email_exists',
              }, 422);
            }
            if (outcome == 'accepted_pending') {
              return jsonResponse({...user, 'new_email': target});
            }
            if (outcome == 'unacknowledged') return jsonResponse(user);
            throw http.ClientException('response lost');
          }
          expect(request.method, 'GET');
          reads++;
          return jsonResponse({
            ...user,
            if (outcome == 'pending' || outcome == 'foreign')
              'new_email': target,
            if (outcome == 'confirmed') 'email': target,
            if (outcome == 'foreign') 'id': 'other-owner',
          });
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'old@example.test',
        password: 'test',
      );
      final repository = SupabaseIdentityRepository(
        client,
        const AppConfig(
          url: 'http://127.0.0.1:54321',
          key: 'test',
          redirect: 'com.mycompany.dopmi://auth/callback',
        ),
        await SharedPreferences.getInstance(),
      );
      if (outcome == 'pending' ||
          outcome == 'confirmed' ||
          outcome == 'accepted_pending') {
        expect(
          await repository.changeEmail(target),
          outcome != 'confirmed'
              ? EmailChangeStatus.pendingConfirmation
              : EmailChangeStatus.confirmed,
        );
        if (outcome == 'accepted_pending') {
          expect(
            await repository.changeEmail(target),
            EmailChangeStatus.pendingConfirmation,
          );
        }
      } else {
        await expectLater(
          repository.changeEmail(target),
          outcome == 'foreign' || outcome == 'unacknowledged'
              ? throwsStateError
              : throwsA(isA<AuthException>()),
        );
      }
      expect(puts, 1);
      expect(
        reads,
        ['denied', 'accepted_pending', 'unacknowledged'].contains(outcome)
            ? 0
            : 1,
      );
    });
  }
}
