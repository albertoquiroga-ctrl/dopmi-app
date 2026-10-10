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

class PlatformNativeIdentity implements NativeIdentity {
  PlatformNativeIdentity(this.config);
  final AppConfig config;
  Future<void>? _googleInitialization;
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
      if (config.googleServerClientId.isEmpty ||
          (defaultTargetPlatform == TargetPlatform.iOS &&
              config.googleIosClientId.isEmpty)) {
        throw StateError('provider_not_configured');
      }
      try {
        await (_googleInitialization ??= GoogleSignIn.instance.initialize(
          serverClientId: config.googleServerClientId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? config.googleIosClientId
              : null,
        ));
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
