import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/adoption_measurement_consent.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'measurement_test.dart' show BlockingEnableAnalytics, DiagnosticsSpy;

const _alice = '79000000-0000-4000-8000-000000000001';
const _bob = '79000000-0000-4000-8000-000000000002';

Map<String, Object> _session(
  String owner,
  String generation, {
  int expiresAt = 1893456000,
}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.'
        '${encode({'sub': owner, 'exp': expiresAt, 'generation': generation})}'
        '.synthetic-signature',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'synthetic-refresh',
    'user': {
      'id': owner,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.test',
      'app_metadata': <String, Object>{},
      'user_metadata': <String, Object>{},
      'created_at': '2026-10-01T00:00:00Z',
    },
  };
}

class _Server {
  String loginOwner = _alice;
  String generation = 'initial';
  int expiresAt = 1893456000;
  final authRequests = <http.Request>[];
  final states = <String, ({bool consent, int revision})>{};
  final reads = <http.Request>[];
  final writes = <http.Request>[];
  Future<Object> Function(http.Request)? readOverride;
  Future<Object> Function(http.Request)? writeOverride;

  String actor(http.Request request) {
    final token = request.headers['authorization']!.substring(7);
    return (jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(token.split('.')[1])),
          ),
        ) as Map<String, dynamic>)['sub']
        as String;
  }

  Map<String, Object> state(String owner) {
    final saved = states[owner] ?? (consent: false, revision: 0);
    return {'consent': saved.consent, 'revision': saved.revision};
  }

  Map<String, Object> apply(http.Request request) {
    final owner = actor(request);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final saved = states[owner] ?? (consent: false, revision: 0);
    final applied = saved.revision == body['expected_revision'];
    if (applied) {
      states[owner] = (
        consent: body['consent'] as bool,
        revision: saved.revision + 1,
      );
    }
    return {'applied': applied, ...state(owner)};
  }

  Future<http.Response> handle(http.Request request) async {
    Object result;
    if (request.url.path.startsWith('/auth/')) {
      authRequests.add(request);
      result = _session(loginOwner, generation, expiresAt: expiresAt);
    } else if (request.url.path.endsWith('dopmi_adoption_measurement_state')) {
      reads.add(request);
      result = readOverride == null
          ? state(actor(request))
          : await readOverride!(request);
    } else {
      expect(
        request.url.path,
        '/rest/v1/rpc/dopmi_set_adoption_measurement_v2',
      );
      writes.add(request);
      result = writeOverride == null
          ? apply(request)
          : await writeOverride!(request);
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  late _Server server;
  late SupabaseClient client;
  late AdoptionMeasurementConsent transport;

  Future<void> login(String owner, {String generation = 'initial'}) async {
    server.loginOwner = owner;
    server.generation = generation;
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
  }

  setUp(() async {
    server = _Server();
    client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(server.handle),
    );
    await login(_alice);
    transport = AdoptionMeasurementConsent(client);
  });
  tearDown(() => client.dispose());

  test(
    'a queued SDK opt-in cannot invalidate the active transport revocation',
    () async {
      SharedPreferences.setMockInitialValues({});
      server.states[_alice] = (consent: true, revision: 1);
      final analytics = BlockingEnableAnalytics();
      late final MeasurementController controller;
      controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        DiagnosticsSpy(),
        prepareAdoptionConsent: (owner, enabled) {
          final revision = controller.analyticsRevision;
          final request = transport.prepare(
            owner,
            enabled,
            stillEligible: () =>
                controller.ownerId == owner &&
                controller.analyticsConsentCurrent &&
                controller.analyticsRevision == revision,
          );
          return request == null
              ? null
              : () async {
                  await request();
                };
        },
      );
      addTearDown(controller.dispose);
      await controller.owner(_alice);
      final entered = Completer<void>();
      final release = Completer<void>();
      server.readOverride = (request) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        return server.state(server.actor(request));
      };
      final on = controller.setAnalytics(true);
      await analytics.started.future;
      final off = controller.setAnalytics(false);
      try {
        await entered.future;
        analytics.release.complete();
        await on;
        release.complete();
        await off;
        await controller.consentReady;
        expect(controller.analyticsEnabled, isFalse);
        expect(server.state(_alice), {'consent': false, 'revision': 2});
        expect(server.writes, hasLength(1));
        expect(jsonDecode(server.writes.single.body)['consent'], isFalse);
      } finally {
        if (!analytics.release.isCompleted) analytics.release.complete();
        if (!release.isCompleted) release.complete();
        await Future.wait([on, off]);
        await controller.consentReady;
      }
    },
  );

  test(
    'every accepted intention advances the server revision, including OFF',
    () async {
      expect(
        await transport.prepare(_alice, false, stillEligible: () => false)!(),
        isTrue,
      );
      expect(server.state(_alice), {'consent': false, 'revision': 1});
      expect(
        await transport.prepare(_alice, true, stillEligible: () => true)!(),
        isTrue,
      );
      expect(server.state(_alice), {'consent': true, 'revision': 2});
      expect(server.writes.map((r) => jsonDecode(r.body)), [
        {'consent': false, 'expected_revision': 0},
        {'consent': true, 'expected_revision': 1},
      ]);
    },
  );

  test(
    'OFF completes while a preceding ON state lookup remains stalled',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      server.readOverride = (request) async {
        if (server.reads.length == 1) {
          started.complete();
          await release.future;
        }
        return server.state(server.actor(request));
      };
      final on = transport.prepare(_alice, true, stillEligible: () => true)!();
      await started.future;
      expect(
        await transport.prepare(_alice, false, stillEligible: () => false)!(),
        isTrue,
      );
      expect(server.state(_alice), {'consent': false, 'revision': 1});
      release.complete();
      expect(await on, isFalse);
      expect(server.writes.length, 1);
    },
  );

  test('accepted consent exposes the revision returned by its own CAS', () async {
    server.states[_alice] = (consent: false, revision: 8);
    server.writeOverride = (request) async {
      final accepted = server.apply(request);
      // Another device can advance state before this response reaches the app.
      server.states[_alice] = (consent: true, revision: 20);
      return accepted;
    };
    final revisions = <int>[];

    expect(
      await transport.prepare(
        _alice,
        true,
        stillEligible: () => true,
        onAcceptedRevision: revisions.add,
      )!(),
      isTrue,
    );

    expect(revisions, [9]);
    expect(server.state(_alice), {'consent': true, 'revision': 20});
    expect(server.reads, hasLength(1));
    expect(server.writes, hasLength(1));
  });

  test('a current actor can observe an accepted OFF revision', () async {
    server.states[_alice] = (consent: true, revision: 3);
    final revisions = <int>[];

    expect(
      await transport.prepare(
        _alice,
        false,
        stillEligible: () => false,
        onAcceptedRevision: revisions.add,
      )!(),
      isTrue,
    );

    expect(revisions, [4]);
    expect(server.state(_alice), {'consent': false, 'revision': 4});
  });

  for (final result in <Map<String, Object>>[
    {'applied': false, 'consent': true, 'revision': 1},
    {'applied': true, 'consent': false, 'revision': 1},
    {'applied': true, 'consent': true, 'revision': 'invalid'},
  ]) {
    test(
      'a rejected or invalid CAS does not expose a revision: $result',
      () async {
        final revisions = <int>[];
        server.writeOverride = (_) async => result;

        expect(
          await transport.prepare(
            _alice,
            true,
            stillEligible: () => true,
            onAcceptedRevision: revisions.add,
          )!(),
          isFalse,
        );
        expect(revisions, isEmpty);
      },
    );
  }

  for (final enabled in [true, false]) {
    test(
      'a response for the previous actor exposes no revision ($enabled)',
      () async {
        final revisions = <int>[];
        server.writeOverride = (request) async {
          final accepted = server.apply(request);
          await login(_bob);
          return accepted;
        };

        expect(
          await transport.prepare(
            _alice,
            enabled,
            stillEligible: () => true,
            onAcceptedRevision: revisions.add,
          )!(),
          enabled ? isFalse : isTrue,
        );

        expect(server.actor(server.writes.single), _alice);
        expect(revisions, isEmpty);
      },
    );
  }

  test(
    'a newer intention suppresses the older accepted revision callback',
    () async {
      final revisions = <int>[];
      server.writeOverride = (request) async {
        final accepted = server.apply(request);
        transport.prepare(_alice, false, stillEligible: () => false);
        return accepted;
      };

      expect(
        await transport.prepare(
          _alice,
          true,
          stillEligible: () => true,
          onAcceptedRevision: revisions.add,
        )!(),
        isFalse,
      );
      expect(revisions, isEmpty);
    },
  );

  test(
    'an ineligible ON response does not expose its accepted revision',
    () async {
      var eligible = true;
      final revisions = <int>[];
      server.writeOverride = (request) async {
        final accepted = server.apply(request);
        eligible = false;
        return accepted;
      };

      expect(
        await transport.prepare(
          _alice,
          true,
          stillEligible: () => eligible,
          onAcceptedRevision: revisions.add,
        )!(),
        isFalse,
      );
      expect(revisions, isEmpty);
    },
  );

  test('a timed out CAS never exposes a late accepted revision', () async {
    final release = Completer<void>();
    final revisions = <int>[];
    server.writeOverride = (request) async {
      await release.future;
      return server.apply(request);
    };
    transport = AdoptionMeasurementConsent(
      client,
      timeout: const Duration(milliseconds: 10),
    );

    try {
      expect(
        await transport.prepare(
          _alice,
          true,
          stillEligible: () => true,
          onAcceptedRevision: revisions.add,
        )!(),
        isFalse,
      );
      release.complete();
      await Future<void>.delayed(Duration.zero);
      expect(server.state(_alice), {'consent': true, 'revision': 1});
      expect(revisions, isEmpty);
    } finally {
      if (!release.isCompleted) release.complete();
    }
  });

  test(
    'an observer failure does not undo confirmed consent acceptance',
    () async {
      expect(
        await transport.prepare(
          _alice,
          true,
          stillEligible: () => true,
          onAcceptedRevision: (_) =>
              throw StateError('optional observer failed'),
        )!(),
        isTrue,
      );
      expect(server.state(_alice), {'consent': true, 'revision': 1});
    },
  );

  test('a late ON POST cannot overwrite the newer OFF revision', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    server.writeOverride = (request) async {
      if ((jsonDecode(request.body) as Map)['consent'] == true) {
        started.complete();
        await release.future;
      }
      return server.apply(request);
    };
    final on = transport.prepare(_alice, true, stillEligible: () => true)!();
    await started.future;
    expect(
      await transport.prepare(_alice, false, stillEligible: () => false)!(),
      isTrue,
    );
    release.complete();
    expect(await on, isFalse);
    expect(server.state(_alice), {'consent': false, 'revision': 1});
    expect(server.writes.length, 2);
  });

  test(
    'an older ON from another transport cannot override a newer OFF',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      server.writeOverride = (request) async {
        if ((jsonDecode(request.body) as Map)['consent'] == true &&
            !started.isCompleted) {
          started.complete();
          await release.future;
        }
        return server.apply(request);
      };
      final oldOn = transport.prepare(
        _alice,
        true,
        stillEligible: () => true,
      )!();
      await started.future;
      final anotherDevice = AdoptionMeasurementConsent(client);
      expect(
        await anotherDevice.prepare(
          _alice,
          false,
          stillEligible: () => false,
        )!(),
        isTrue,
      );
      release.complete();
      final accepted = await oldOn;
      expect(server.state(_alice), {'consent': false, 'revision': 1});
      expect(accepted, isFalse);
      expect(server.writes.length, 2);
    },
  );

  test(
    'ON skips a conflict even when the current server decision is already true',
    () async {
      server.writeOverride = (request) async {
        server.states[_alice] = (consent: true, revision: 1);
        return server.apply(request);
      };
      expect(
        await transport.prepare(_alice, true, stillEligible: () => true)!(),
        isFalse,
      );
      expect(server.state(_alice), {'consent': true, 'revision': 1});
      expect(server.writes.length, 1);
    },
  );

  test(
    'latest local ON skips a conflict after an earlier OFF already dispatched',
    () async {
      final offStarted = Completer<void>();
      final releaseOff = Completer<void>();
      final offApplied = Completer<void>();
      var firstOn = true;
      server.writeOverride = (request) async {
        if ((jsonDecode(request.body) as Map)['consent'] == false) {
          offStarted.complete();
          await releaseOff.future;
          final result = server.apply(request);
          offApplied.complete();
          return result;
        }
        if (firstOn) {
          firstOn = false;
          releaseOff.complete();
          await offApplied.future;
        }
        return server.apply(request);
      };
      final off = transport.prepare(
        _alice,
        false,
        stillEligible: () => false,
      )!();
      await offStarted.future;
      expect(
        await transport.prepare(_alice, true, stillEligible: () => true)!(),
        isFalse,
      );
      expect(await off, isFalse);
      expect(server.state(_alice), {'consent': false, 'revision': 1});
      expect(server.writes.map((r) => jsonDecode(r.body)), [
        {'consent': false, 'expected_revision': 0},
        {'consent': true, 'expected_revision': 0},
      ]);
    },
  );

  test('intention counters are separate per actor and revocation retains its actor token', () async {
    final off = transport.prepare(_alice, false, stillEligible: () => false)!;
    await login(_bob);
    final on = transport.prepare(_bob, true, stillEligible: () => true)!;
    expect(await off(), isTrue);
    expect(await on(), isTrue);
    expect(server.writes.map(server.actor), [_alice, _bob]);
    expect(server.state(_alice), {'consent': false, 'revision': 1});
    expect(server.state(_bob), {'consent': true, 'revision': 1});
  });

  test(
    'an ON intent never follows an account switch or a newer same-actor intent',
    () async {
      final superseded = transport.prepare(
        _alice,
        true,
        stillEligible: () => true,
      )!;
      transport.prepare(_alice, false, stillEligible: () => false);
      expect(await superseded(), isFalse);
      final switched = transport.prepare(
        _alice,
        true,
        stillEligible: () => true,
      )!;
      await login(_bob);
      expect(await switched(), isFalse);
      expect(
        transport.prepare(_alice, true, stillEligible: () => true),
        isNull,
      );
      expect(server.reads, isEmpty);
      expect(server.writes, isEmpty);
    },
  );

  test(
    'ON checks eligibility again after each asynchronous response',
    () async {
      var eligible = true;
      server.readOverride = (request) async {
        eligible = false;
        return server.state(server.actor(request));
      };
      expect(
        await transport.prepare(_alice, true, stillEligible: () => eligible)!(),
        isFalse,
      );
      expect(server.writes, isEmpty);
      eligible = true;
      server.readOverride = null;
      server.writeOverride = (request) async {
        eligible = false;
        return server.apply(request);
      };
      expect(
        await transport.prepare(_alice, true, stillEligible: () => eligible)!(),
        isFalse,
      );
      expect(server.writes.length, 1);
    },
  );

  test(
    'requests use a refreshed token only for the originally captured actor',
    () async {
      final action = transport.prepare(
        _alice,
        true,
        stillEligible: () => true,
      )!;
      await login(_alice, generation: 'refreshed');
      expect(await action(), isTrue);
      expect(
        server.reads.single.headers['authorization'],
        'Bearer ${_session(_alice, 'refreshed')['access_token']}',
      );
      expect(
        server.writes.single.headers['authorization'],
        'Bearer ${_session(_alice, 'refreshed')['access_token']}',
      );
    },
  );

  test('an expired session refreshes only while the captured actor is still current', () async {
    server.expiresAt = 1;
    await login(_alice);
    expect(client.auth.currentSession!.isExpired, isTrue);
    final action = transport.prepare(_alice, true, stillEligible: () => true)!;
    server.expiresAt = 1893456000;
    server.generation = 'refreshed';
    expect(await action(), isTrue);
    expect(
      server.authRequests.last.url.queryParameters['grant_type'],
      'refresh_token',
    );
    expect(
      server.writes.single.headers['authorization'],
      'Bearer ${_session(_alice, 'refreshed')['access_token']}',
    );
  });

  test(
    'an expired captured revocation does not refresh or use another account',
    () async {
      server.expiresAt = 1;
      await login(_alice);
      final off = transport.prepare(_alice, false, stillEligible: () => false)!;
      server.expiresAt = 1893456000;
      await login(_bob);
      final authCount = server.authRequests.length;
      expect(await off(), isFalse);
      expect(server.authRequests.length, authCount);
      expect(server.reads, isEmpty);
      expect(server.writes, isEmpty);
    },
  );

  test('OFF conflict retries stop after three retries and never repeat the state lookup', () async {
    server.writeOverride = (request) async {
      final saved = server.states[_alice] ?? (consent: false, revision: 0);
      server.states[_alice] = (consent: false, revision: saved.revision + 1);
      return {'applied': false, ...server.state(_alice)};
    };
    expect(
      await transport.prepare(_alice, false, stillEligible: () => false)!(),
      isFalse,
    );
    expect(server.reads.length, 1);
    expect(server.writes.length, 4);
    expect(server.state(_alice), {'consent': false, 'revision': 4});
  });

  test(
    'OFF retries confirmed conflicts and persists revocation when it wins',
    () async {
      server.states[_alice] = (consent: true, revision: 4);
      server.writeOverride = (request) async {
        if (server.writes.length <= 3) {
          final saved = server.states[_alice]!;
          server.states[_alice] = (consent: true, revision: saved.revision + 1);
        }
        return server.apply(request);
      };
      expect(
        await transport.prepare(_alice, false, stillEligible: () => false)!(),
        isTrue,
      );
      expect(server.state(_alice), {'consent': false, 'revision': 8});
      expect(server.writes.map((request) => jsonDecode(request.body)), [
        {'consent': false, 'expected_revision': 4},
        {'consent': false, 'expected_revision': 5},
        {'consent': false, 'expected_revision': 6},
        {'consent': false, 'expected_revision': 7},
      ]);
      expect(server.reads.length, 1);
    },
  );

  for (final stage in ['read', 'write']) {
    for (final outcome in ['timeout', 'error', 'malformed']) {
      test(
        '$stage $outcome skips consent without retrying an indeterminate request',
        () async {
          final pending = Completer<Object>();
          Future<Object> failure(http.Request request) async {
            if (outcome == 'timeout') return pending.future;
            if (outcome == 'error') {
              throw http.ClientException('synthetic response loss');
            }
            return {'consent': true, 'revision': 'invalid'};
          }

          if (stage == 'read') {
            server.readOverride = failure;
          } else {
            server.writeOverride = failure;
          }
          transport = AdoptionMeasurementConsent(
            client,
            timeout: const Duration(milliseconds: 10),
          );
          try {
            expect(
              await transport.prepare(
                _alice,
                true,
                stillEligible: () => true,
              )!(),
              isFalse,
            );
            expect(server.reads.length, 1);
            expect(server.writes.length, stage == 'read' ? 0 : 1);
          } finally {
            if (!pending.isCompleted) {
              pending.complete({'consent': false, 'revision': 0});
            }
          }
        },
      );
    }
  }
}
