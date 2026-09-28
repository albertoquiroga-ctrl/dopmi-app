import 'dart:convert';

class AppConfig {
  const AppConfig({
    required this.url,
    required this.key,
    required this.redirect,
    this.googleEnabled = false,
    this.appleEnabled = false,
    this.environment = 'test',
    this.googleServerClientId = '',
    this.googleIosClientId = '',
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
    environment: String.fromEnvironment(
      'DOPMI_ENVIRONMENT',
      defaultValue: 'test',
    ),
  );
  final String url, key, redirect;
  final bool googleEnabled, appleEnabled;
  final String environment;
  final String googleServerClientId, googleIosClientId;
  bool get isValid {
    // Production cannot be selected until its project has been commissioned.
    if (environment != 'test') return false;
    final uri = Uri.tryParse(url);
    final callback = Uri.tryParse(redirect);
    if (uri == null ||
        uri.host.isEmpty ||
        callback == null ||
        !callback.hasScheme) {
      return false;
    }
    if (uri.scheme != 'https' &&
        !['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)) {
      return false;
    }
    if (key.startsWith('sb_publishable_')) return true;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))),
      ) as Map;
      return payload['role'] == 'anon' &&
          (payload['ref'] == null ||
              payload['ref'] == uri.host.split('.').first);
    } catch (_) {
      return false;
    }
  }
}
