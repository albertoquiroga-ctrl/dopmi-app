import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _actor = '8b936a10-6d19-4d6e-8b2b-dbe47b5f639c';
const _url = 'https://session-fixture.example.test';
const _oldRefreshToken = 'synthetic-stored-refresh-token';

Map<String, dynamic> _user({bool remote = false}) => {
  'id': _actor,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': remote ? 'authoritative@example.test' : 'cached@example.test',
  'email_confirmed_at': '2026-10-01T00:00:00Z',
  'created_at': '2026-10-01T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
};

String _jwt(int expiresAt) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return [
    encode({'alg': 'HS256', 'typ': 'JWT'}),
    encode({'sub': _actor, 'aud': 'authenticated', 'exp': expiresAt}),
    'synthetic-signature',
  ].join('.');
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {
    'content-type': 'application/json',
    'x-supabase-api-version': '2024-01-01',
  },
);

Future<({T? value, Object? error})> _capture<T>(Future<T> operation) async {
  try {
    return (value: await operation, error: null);
  } catch (error) {
    return (value: null, error: error);
  }
}

/// Only HTTP is replaced. Session parsing, expiry, recovery, refresh sharing,
/// and getUser authorization all run through the installed Supabase SDK.
class _SessionTransport {
  _SessionTransport() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expiredJwt = _jwt(now - 3600);
    validJwt = _jwt(now + 3600);
    httpClient = MockClient((request) async {
      requests.add(request);
      expect(request.url.origin, _url);
      if (request.method == 'POST' && request.url.path == '/auth/v1/token') {
        refreshes++;
        expect(request.url.queryParameters['grant_type'], 'refresh_token');
        expect(jsonDecode(request.body), {'refresh_token': _oldRefreshToken});
        if (!refreshStarted.isCompleted) refreshStarted.complete();
        if (!firstRequest.isCompleted) firstRequest.complete();
        return await refreshReply.future;
      }
      if (request.method == 'GET' && request.url.path == '/auth/v1/user') {
        users++;
        final authorization = request.headers['authorization'];
        userAuthorizations.add(authorization);
        if (!firstRequest.isCompleted) firstRequest.complete();
        if (authorization != 'Bearer $validJwt') {
          return _json({'code': 'bad_jwt', 'msg': 'JWT expired'}, 401);
        }
        return _json(_user(remote: true));
      }
      fail(
        'Unexpected SDK HTTP request: ${request.method} ${request.url.path}',
      );
    });
  }

  late final String expiredJwt, validJwt;
  late final MockClient httpClient;
  final requests = <http.Request>[];
  final userAuthorizations = <String?>[];
  final refreshReply = Completer<http.Response>();
  final refreshStarted = Completer<void>();
  final firstRequest = Completer<void>();
  int refreshes = 0, users = 0;

  Map<String, dynamic> session({required bool expired}) => {
    'access_token': expired ? expiredJwt : validJwt,
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': _oldRefreshToken,
    'user': _user(),
  };

  void releaseRefresh({bool revoked = false}) {
    if (refreshReply.isCompleted) return;
    refreshReply.complete(
      revoked
          ? _json({
              'code': 'refresh_token_not_found',
              'msg': 'Refresh token revoked',
            }, 400)
          : _json({
              ...session(expired: false),
              'refresh_token': 'synthetic-rotated-refresh-token',
            }),
    );
  }
}

