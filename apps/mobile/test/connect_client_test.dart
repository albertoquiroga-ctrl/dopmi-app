import 'dart:async';

import 'package:dopmi_mobile/features/payments/connect_client.dart';
import 'package:dopmi_mobile/features/payments/payment_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> session() => {
  'client_secret': 'synthetic_session_secret',
  'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
};
void main() {
  test('Connect rejects an initial server failure before any SDK UI', () async {
    var initialized = 0, presented = 0, requests = 0, loggedOut = 0;
    final client = ConnectClient(
      key: 'pk_test_ok',
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      session: () async {
        requests++;
        throw StateError('private_processor_detail');
      },
      initialize: (_, fetch) async {
        initialized++;
        // The native plugin can consume callback failures without propagating
        // them to run(), then show its own misleading authentication screen.
        try {
          await fetch();
        } catch (_) {}
      },
      present: () async {
        presented++;
      },
      logout: () async {
        loggedOut++;
      },
    );
    await expectLater(client.run(() => true), throwsFormatException);
    expect([requests, initialized, presented, loggedOut], [1, 0, 0, 1]);
  });
  test(
    'Connect validates the initial session before initializing the SDK',
    () async {
      for (final invalid in [
        {...session(), 'expires_at': 1},
        {...session(), 'client_secret': 'short'},
        {...session(), 'client_secret': '                '},
        {...session(), 'expires_at': 'future'},
      ]) {
        var initialized = 0, presented = 0;
        final client = ConnectClient(
          key: 'pk_test_ok',
          enabled: true,
          web: false,
          platform: TargetPlatform.android,
          session: () async => invalid,
          initialize: (_, fetch) async {
            initialized++;
            await fetch();
          },
          present: () async {
            presented++;
          },
          logout: () async {},
        );
        await expectLater(client.run(() => true), throwsFormatException);
        expect([initialized, presented], [0, 0]);
      }
    },
  );
  test(
    'Connect shares the request while its initial session is loading',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      var requests = 0, initialized = 0, presented = 0;
      final client = ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () async {
          requests++;
          return gate.future;
        },
        initialize: (_, fetch) async {
          initialized++;
          await fetch();
        },
        present: () async {
          presented++;
        },
        logout: () async {},
      );
      final one = client.run(() => true), two = client.run(() => true);
      expect([requests, initialized, presented], [1, 0, 0]);
      gate.complete(session());
      await Future.wait([one, two]);
      expect([requests, initialized, presented], [1, 1, 1]);
    },
  );
  test('Connect opens LIVE only with explicit production mode', () async {
    var initialized = 0, requests = 0, presented = 0, loggedOut = 0;
    final client = ConnectClient(
      key: 'pk_live_synthetic',
      paymentEnvironment: const PaymentEnvironment(environment: 'production'),
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      session: () async {
        requests++;
        return session();
      },
      initialize: (key, fetch) async {
        expect(key, 'pk_live_synthetic');
        expect(await fetch(), 'synthetic_session_secret');
        initialized++;
      },
      present: () async {
        presented++;
      },
      logout: () async {
        loggedOut++;
      },
    );
    expect(client.available, true);
    await client.run(() => true);
    expect([initialized, requests, presented, loggedOut], [1, 1, 1, 1]);
  });
  test(
    'Connect consumes the initial session once and refreshes explicitly',
    () async {
      late Future<String> Function() fetch;
      var requests = 0;
      final client = ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () async {
          requests++;
          return {...session(), 'client_secret': 'synthetic_session_$requests'};
        },
        initialize: (_, provider) async {
          expect(requests, 1);
          fetch = provider;
        },
        present: () async {
          expect(await fetch(), 'synthetic_session_1');
          expect(requests, 1);
          expect(await fetch(), 'synthetic_session_2');
          expect(requests, 2);
        },
        logout: () async {},
      );
      await client.run(() => true);
      await expectLater(fetch(), throwsFormatException);
      expect(requests, 2);
    },
  );
  test(
    'Connect never presents if the actor leaves during initialization',
    () async {
      var current = true, presented = 0;
      final client = ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () async => session(),
        initialize: (_, _) async {
          current = false;
        },
        present: () async {
          presented++;
        },
        logout: () async {},
      );
      await expectLater(client.run(() => current), throwsFormatException);
      expect(presented, 0);
    },
  );
  test('Connect rechecks expiration before showing native UI', () async {
    var clock = DateTime.fromMillisecondsSinceEpoch(1000000);
    var presented = 0, requests = 0;
    final client = ConnectClient(
      key: 'pk_test_ok',
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      now: () => clock,
      session: () async {
        requests++;
        return {...session(), 'expires_at': 1010};
      },
      initialize: (_, _) async {
        clock = clock.add(const Duration(seconds: 10));
      },
      present: () async {
        presented++;
      },
      logout: () async {},
    );
    await expectLater(client.run(() => true), throwsFormatException);
    expect([requests, presented], [1, 0]);
  });
  test(
    'Connect never delivers an initial secret that expires before consumption',
    () async {
      var clock = DateTime.fromMillisecondsSinceEpoch(1000000);
      var delivered = false, requests = 0;
      late Future<String> Function() fetch;
      final client = ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        now: () => clock,
        session: () async {
          requests++;
          return {...session(), 'expires_at': 1010};
        },
        initialize: (_, provider) async {
          fetch = provider;
        },
        present: () async {
          clock = clock.add(const Duration(seconds: 10));
          await fetch();
          delivered = true;
        },
        logout: () async {},
      );
      await expectLater(client.run(() => true), throwsFormatException);
      expect(delivered, false);
      expect(requests, 1);
    },
  );
  test('Connect prevents refresh requests after its actor changes', () async {
    var current = true, requests = 0;
    late Future<String> Function() fetch;
    final client = ConnectClient(
      key: 'pk_test_ok',
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      session: () async {
        requests++;
        return session();
      },
      initialize: (_, provider) async {
        fetch = provider;
      },
      present: () async {
        await fetch();
        current = false;
        await fetch();
      },
      logout: () async {},
    );
    await expectLater(client.run(() => current), throwsFormatException);
    expect(requests, 1);
  });
  test(
    'Connect permits only a new manual attempt after initial failure',
    () async {
      var requests = 0, initialized = 0, presented = 0;
      final client = ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () async {
          requests++;
          if (requests == 1) throw StateError('private_processor_detail');
          return session();
        },
        initialize: (_, fetch) async {
          initialized++;
          await fetch();
        },
        present: () async {
          presented++;
        },
        logout: () async {},
      );
      await expectLater(client.run(() => true), throwsFormatException);
      expect([requests, initialized, presented], [1, 0, 0]);
      await client.run(() => true);
      expect([requests, initialized, presented], [2, 1, 1]);
    },
  );
  test('Connect masks rejected or stale explicit refresh responses', () async {
    for (final failure in ['actor', 'expired', 'backend']) {
      var current = true, requests = 0, delivered = false, loggedOut = 0;
      late Future<String> Function() fetch;
      final client = ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () async {
          requests++;
          if (requests == 1) return session();
          if (failure == 'backend') {
            throw StateError('private_processor_detail');
          }
          if (failure == 'actor') current = false;
          return {...session(), if (failure == 'expired') 'expires_at': 1};
        },
        initialize: (_, provider) async {
          fetch = provider;
        },
        present: () async {
          await fetch();
          await fetch();
          delivered = true;
        },
        logout: () async {
          loggedOut++;
        },
      );
      try {
        await client.run(() => current);
        fail('must reject the refresh');
      } on FormatException catch (error) {
        expect(error.message, contains('contacta a soporte'));
        expect(error.message, isNot(contains('private_processor_detail')));
        expect(error.message, isNot(contains('synthetic_session_secret')));
      }
      expect([requests, loggedOut], [2, 1]);
      expect(delivered, false);
    }
  });
  test('Connect masks cleanup failures before SDK initialization', () async {
    final client = ConnectClient(
      key: 'pk_test_ok',
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      session: () async => throw StateError('private_processor_detail'),
      initialize: (_, _) async => fail('must not initialize'),
      present: () async => fail('must not present'),
      logout: () async => throw StateError('private_native_detail'),
    );
    try {
      await client.run(() => true);
      fail('must reject');
    } on FormatException catch (error) {
      expect(error.message, contains('contacta a soporte'));
      expect(error.message, isNot(contains('private_processor_detail')));
      expect(error.message, isNot(contains('private_native_detail')));
    }
  });
  test('Connect rejects missing, crossed and unknown production configuration before the server', () async {
    for (final config in [
      (mode: 'production', key: 'pk_test_synthetic'),
      (mode: 'production', key: ''),
      (mode: 'production', key: 'sk_live_synthetic'),
      (mode: 'unknown', key: 'pk_live_synthetic'),
    ]) {
      final client = ConnectClient(
        key: config.key,
        paymentEnvironment: PaymentEnvironment(environment: config.mode),
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () async => fail('must not request a session'),
        initialize: (_, _) async => fail('must not initialize'),
      );
      expect(client.available, false);
      await expectLater(client.run(() => true), throwsFormatException);
    }
  });
  test('Connect rejects a LIVE key in TEST, web, unsupported and disabled before SDK or server', () async {
    for (final config in [
      ConnectClient(
        key: 'pk_live_invalid',
        enabled: true,
        platform: TargetPlatform.android,
        session: () async => throw StateError('server'),
      ),
      ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: true,
        platform: TargetPlatform.android,
        session: () async => throw StateError('server'),
      ),
      ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.windows,
        session: () async => throw StateError('server'),
      ),
      ConnectClient(
        key: 'pk_test_ok',
        enabled: false,
        platform: TargetPlatform.android,
        session: () async => throw StateError('server'),
      ),
    ]) {
      await expectLater(config.run(() => true), throwsFormatException);
    }
  });
  test('Connect double tap shares one session/presentation and clears native state', () async {
    var requests = 0, presented = 0, loggedOut = 0;
    final gate = Completer<void>();
    final client = ConnectClient(
      key: 'pk_test_ok',
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      session: () async {
        requests++;
        return session();
      },
      initialize: (_, fetch) async {
        expect(await fetch(), 'synthetic_session_secret');
      },
      present: () async {
        presented++;
        await gate.future;
      },
      logout: () async {
        loggedOut++;
      },
    );
    final one = client.run(() => true), two = client.run(() => true);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(presented, 1);
    expect(loggedOut, 0);
    gate.complete();
    await Future.wait([one, two]);
    expect(loggedOut, 1);
  });
  test(
    'Connect actor switch during fetch never returns a session to native',
    () async {
      var current = true,
          delivered = false,
          presented = false,
          loggedOut = false;
      final client = ConnectClient(
        key: 'pk_test_ok',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () async {
          current = false;
          return session();
        },
        initialize: (_, fetch) async {
          await fetch();
          delivered = true;
        },
        present: () async {
          presented = true;
        },
        logout: () async {
          loggedOut = true;
        },
      );
      await expectLater(client.run(() => current), throwsFormatException);
      expect(delivered, false);
      expect(presented, false);
      expect(loggedOut, true);
    },
  );
  test(
    'Connect rejects expired secret and masks processor error details',
    () async {
      for (final broken in [true, false]) {
        final client = ConnectClient(
          key: 'pk_test_ok',
          enabled: true,
          web: false,
          platform: TargetPlatform.android,
          session: () async {
            if (broken) throw StateError('private_processor_detail');
            return {...session(), 'expires_at': 1};
          },
          initialize: (_, fetch) async {
            await fetch();
          },
          present: () async => fail('must not present'),
          logout: () async {},
        );
        try {
          await client.run(() => true);
          fail('must reject');
        } on FormatException catch (e) {
          expect(e.message, contains('contacta a soporte'));
          expect(e.message, isNot(contains('private_processor_detail')));
        }
      }
    },
  );
}
