import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/native_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlledNativeIdentity implements NativeIdentity {
  final pending = Completer<NativeIdentityCredential?>();
  int calls = 0;
  @override
  bool supports(String provider) => true;
  @override
  Future<NativeIdentityCredential?> authenticate(String provider) {
    calls++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late ControlledNativeIdentity native;
  late SupabaseIdentityRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient(
      'http://127.0.0.1:54321',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    native = ControlledNativeIdentity();
    repository = SupabaseIdentityRepository(
      client,
      const AppConfig(
        url: 'http://127.0.0.1:54321',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleEnabled: true,
      ),
      await SharedPreferences.getInstance(),
      nativeIdentity: native,
    );
  });
  tearDown(() async => client.dispose());

  test('unknown and disabled providers never launch authentication', () async {
    await expectLater(repository.oauth('facebook'), throwsStateError);
    await expectLater(repository.oauth('apple'), throwsStateError);
    expect(native.calls, 0);
  });

  test(
    'cancelled native login creates no session and blocks double taps',
    () async {
      final first = repository.oauth('google');
      await repository.oauth('google');
      expect(native.calls, 1);
      native.pending.complete(null);
      await first;
      expect(client.auth.currentSession, isNull);
      await repository.oauth('google');
      expect(native.calls, 2);
    },
  );

  test('Google native login forwards both provider tokens', () async {
    late Map<String, dynamic> requestBody;
    final jwt = [
      base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))),
      base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': '4687b936-6d19-4d6e-8b2b-dbe47b5f639c',
            'exp': 1893456000,
          }),
        ),
      ),
      'signature',
    ].join('.');
    final mockHttp = MockClient((request) async {
      requestBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      return http.Response(
        jsonEncode({
          'access_token': jwt,
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'refresh-token',
          'user': {
            'id': '4687b936-6d19-4d6e-8b2b-dbe47b5f639c',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'user@example.test',
            'app_metadata': {
              'provider': 'google',
              'providers': ['google'],
            },
            'user_metadata': {},
            'created_at': '2026-09-29T21:00:00Z',
            'updated_at': '2026-09-29T21:00:00Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final customClient = SupabaseClient(
      'http://127.0.0.1:54321',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: mockHttp,
    );
    final customNative = ControlledNativeIdentity();
    final customRepository = SupabaseIdentityRepository(
      customClient,
      const AppConfig(
        url: 'http://127.0.0.1:54321',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleEnabled: true,
      ),
      await SharedPreferences.getInstance(),
      nativeIdentity: customNative,
    );

    final login = customRepository.oauth('google');
    customNative.pending.complete(
      const NativeIdentityCredential(
        idToken: 'google-id-token',
        accessToken: 'google-access-token',
      ),
    );
    await login;

    expect(requestBody['id_token'], 'google-id-token');
    expect(requestBody['access_token'], 'google-access-token');
    expect(requestBody['nonce'], isNull);
    await customClient.dispose();
  });
}
