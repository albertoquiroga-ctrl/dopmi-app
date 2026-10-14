import 'dart:async';

import 'package:dopmi_mobile/features/payments/connect_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> session() => {
  'client_secret': 'synthetic_session_secret',
  'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
};
void main() {
  test(
    'Connect rejects live/web/unsupported/disabled before SDK or server',
    () async {
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
    },
  );
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
          expect(e.message, contains('Consulta el estado'));
          expect(e.message, isNot(contains('private_processor_detail')));
        }
      }
    },
  );
}
