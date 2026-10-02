import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production remains closed until commissioned', () {
    expect(
      const AppConfig(
        url: 'https://demo.supabase.co',
        key: 'sb_publishable_example',
        redirect: 'io.dopmi.app://auth/callback',
        environment: 'production',
      ).isValid,
      isFalse,
    );
  });

  test('legacy public keys must match the endpoint project', () {
    for (final project in ['demo', 'other']) {
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'role': 'anon', 'ref': project})),
      );
      final config = AppConfig(
        url: 'https://demo.supabase.co',
        key: 'e30.$payload.signature',
        redirect: 'io.dopmi.app://auth/callback',
      );
      expect(config.isValid, project == 'demo');
    }
  });
}
