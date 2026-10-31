import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

/// Replaces only the native SDK boundary; the app-facing Google SDK stays real.
class FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  final initializations = <InitParameters>[];
  final authentications = <AuthenticateParameters>[];
  Completer<void>? initializationBarrier;
  Object? initializationError;
  Object? authenticationError;
  String? sdkGeneratedNonce;

  @override
  Future<void> init(InitParameters params) async {
    initializations.add(params);
    await initializationBarrier?.future;
    if (initializationError case final error?) throw error;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authentications.add(params);
    if (authenticationError case final error?) throw error;
    return AuthenticationResults(
      user: const GoogleSignInUserData(
        email: 'user@example.test',
        id: 'google-test-user',
      ),
      authenticationTokens: AuthenticationTokenData(
        idToken: testJwt({
          'sub': 'google-test-user',
          'nonce': ?(initializations.single.nonce ?? sdkGeneratedNonce),
        }),
      ),
    );
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async =>
      const ClientAuthorizationTokenData(accessToken: 'google-access-token');

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) => throw UnimplementedError();

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) => throw UnimplementedError();

  @override
  Future<void> signOut(SignOutParams params) => throw UnimplementedError();

  @override
  Future<void> disconnect(DisconnectParams params) =>
      throw UnimplementedError();
}

String testJwt(Map<String, Object?> claims) => [
  base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))),
  base64Url.encode(utf8.encode(jsonEncode(claims))),
  'test-signature',
].join('.');

String supabaseSessionResponse() => jsonEncode({
  'access_token': testJwt({
    'sub': '4687b936-6d19-4d6e-8b2b-dbe47b5f639c',
    'exp': 1893456000,
  }),
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
});
