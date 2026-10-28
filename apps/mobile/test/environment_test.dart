import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testUrl = 'https://ohqxranynackjignryep.supabase.co';
  const productionUrl = 'https://ysaoeuidcvgtlmphmeyb.supabase.co';
  const redirect = 'io.dopmi.app://auth/callback';

  AppConfig candidate({
    String url = testUrl,
    String key = 'sb_publishable_fixture',
    String environment = 'test',
    String callback = redirect,
  }) => AppConfig(
    url: url,
    key: key,
    redirect: callback,
    environment: environment,
  );

  String jwt(String role, [String? project]) {
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({'role': role, 'ref': ?project}),
      ),
    );
    return 'e30.$payload.signature';
  }

  test('registered TEST and production accept public client keys', () {
    expect(candidate().isValid, isTrue);
    expect(
      candidate(url: productionUrl, environment: 'production').isValid,
      isTrue,
    );
    expect(
      candidate(
        url: productionUrl,
        key: jwt('anon', 'ysaoeuidcvgtlmphmeyb'),
        environment: 'production',
      ).isValid,
      isTrue,
    );
  });

  test('production requires its registered HTTPS endpoint', () {
    for (final url in [
      testUrl,
      'https://demo.supabase.co',
      'http://ysaoeuidcvgtlmphmeyb.supabase.co',
      'https://ysaoeuidcvgtlmphmeyb.supabase.co.evil.test',
      '$productionUrl:443',
      'https://user@ysaoeuidcvgtlmphmeyb.supabase.co',
      '$productionUrl/unregistered',
      '$productionUrl?project=other',
      '$productionUrl#other',
      'http://localhost:54321',
    ]) {
      expect(candidate(url: url, environment: 'production').isValid, isFalse);
    }
    expect(
      candidate(url: '$productionUrl/', environment: 'production').isValid,
      isTrue,
    );
  });

  test('TEST cannot connect to the production host', () {
    for (final url in [productionUrl, '$productionUrl/', '$productionUrl:443']) {
      expect(candidate(url: url).isValid, isFalse);
    }
    expect(
      candidate(key: jwt('anon', 'ysaoeuidcvgtlmphmeyb')).isValid,
      isFalse,
    );
  });

  test('unknown environments fail closed', () {
    for (final environment in ['', 'staging', 'Production', 'live']) {
      expect(candidate(environment: environment).isValid, isFalse);
    }
  });

  test('production anon keys require the exact project reference', () {
    for (final project in [null, '', 'demo', 'ohqxranynackjignryep']) {
      expect(
        candidate(
          url: productionUrl,
          environment: 'production',
          key: jwt('anon', project),
        ).isValid,
        isFalse,
      );
    }
  });

  test('legacy public keys must match the endpoint project', () {
    for (final project in ['demo', 'other']) {
      final config = candidate(
        url: 'https://demo.supabase.co',
        key: jwt('anon', project),
      );
      expect(config.isValid, project == 'demo');
    }
    expect(candidate(key: jwt('anon')).isValid, isTrue);
    expect(candidate(key: jwt('anon', 'ohqxranynackjignryep')).isValid, isTrue);
  });

  test('both environments reject server and malformed credentials', () {
    for (final environment in ['test', 'production']) {
      final production = environment == 'production';
      for (final key in [
        '',
        'sb_secret_fixture',
        'sb_publishable_',
        'sb_publishable_fixture.invalid',
        'pk_live_fixture',
        'sk_live_fixture',
        'rk_test_fixture',
        'not-a-jwt',
        '${jwt('anon', 'ysaoeuidcvgtlmphmeyb')}.extra',
        jwt('service_role', production ? 'ysaoeuidcvgtlmphmeyb' : 'demo'),
      ]) {
        expect(
          candidate(
            url: production ? productionUrl : testUrl,
            environment: environment,
            key: key,
          ).isValid,
          isFalse,
        );
      }
    }
  });

  test('local TEST endpoints and native callbacks remain supported', () {
    for (final host in ['localhost', '127.0.0.1', '10.0.2.2']) {
      final config = candidate(url: 'http://$host:54321', key: jwt('anon'));
      expect(config.isValid, isTrue);
      expect(config.redirect, redirect);
    }
    expect(candidate(callback: 'missing-scheme').isValid, isFalse);
    expect(
      candidate(url: productionUrl, environment: 'production').redirect,
      redirect,
    );
  });
}
