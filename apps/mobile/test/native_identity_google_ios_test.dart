import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/native_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/google_sign_in_platform_fake.dart';

const config = AppConfig(
  url: 'http://127.0.0.1:54321',
  key: 'test',
  redirect: 'io.dopmi.app://auth/callback',
  googleEnabled: true,
  googleServerClientId: 'server-client.apps.googleusercontent.com',
  googleIosClientId: 'ios-client.apps.googleusercontent.com',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS Google cancellation and retry keep one shared SDK nonce through Supabase', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final originalPlatform = GoogleSignInPlatform.instance;
    final platform = FakeGoogleSignInPlatform();
    // iOS/AppAuth supplies its own nonce if the app does not supply one.
    platform.sdkGeneratedNonce = 'sdk-nonce-not-known-to-dopmi';
    platform.initializationBarrier = Completer<void>();
    platform.authenticationError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    GoogleSignInPlatform.instance = platform;
    addTearDown(() => GoogleSignInPlatform.instance = originalPlatform);
    SharedPreferences.setMockInitialValues({});
    final requests = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      config.url,
      config.key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/auth/v1/token');
        expect(request.url.queryParameters['grant_type'], 'id_token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        final tokenClaims = jsonDecode(
          utf8.decode(
            base64Url.decode((body['id_token'] as String).split('.')[1]),
          ),
        ) as Map<String, dynamic>;
        final rawNonce = body['nonce'] as String?;
        final tokenNonce = tokenClaims['nonce'] as String?;
        if ((rawNonce == null) != (tokenNonce == null)) {
          return http.Response(
            jsonEncode({
              'code': 'validation_failed',
              'msg': 'Passed nonce and nonce in id_token should either both exist or not',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        if (rawNonce != null &&
            sha256.convert(utf8.encode(rawNonce)).toString() != tokenNonce) {
          return http.Response(
            jsonEncode({'code': 'validation_failed', 'msg': 'Nonces mismatch'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          supabaseSessionResponse(),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseIdentityRepository(
      client,
      config,
      await SharedPreferences.getInstance(),
    );

    final first = repository.oauth('google');
    final secondNative = PlatformNativeIdentity(config);
    final concurrent = secondNative.authenticate('google');
    await Future<void>.delayed(Duration.zero);
    expect(platform.initializations, hasLength(1));
    expect(platform.authentications, isEmpty);
    final originalChallenge = platform.initializations.single.nonce;
    platform.initializationBarrier!.complete();
    await first;
    expect(await concurrent, isNull);
    expect(requests, isEmpty);
    expect(client.auth.currentSession, isNull);

    platform.authenticationError = null;
    await repository.oauth('google');
    final secondCredential = await secondNative.authenticate('google');

    final requestBody = requests.single;
    expect(requestBody['nonce'], isNotNull);
    final rawNonce = requestBody['nonce'] as String;
    final challenge = platform.initializations.single.nonce;
    expect(base64Url.decode(rawNonce), hasLength(32));
    expect(challenge, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(sha256.convert(utf8.encode(rawNonce)).toString(), challenge);
    expect(rawNonce, isNot(challenge));
    expect(challenge, originalChallenge);
    expect(secondCredential?.nonce, rawNonce);
    expect(platform.initializations, hasLength(1));
    final claims = jsonDecode(
      utf8.decode(
        base64Url.decode((requestBody['id_token'] as String).split('.')[1]),
      ),
    ) as Map<String, dynamic>;
    expect(claims['nonce'], challenge);
    expect(requestBody['access_token'], 'google-access-token');
    expect(client.auth.currentUser?.id, '4687b936-6d19-4d6e-8b2b-dbe47b5f639c');

    final authenticationsBeforeMismatch = platform.authentications.length;
    for (final differentConfig in [
      const AppConfig(
        url: 'http://127.0.0.1:54321',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleServerClientId: 'different-server-client',
        googleIosClientId: 'ios-client.apps.googleusercontent.com',
      ),
      const AppConfig(
        url: 'http://127.0.0.1:54321',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleServerClientId: 'server-client.apps.googleusercontent.com',
        googleIosClientId: 'different-ios-client',
      ),
    ]) {
      await expectLater(
        PlatformNativeIdentity(differentConfig).authenticate('google'),
        throwsStateError,
      );
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await expectLater(secondNative.authenticate('google'), throwsStateError);
    expect(platform.initializations, hasLength(1));
    expect(platform.authentications, hasLength(authenticationsBeforeMismatch));
  });
}