Future<SupabaseIdentityRepository> _repository(
  _SessionTransport transport, {
  bool autoRefreshToken = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final client = SupabaseClient(
    _url,
    'synthetic-publishable-key',
    authOptions: AuthClientOptions(autoRefreshToken: autoRefreshToken),
    httpClient: transport.httpClient,
  );
  addTearDown(() async {
    transport.releaseRefresh(revoked: true);
    await client.dispose();
  });
  return SupabaseIdentityRepository(
    client,
    const AppConfig(
      url: _url,
      key: 'synthetic-publishable-key',
      redirect: 'com.mycompany.dopmi://auth/callback',
    ),
    await SharedPreferences.getInstance(),
  );
}

void _expectRemoteIdentity(Identity? identity) {
  expect(identity?.id, _actor);
  expect(identity?.email, 'authoritative@example.test');
  expect(identity?.verified, isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restore without a stored session sends no HTTP request', () async {
    final transport = _SessionTransport();
    final repository = await _repository(transport);

    expect(await repository.restore(), isNull);
    expect(transport.requests, isEmpty);
  });

  test(
    'restore validates a live session remotely without refreshing',
    () async {
      final transport = _SessionTransport();
      final repository = await _repository(transport);
      await repository.client.auth.setInitialSession(
        jsonEncode(transport.session(expired: false)),
      );
      expect(transport.requests, isEmpty);

      _expectRemoteIdentity(await repository.restore());

      expect(transport.refreshes, 0);
      expect(transport.users, 1);
      expect(transport.userAuthorizations, ['Bearer ${transport.validJwt}']);
    },
  );

  test(
    'restore waits for expired JWT refresh before requesting the user',
    () async {
      final transport = _SessionTransport();
      final repository = await _repository(transport);
      await repository.client.auth.setInitialSession(
        jsonEncode(transport.session(expired: true)),
      );
      expect(repository.client.auth.currentSession!.isExpired, isTrue);
      expect(transport.requests, isEmpty);
      var finished = false;
      final restoring = _capture(repository.restore())
          .whenComplete(() => finished = true);
      try {
        await transport.firstRequest.future;
        await Future<void>.delayed(Duration.zero);
        expect(
          transport.users,
          0,
          reason:
              'GET /user must wait while the expired JWT is being refreshed.',
        );
        expect(transport.refreshes, 1);
        expect(finished, isFalse);

        transport.releaseRefresh();
        final result = await restoring;
        expect(result.error, isNull);
        _expectRemoteIdentity(result.value);
        expect(transport.refreshes, 1);
        expect(transport.users, 1);
        expect(transport.userAuthorizations, ['Bearer ${transport.validJwt}']);
        expect(repository.client.auth.currentSession!.isExpired, isFalse);
        expect(repository.client.auth.currentUser!.id, _actor);
      } finally {
        transport.releaseRefresh();
        await restoring;
      }
    },
  );

  test(
    'restore shares one refresh with SDK recovery and auto refresh',
    () async {
      final transport = _SessionTransport();
      final repository = await _repository(transport, autoRefreshToken: true);
      final persistedSession = jsonEncode(transport.session(expired: true));
      await repository.client.auth.setInitialSession(persistedSession);
      repository.client.auth.startAutoRefresh();
      // Supabase Flutter recovery uses this real SDK call after initialSession.
      // Its refresh and the SDK's zero-delay auto-refresh tick stay in flight.
      final recovering = _capture(
        repository.client.auth.recoverSession(persistedSession),
      );
      await transport.refreshStarted.future;
      var finished = false;
      final restoring = _capture(repository.restore())
          .whenComplete(() => finished = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(
          transport.users,
          0,
          reason:
              'Restoration must join the SDK refresh, not send the old JWT.',
        );
        expect(transport.refreshes, 1);
        expect(finished, isFalse);

        transport.releaseRefresh();
        final result = await restoring;
        final recovery = await recovering;
        expect(result.error, isNull);
        expect(recovery.error, isNull);
        _expectRemoteIdentity(result.value);
        expect(recovery.value?.session?.user.id, _actor);
        expect(transport.refreshes, 1);
        expect(transport.users, 1);
        expect(transport.userAuthorizations, ['Bearer ${transport.validJwt}']);
        expect(
          repository.client.auth.currentSession!.refreshToken,
          'synthetic-rotated-refresh-token',
        );
        expect(repository.client.auth.currentUser!.id, _actor);
      } finally {
        transport.releaseRefresh();
        await restoring;
        await recovering;
      }
    },
  );

  test(
    'restore never grants identity after refresh token revocation',
    () async {
      final transport = _SessionTransport();
      final repository = await _repository(transport);
      await repository.client.auth.setInitialSession(
        jsonEncode(transport.session(expired: true)),
      );
      transport.releaseRefresh(revoked: true);

      final result = await _capture(repository.restore());

      expect(result.value, isNull);
      expect(
        result.error,
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'refresh_token_not_found',
        ),
      );
      expect(transport.refreshes, 1);
      expect(transport.users, 0);
      expect(repository.client.auth.currentSession, isNull);
      expect(repository.current, isNull);
    },
  );
}
