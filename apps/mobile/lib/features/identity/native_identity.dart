import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config.dart';

class NativeIdentityCredential {
  const NativeIdentityCredential({
    required this.idToken,
    this.accessToken,
    this.nonce,
    this.authorizationCode,
  });
  final String idToken;
  final String? accessToken, nonce, authorizationCode;
}

abstract interface class NativeIdentity {
  bool supports(String provider);
  Future<NativeIdentityCredential?> authenticate(String provider);
}

typedef _GoogleConfiguration = ({
  TargetPlatform platform,
  String serverClientId,
  String? clientId,
});

class _GoogleSession {
  _GoogleSession(this.configuration)
    : rawNonce = configuration.platform == TargetPlatform.iOS
          ? _newNonce()
          : null {
    initialized = GoogleSignIn.instance.initialize(
      serverClientId: configuration.serverClientId,
      clientId: configuration.clientId,
      nonce: rawNonce == null
          ? null
          : sha256.convert(utf8.encode(rawNonce!)).toString(),
    );
  }

  final _GoogleConfiguration configuration;
  // google_sign_in 7 initializes exactly once. This pair lasts for that SDK
  // cycle (including cancellations/retries), rather than one login attempt.
  final String? rawNonce;
  late final Future<void> initialized;

  static String _newNonce() {
    final random = Random.secure();
    return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  }
}

class PlatformNativeIdentity implements NativeIdentity {
  PlatformNativeIdentity(this.config);
  final AppConfig config;
  static _GoogleSession? _googleSession;
  static const _googleScopes = <String>[
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  @override
  bool supports(String provider) =>
      !kIsWeb &&
      switch (provider) {
        'apple' => defaultTargetPlatform == TargetPlatform.iOS,
        'google' =>
          defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android,
        _ => false,
      };

  @override
  Future<NativeIdentityCredential?> authenticate(String provider) async {
    if (!supports(provider)) throw StateError('provider_not_configured');
    if (provider == 'google') {
      final platform = defaultTargetPlatform;
      if (config.googleServerClientId.isEmpty ||
          (platform == TargetPlatform.iOS &&
              config.googleIosClientId.isEmpty)) {
        throw StateError('provider_not_configured');
      }
      final configuration = (
        platform: platform,
        serverClientId: config.googleServerClientId,
        clientId: platform == TargetPlatform.iOS
            ? config.googleIosClientId
            : null,
      );
      final session = _googleSession ??= _GoogleSession(configuration);
      if (session.configuration != configuration) {
        throw StateError('provider_configuration_changed');
      }
      // Keep initialization failures sticky; retrying initialize is undefined
      // in the singleton SDK. Authentication must never bypass this barrier.
      await session.initialized;
      try {
        final user = await GoogleSignIn.instance.authenticate(
          scopeHint: _googleScopes,
        );
        final token = user.authentication.idToken;
        if (token == null) throw StateError('provider_token_missing');
        final authorization =
            await user.authorizationClient.authorizationForScopes(
              _googleScopes,
            ) ??
            await user.authorizationClient.authorizeScopes(_googleScopes);
        return NativeIdentityCredential(
          idToken: token,
          accessToken: authorization.accessToken,
          nonce: session.rawNonce,
        );
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) return null;
        rethrow;
      }
    }
    final random = Random.secure();
    final nonce = base64Url.encode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
      );
      final token = credential.identityToken;
      if (token == null) throw StateError('provider_token_missing');
      return NativeIdentityCredential(
        idToken: token,
        nonce: nonce,
        authorizationCode: credential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }
}
