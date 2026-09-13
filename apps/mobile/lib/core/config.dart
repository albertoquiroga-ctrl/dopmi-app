import 'dart:convert';

class AppConfig {
  const AppConfig({
    required this.url,
    required this.key,
    required this.redirect,
    this.googleEnabled = false,
    this.appleEnabled = false,
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
  );
  final String url, key, redirect;
  final bool googleEnabled, appleEnabled;
  bool get isValid {
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
      return (jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(key.split('.')[1])),
            ),
          ) as Map)['role'] ==
          'anon';
    } catch (_) {
      return false;
    }
  }
}
