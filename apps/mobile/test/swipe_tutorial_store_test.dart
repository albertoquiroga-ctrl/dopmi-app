import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/adoption/swipe_tutorial_store.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_identity_repository.dart';

const _actor = '11111111-1111-4111-8111-111111111111';
const _otherActor = '22222222-2222-4222-8222-222222222222';
const _flag = 'dopmi_swipe_tutorial_v1';
const _config = AppConfig(
  url: 'https://tutorial.example.test',
  key: 'synthetic-publishable-key',
  redirect: 'com.mycompany.dopmi://auth/callback',
);

Map<String, dynamic> _user(String actor, {bool completed = false}) => {
  'id': actor,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': '$actor@example.test',
  'email_confirmed_at': '2026-11-24T00:00:00Z',
  'created_at': '2026-11-24T00:00:00Z',
  'app_metadata': <String, dynamic>{'provider': 'email'},
  'user_metadata': <String, dynamic>{
    'display_name': 'Nombre privado',
    if (completed) _flag: true,
  },
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic>? _receipt(
  SharedPreferences preferences, {
  AppConfig config = _config,
  String actor = _actor,
}) {
  final value = preferences.getString(
    swipeTutorialPreferenceKey(config, actor),
  );
  return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
}

Future<Object?> _captureError(Future<void> operation) async {
  try {
    await operation;
    return null;
  } catch (error) {
    return error;
  }
}

String _jwt(String actor) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return [
    encode({'alg': 'HS256', 'typ': 'JWT'}),
    encode({'sub': actor, 'aud': 'authenticated', 'exp': 1893456000}),
    'synthetic-signature',
  ].join('.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  String? actor, token;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    actor = _actor;
    token = 'synthetic-actor-token';
  });

  SupabaseSwipeTutorialStore store(
    MockClient transport, {
    AppConfig config = _config,
    Duration requestTimeout = const Duration(seconds: 8),
  }) => SupabaseSwipeTutorialStore(
    config: config,
    preferences: preferences,
    currentActor: () => actor,
    accessToken: () => token,
    transport: transport,
    requestTimeout: requestTimeout,
  );

  test(
    'unseen account reads Auth freshly without a completion receipt',
    () async {
      final requests = <http.Request>[];
      final tutorial = store(
        MockClient((request) async {
          requests.add(request);
          return _json(_user(_actor));
        }),
      );

      expect(await tutorial.completed(_actor), isFalse);
      expect(_receipt(preferences), isNull);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.toString(), '${_config.url}/auth/v1/user');
      expect(requests.single.headers['apikey'], 'synthetic-publishable-key');
      expect(
        requests.single.headers['authorization'],
        'Bearer synthetic-actor-token',
      );
    },
  );

  test(
    'fresh device caches remote completion without private metadata',
    () async {
      var reads = 0;
      final tutorial = store(
        MockClient((request) async {
          reads++;
          return _json(_user(_actor, completed: true));
        }),
      );

      expect(await tutorial.completed(_actor), isTrue);
      expect(await tutorial.completed(_actor), isTrue);
      expect(reads, 1);
      expect(_receipt(preferences), {'completed': true, 'pending': false});
    },
  );

  test(
    'completion sends only its flag and survives a second installation',
    () async {
      var remoteCompleted = false;
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT') {
          expect(jsonDecode(request.body), {
            'data': {_flag: true},
          });
          expect(request.headers['content-type'], 'application/json');
          remoteCompleted = true;
        }
        return _json(_user(_actor, completed: remoteCompleted));
      });

      await store(transport).complete(_actor);
      expect(_receipt(preferences), {'completed': true, 'pending': false});

      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      expect(await store(transport).completed(_actor), isTrue);
      expect(requests.map((request) => request.method), ['PUT', 'GET']);
    },
  );

  test(
    'offline close persists and retries the pending upload on next access',
    () async {
      var online = false;
      final methods = <String>[];
      final transport = MockClient((request) async {
        methods.add(request.method);
        if (!online) throw http.ClientException('synthetic offline');
        return _json(_user(_actor, completed: true));
      });

      await store(transport).complete(_actor);
      expect(_receipt(preferences), {'completed': true, 'pending': true});
      expect(await store(transport).completed(_actor), isTrue);
      expect(_receipt(preferences), {'completed': true, 'pending': true});

      online = true;
      expect(await store(transport).completed(_actor), isTrue);
      expect(_receipt(preferences), {'completed': true, 'pending': false});
      expect(await store(transport).completed(_actor), isTrue);
      expect(methods, ['PUT', 'PUT', 'PUT']);
    },
  );

  test(
    'close remains local while the access token is temporarily unavailable',
    () async {
      var writes = 0;
      final transport = MockClient((request) async {
        writes++;
        return _json(_user(_actor, completed: true));
      });
      token = null;

      await store(transport).complete(_actor);
      expect(await store(transport).completed(_actor), isTrue);
      expect(writes, 0);
      expect(_receipt(preferences), {'completed': true, 'pending': true});

      token = 'synthetic-renewed-token';
      expect(await store(transport).completed(_actor), isTrue);
      expect(writes, 1);
      expect(_receipt(preferences), {'completed': true, 'pending': false});
    },
  );

  test(
    'cached completion cannot suppress a different account tutorial',
    () async {
      final transport = MockClient((request) async {
        return _json(_user(actor!, completed: request.method == 'PUT'));
      });
      final tutorial = store(transport);
      await tutorial.complete(_actor);

      actor = _otherActor;
      token = 'synthetic-other-token';
      expect(await tutorial.completed(_otherActor), isFalse);
      expect(_receipt(preferences, actor: _otherActor), isNull);
      expect(_receipt(preferences), {'completed': true, 'pending': false});
    },
  );

  for (final isolated in ['environment', 'host']) {
    test('cached completion is isolated by $isolated', () async {
      final transport = MockClient((request) async {
        return _json(_user(_actor, completed: request.method == 'PUT'));
      });
      await store(transport).complete(_actor);
      final otherConfig = AppConfig(
        url: isolated == 'host' ? 'https://other.example.test' : _config.url,
        key: _config.key,
        redirect: _config.redirect,
        environment: isolated == 'environment' ? 'production' : 'test',
      );

      expect(
        await store(transport, config: otherConfig).completed(_actor),
        isFalse,
      );
      expect(_receipt(preferences, config: otherConfig), isNull);
      expect(_receipt(preferences), {'completed': true, 'pending': false});
    });
  }

  test('stale actor cannot issue requests or write local completion', () async {
    var requests = 0;
    final tutorial = store(
      MockClient((request) async {
        requests++;
        return _json(_user(_actor, completed: true));
      }),
    );
    actor = _otherActor;

    await expectLater(tutorial.completed(_actor), throwsStateError);
    await expectLater(tutorial.complete(_actor), throwsStateError);
    expect(requests, 0);
    expect(preferences.getKeys(), isEmpty);
  });

  test('failed remote read never becomes a completion receipt', () async {
    var failing = true;
    final tutorial = store(
      MockClient((request) async {
        if (failing) throw http.ClientException('synthetic offline');
        return _json(_user(_actor));
      }),
    );

    await expectLater(tutorial.completed(_actor), throwsA(isA<Exception>()));
    expect(preferences.getKeys(), isEmpty);
    failing = false;
    expect(await tutorial.completed(_actor), isFalse);
    expect(preferences.getKeys(), isEmpty);
  });

  for (final invalid in ['foreign', 'denied', 'malformed']) {
    test('$invalid Auth read cannot create a completion receipt', () async {
      final tutorial = store(
        MockClient((request) async {
          return switch (invalid) {
            'foreign' => _json(_user(_otherActor, completed: true)),
            'denied' => _json({'msg': 'synthetic denial'}, 401),
            _ => http.Response('malformed', 200),
          };
        }),
      );

      await expectLater(
        tutorial.completed(_actor),
        throwsA(anyOf(isA<Exception>(), isA<StateError>())),
      );
      expect(preferences.getKeys(), isEmpty);
    });
  }

  test(
    'late Auth read after account change cannot write either receipt',
    () async {
      final started = Completer<void>();
      final reply = Completer<http.Response>();
      final tutorial = store(
        MockClient((request) async {
          started.complete();
          return reply.future;
        }),
      );
      final result = _captureError(tutorial.completed(_actor).then((_) {}));
      await started.future;
      actor = _otherActor;
      token = 'synthetic-other-token';
      reply.complete(_json(_user(_actor, completed: true)));

      expect(await result, isA<StateError>());
      expect(preferences.getKeys(), isEmpty);
    },
  );

  test(
    'late completion cannot mutate a newer Supabase session or its receipt',
    () async {
      final client = SupabaseClient(
        _config.url,
        _config.key,
        authOptions: AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/v1/token');
          final loginActor =
              jsonDecode(request.body)['email'] == 'first@example.test'
              ? _actor
              : _otherActor;
          return _json({
            'access_token': _jwt(loginActor),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'synthetic-$loginActor-refresh',
            'user': _user(loginActor),
          });
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'first@example.test',
        password: 'synthetic-password',
      );
      final started = Completer<void>();
      final reply = Completer<http.Response>();
      final tutorial = SupabaseSwipeTutorialStore(
        config: _config,
        preferences: preferences,
        currentActor: () => client.auth.currentUser?.id,
        accessToken: () => client.auth.currentSession?.accessToken,
        transport: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.headers['authorization'], 'Bearer ${_jwt(_actor)}');
          started.complete();
          return reply.future;
        }),
      );
      final result = _captureError(tutorial.complete(_actor));
      await started.future;
      await client.auth.signInWithPassword(
        email: 'second@example.test',
        password: 'synthetic-password',
      );
      final newerSession = client.auth.currentSession;
      reply.complete(_json(_user(_actor, completed: true)));

      expect(await result, isA<StateError>());
      expect(identical(client.auth.currentSession, newerSession), isTrue);
      expect(client.auth.currentUser?.id, _otherActor);
      expect(client.auth.currentSession?.accessToken, _jwt(_otherActor));
      expect(_receipt(preferences, actor: _otherActor), isNull);
      expect(_receipt(preferences), {'completed': true, 'pending': true});
    },
  );

  test(
    'remote read timeout releases the gate without recording completion',
    () async {
      final reply = Completer<http.Response>();
      final tutorial = store(
        MockClient((request) => reply.future),
        requestTimeout: const Duration(milliseconds: 5),
      );

      await expectLater(
        tutorial.completed(_actor),
        throwsA(isA<TimeoutException>()),
      );
      reply.complete(_json(_user(_actor, completed: true)));
      await Future<void>.delayed(Duration.zero);
      expect(preferences.getKeys(), isEmpty);
    },
  );

  test('unacknowledged PUT keeps local completion pending for retry', () async {
    var writes = 0;
    final tutorial = store(
      MockClient((request) async {
        writes++;
        return _json(_user(_actor, completed: writes > 1));
      }),
    );

    await tutorial.complete(_actor);
    expect(_receipt(preferences), {'completed': true, 'pending': true});
    expect(await tutorial.completed(_actor), isTrue);
    expect(writes, 2);
    expect(_receipt(preferences), {'completed': true, 'pending': false});
  });

  test('non-Supabase repositories keep existing injected discovery fixtures eligible', () async {
    final identity = FakeIdentityRepository();
    addTearDown(identity.changes.close);
    final container = ProviderContainer(
      overrides: [identityRepositoryProvider.overrideWithValue(identity)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(swipeTutorialStoreProvider).completed(_actor),
      isTrue,
    );
    await container.read(swipeTutorialStoreProvider).complete(_actor);
    expect(preferences.getKeys(), isEmpty);
  });
}
