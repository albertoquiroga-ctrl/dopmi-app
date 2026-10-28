import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppConfig {
  static const _productionHost = 'ysaoeuidcvgtlmphmeyb.supabase.co';
  static const _productionUrl = 'https://$_productionHost';

  const AppConfig({
    required this.url,
    required this.key,
    required this.redirect,
    this.googleEnabled = false,
    this.appleEnabled = false,
    this.environment = 'test',
    this.googleServerClientId = '',
    this.googleIosClientId = '',
    this.measurementTestEnabled = false,
    this.releaseName = 'desarrollo',
    this.buildNumber = 'local',
  });
  factory AppConfig.environment() => const AppConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    key: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    redirect: String.fromEnvironment(
      'AUTH_REDIRECT_URL',
      defaultValue: 'io.dopmi.app://auth/callback',
    ),
    googleEnabled: bool.fromEnvironment('ENABLE_GOOGLE_AUTH'),
    appleEnabled: bool.fromEnvironment('ENABLE_APPLE_AUTH'),
    googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    measurementTestEnabled: bool.fromEnvironment('ENABLE_MEASUREMENT_TEST'),
    releaseName: String.fromEnvironment(
      'DOPMI_RELEASE_NAME',
      defaultValue: 'desarrollo',
    ),
    buildNumber: String.fromEnvironment(
      'DOPMI_BUILD_NUMBER',
      defaultValue: 'local',
    ),
    environment: String.fromEnvironment(
      'DOPMI_ENVIRONMENT',
      defaultValue: 'test',
    ),
  );
  final String url, key, redirect;
  final bool googleEnabled, appleEnabled;
  final String environment;
  final String googleServerClientId, googleIosClientId;
  final bool measurementTestEnabled;
  final String releaseName, buildNumber;
  String get versionLabel => '$releaseName ($buildNumber)';
  bool get appleNativeAvailable =>
      appleEnabled && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get isValid {
    if (environment != 'test' && environment != 'production') return false;
    final uri = Uri.tryParse(url);
    final callback = Uri.tryParse(redirect);
    if (uri == null ||
        uri.host.isEmpty ||
        callback == null ||
        !callback.hasScheme) {
      return false;
    }
    final production = environment == 'production';
    if (production) {
      if (url != _productionUrl && url != '$_productionUrl/') {
        return false;
      }
    } else if (uri.host == _productionHost) {
      return false;
    }
    if (uri.scheme != 'https' &&
        !['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)) {
      return false;
    }
    if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key)) return true;
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map;
      return payload['role'] == 'anon' &&
          ((!production && payload['ref'] == null) ||
              payload['ref'] == uri.host.split('.').first);
    } catch (_) {
      return false;
    }
  }
}
