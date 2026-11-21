import 'dart:async';

import 'package:dopmi_mobile/core/ios_cpp_acquisition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final receivedAt = DateTime.utc(2026, 11, 20, 23);
final personalA = Uri.parse('io.dopmi.app://acquire/personal-a');

Future<SharedPreferences> preferences({bool reset = true}) async {
  if (reset) SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

IosCppAcquisition acquisition(
  SharedPreferences store, {
  String namespace = 'test',
  DateTime Function()? now,
  bool? supported = true,
}) => IosCppAcquisition(
  store,
  namespace,
  now: now ?? () => receivedAt,
  supported: supported,
);

Future<void> record(
  IosCppAcquisition service,
  List<String> sent, {
  String owner = 'alice',
  bool Function()? eligible,
  IosCppClaimResult result = IosCppClaimResult.recorded,
}) => service.record(
  owner: owner,
  sessionStillEligible: eligible ?? () => true,
  send: (variant) async {
    sent.add('$owner:$variant');
    return result;
  },
);

/// Models external persistence delays/failures while keeping successful writes
/// and reads in the real SharedPreferences implementation used by the service.
class ControlledPreferences implements SharedPreferences {
  ControlledPreferences(this.store);
  final SharedPreferences store;
  Completer<void>? holdWrite;
  Completer<void>? writeStarted;
  bool failWrites = false;
  bool failStringWrites = false;

  @override
  String? getString(String key) => store.getString(key);
  @override
  bool? getBool(String key) => store.getBool(key);
  @override
  Future<bool> setString(String key, String value) async {
    final hold = holdWrite;
    holdWrite = null;
    if (hold != null) {
      writeStarted?.complete();
      await hold.future;
    }
    if (failWrites || failStringWrites) return false;
    return store.setString(key, value);
  }

  @override
  Future<bool> setBool(String key, bool value) async =>
      failWrites ? false : store.setBool(key, value);
  @override
  Future<bool> remove(String key) => store.remove(key);
  @override
  Future<void> reload() => store.reload();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a captured personal-a survives restart and is sent only after account binding', () async {
    final store = await preferences();
    final first = acquisition(store);
    await first.capture(personalA);
    final sent = <String>[];
    await record(first, sent);
    expect(sent, isEmpty);

    final restarted = acquisition(await preferences(reset: false));
    await restarted.observeOwner('alice');
    await record(restarted, sent);
    await record(restarted, sent);
    expect(sent, ['alice:personal-a']);
    expect(
      store.getKeys().map(store.get).join(' '),
      isNot(contains('io.dopmi.app://')),
    );
  });

  test(
    'only the canonical single pilot URI can create a pending source',
    () async {
      for (final uri in [
        'io.dopmi.app://acquire/personal-b',
        'io.dopmi.app://acquire/pagina-a',
        'io.dopmi.app://acquire/pagina-b',
        'io.dopmi.app://acquire/personal-a/',
        'io.dopmi.app://acquire/personal-a/extra',
        'io.dopmi.app://acquire/personal-a?variant=personal-a',
        'io.dopmi.app://acquire/personal-a#fragment',
        'io.dopmi.app://user@acquire/personal-a',
        'io.dopmi.app://acquire:443/personal-a',
        'io.dopmi.app://acquire/personal-A',
        'io.dopmi.app://acquire/personal%2Fa',
        'io.dopmi.app://acquire//personal-a',
        'https://www.dopmi.org/descargar/personal-a',
        'io.dopmi.app://auth/callback?code=private',
        'io.dopmi.app://content/messages/personal-a',
        'io.dopmi.app://payments/return',
      ]) {
        final service = acquisition(await preferences());
        final sent = <String>[];
        await service.capture(Uri.parse(uri));
        await service.observeOwner('alice');
        await record(service, sent);
        expect(sent, isEmpty, reason: uri);
      }
    },
  );

  test('invalid links do not consume a later valid campaign', () async {
    final service = acquisition(await preferences());
    final sent = <String>[];
    await service.observeOwner('alice');
    await service.capture(
      Uri.parse('io.dopmi.app://auth/callback?code=private'),
    );
    await record(service, sent);
    await service.capture(personalA);
    await record(service, sent);
    expect(sent, ['alice:personal-a']);
  });

  test(
    'the native gate leaves Android and other platforms unclaimed',
    () async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.iOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final service = acquisition(await preferences(), supported: null);
        final sent = <String>[];
        await service.capture(personalA);
        await service.observeOwner('alice');
        await record(service, sent);
        expect(
          sent,
          platform == TargetPlatform.iOS ? ['alice:personal-a'] : isEmpty,
        );
      }
    },
  );

  test(
    'disabled capture cannot become a source on a later supported run',
    () async {
      final store = await preferences();
      final disabled = acquisition(store, supported: false);
      final sent = <String>[];
      await disabled.capture(personalA);
      await disabled.observeOwner('alice');
      await record(disabled, sent);
      final enabled = acquisition(store);
      await enabled.observeOwner('alice');
      await record(enabled, sent);
      expect(sent, isEmpty);
      await enabled.capture(personalA);
      await record(enabled, sent);
      expect(sent, ['alice:personal-a']);
    },
  );

  test('duplicate initial and stream deliveries never extend the first receipt TTL', () async {
    var now = receivedAt;
    final store = await preferences();
    final service = acquisition(store, now: () => now);
    final sent = <String>[];
    await service.capture(personalA);
    now = receivedAt.add(const Duration(hours: 23));
    await service.capture(personalA);
    await service.observeOwner('alice');
    now = receivedAt.add(const Duration(hours: 24));
    await record(service, sent);
    expect(sent, isEmpty);

    now = receivedAt.add(const Duration(hours: 25));
    final restarted = acquisition(store, now: () => now);
    await restarted.capture(personalA);
    await restarted.observeOwner('alice');
    await record(restarted, sent);
    expect(sent, isEmpty);
  });

  test(
    'a pending source is usable immediately before its 24-hour deadline',
    () async {
      var now = receivedAt;
      final service = acquisition(await preferences(), now: () => now);
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      now = receivedAt.add(
        const Duration(hours: 24) - const Duration(milliseconds: 1),
      );
      await record(service, sent);
      expect(sent, ['alice:personal-a']);
    },
  );

  test('clock rollback invalidates the pending context instead of inventing a receipt', () async {
    var now = receivedAt;
    final service = acquisition(await preferences(), now: () => now);
    final sent = <String>[];
    await service.capture(personalA);
    await service.observeOwner('alice');
    now = receivedAt.subtract(const Duration(milliseconds: 1));
    await record(service, sent);
    now = receivedAt;
    await service.capture(personalA);
    await record(service, sent);
    expect(sent, isEmpty);
  });

  test(
    'environment namespaces cannot reuse pending or terminal state',
    () async {
      final store = await preferences();
      final dev = acquisition(store, namespace: 'dev.example');
      final prod = acquisition(store, namespace: 'prod.example');
      final sent = <String>[];
      await dev.capture(personalA);
      await prod.observeOwner('alice');
      await record(prod, sent);
      expect(sent, isEmpty);
      await dev.observeOwner('alice');
      await record(dev, sent);
      await prod.capture(personalA);
      await record(prod, sent);
      expect(sent, ['alice:personal-a', 'alice:personal-a']);
    },
  );

  test(
    'the first account owns the context before any optional network request',
    () async {
      final store = await preferences();
      final service = acquisition(store);
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      await service.observeOwner(null);
      await service.observeOwner('bob');
      await record(service, sent, owner: 'bob');
      expect(sent, isEmpty);

      final restarted = acquisition(store);
      await restarted.observeOwner('bob');
      await record(restarted, sent, owner: 'bob');
      await restarted.observeOwner('alice');
      await record(restarted, sent);
      expect(sent, ['alice:personal-a']);
    },
  );

  test('a pending source captured for an already signed-in account keeps that owner', () async {
    final service = acquisition(await preferences());
    final sent = <String>[];
    await service.observeOwner('alice');
    await service.capture(personalA);
    await service.observeOwner('bob');
    await record(service, sent, owner: 'bob');
    await service.observeOwner('alice');
    await record(service, sent);
    expect(sent, ['alice:personal-a']);
  });

  test(
    'an ineligible session does not consume consent-pending attribution',
    () async {
      final service = acquisition(await preferences());
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      await record(service, sent, eligible: () => false);
      expect(sent, isEmpty);
      await record(service, sent);
      expect(sent, ['alice:personal-a']);
    },
  );

  test(
    'a signed-out or different live owner cannot send an old account request',
    () async {
      final service = acquisition(await preferences());
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      for (final current in <String?>[null, 'bob']) {
        await service.observeOwner(current);
        await record(service, sent);
      }
      expect(sent, isEmpty);
    },
  );

  test(
    'an ambiguous request remains bound to the original account after restart',
    () async {
      final store = await preferences();
      final service = acquisition(store);
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      await service.record(
        owner: 'alice',
        sessionStillEligible: () => true,
        send: (variant) async {
          sent.add('alice:$variant');
          throw TimeoutException('network outcome unknown');
        },
      );
      final restarted = acquisition(store);
      await restarted.observeOwner('bob');
      await record(restarted, sent, owner: 'bob');
      await restarted.observeOwner('alice');
      await record(restarted, sent);
      expect(sent, ['alice:personal-a', 'alice:personal-a']);
    },
  );

  test(
    'a changed server consent stays pending for the next successful sync',
    () async {
      final service = acquisition(await preferences());
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      await record(service, sent, result: IosCppClaimResult.consentChanged);
      await record(service, sent, result: IosCppClaimResult.alreadyRecorded);
      await record(service, sent);
      expect(sent, ['alice:personal-a', 'alice:personal-a']);
    },
  );

  for (final result in [
    IosCppClaimResult.recorded,
    IosCppClaimResult.alreadyRecorded,
    IosCppClaimResult.ineligible,
  ]) {
    test(
      'a definitive $result blocks repeated links and account reuse',
      () async {
        final store = await preferences();
        final service = acquisition(store);
        final sent = <String>[];
        await service.capture(personalA);
        await service.observeOwner('alice');
        await record(service, sent, result: result);
        final restarted = acquisition(store);
        await restarted.capture(personalA);
        await restarted.observeOwner('bob');
        await record(restarted, sent, owner: 'bob');
        await restarted.observeOwner('alice');
        await record(restarted, sent);
        expect(sent, ['alice:personal-a']);
      },
    );
  }

  test(
    'explicit OFF retires the context while absence of a local choice does not',
    () async {
      final store = await preferences();
      final service = acquisition(store);
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      // No revoke call represents the fresh installation's absent local choice.
      await record(service, sent, eligible: () => false);
      await service.revoke('alice');
      final restarted = acquisition(store);
      await restarted.observeOwner('alice');
      await restarted.capture(personalA);
      await record(restarted, sent);
      expect(sent, isEmpty);
    },
  );

  test('OFF invalidates a queued claim before an earlier preference write finishes', () async {
    final store = ControlledPreferences(await preferences());
    final service = acquisition(store);
    final sent = <String>[];
    await service.capture(personalA);
    final release = Completer<void>();
    store.holdWrite = release;
    store.writeStarted = Completer<void>();
    final observing = service.observeOwner('alice');
    await store.writeStarted!.future.timeout(const Duration(seconds: 2));
    final queued = record(service, sent);
    final revoking = service.revoke('alice');
    release.complete();
    await Future.wait([observing, queued, revoking]);
    expect(sent, isEmpty);
  });

  test('a delayed OFF from another account cannot retire the current owners pending source', () async {
    final service = acquisition(await preferences());
    final sent = <String>[];
    await service.observeOwner('bob');
    await service.capture(personalA);
    await service.revoke('alice');
    await record(service, sent, owner: 'bob');
    expect(sent, ['bob:personal-a']);
  });

  test(
    'live account changes invalidate an earlier queued claim immediately',
    () async {
      final store = ControlledPreferences(await preferences());
      final service = acquisition(store);
      final sent = <String>[];
      await service.capture(personalA);
      final release = Completer<void>();
      store.holdWrite = release;
      store.writeStarted = Completer<void>();
      final observing = service.observeOwner('alice');
      await store.writeStarted!.future.timeout(const Duration(seconds: 2));
      final queued = record(service, sent);
      final switching = service.observeOwner('bob');
      release.complete();
      await Future.wait([observing, queued, switching]);
      await record(service, sent, owner: 'bob');
      expect(sent, isEmpty);
    },
  );

  test(
    'failed capture persistence cannot send from uncommitted memory',
    () async {
      final store = ControlledPreferences(await preferences())
        ..failWrites = true;
      final service = acquisition(store);
      final sent = <String>[];
      await service.capture(personalA);
      await service.observeOwner('alice');
      store.failWrites = false;
      await record(service, sent);
      expect(sent, isEmpty);
      await service.capture(personalA);
      await record(service, sent);
      expect(sent, ['alice:personal-a']);
    },
  );

  test('failed owner persistence prevents a request until the same account can bind durably', () async {
    final store = ControlledPreferences(await preferences());
    final service = acquisition(store);
    final sent = <String>[];
    await service.capture(personalA);
    store.failWrites = true;
    await service.observeOwner('alice');
    await record(service, sent);
    expect(sent, isEmpty);
    store.failWrites = false;
    await service.observeOwner('alice');
    await record(service, sent);
    expect(sent, ['alice:personal-a']);
  });

  test('failed binding keeps its first owner when another account can write successfully', () async {
    final store = ControlledPreferences(await preferences());
    final service = acquisition(store);
    final sent = <String>[];
    await service.capture(personalA);
    store.failWrites = true;
    await service.observeOwner('alice');
    store.failWrites = false;
    await service.observeOwner('bob');
    await record(service, sent, owner: 'bob');
    expect(sent, isEmpty);
    await service.observeOwner('alice');
    await record(service, sent);
    expect(sent, ['alice:personal-a']);
  });

  test('failed binding cannot survive restart as anonymous context for another account', () async {
    final store = ControlledPreferences(await preferences());
    final service = acquisition(store);
    final sent = <String>[];
    await service.capture(personalA);
    store.failWrites = true;
    await service.observeOwner('alice');
    store.failWrites = false;
    final restarted = acquisition(store);
    await restarted.capture(personalA);
    await restarted.observeOwner('bob');
    await record(restarted, sent, owner: 'bob');
    expect(sent, isEmpty);
  });

  test('a saved first-receipt fence prevents restart replay when pending persistence fails', () async {
    final store = ControlledPreferences(await preferences())
      ..failStringWrites = true;
    final service = acquisition(store);
    final sent = <String>[];
    await service.capture(personalA);
    await service.observeOwner('alice');
    store.failStringWrites = false;
    final restarted = acquisition(store);
    await restarted.capture(personalA);
    await restarted.observeOwner('bob');
    await record(restarted, sent, owner: 'bob');
    expect(sent, isEmpty);
  });

  test('another owners OFF cannot retire a first candidate awaiting pending persistence', () async {
    final store = ControlledPreferences(await preferences())
      ..failStringWrites = true;
    final service = acquisition(store);
    final sent = <String>[];
    await service.observeOwner('bob');
    await service.capture(personalA);
    await service.observeOwner('alice');
    await service.revoke('alice');
    store.failStringWrites = false;
    await service.observeOwner('bob');
    await service.capture(personalA);
    await record(service, sent, owner: 'bob');
    expect(sent, ['bob:personal-a']);
  });

  test('failed terminal persistence retains the claimed owner across restart and duplicate links', () async {
    final store = ControlledPreferences(await preferences());
    final service = acquisition(store);
    final sent = <String>[];
    await service.capture(personalA);
    await service.observeOwner('alice');
    store.failWrites = true;
    await record(service, sent);
    store.failWrites = false;
    final restarted = acquisition(store);
    await restarted.capture(personalA);
    await restarted.observeOwner('bob');
    await record(restarted, sent, owner: 'bob');
    expect(sent, ['alice:personal-a']);
  });

  test('failed OFF tombstone persistence keeps another account from reviving the context', () async {
    final store = ControlledPreferences(await preferences());
    final service = acquisition(store);
    final sent = <String>[];
    await service.capture(personalA);
    await service.observeOwner('alice');
    store.failWrites = true;
    await service.revoke('alice');
    store.failWrites = false;
    final restarted = acquisition(store);
    await restarted.capture(personalA);
    await restarted.observeOwner('bob');
    await record(restarted, sent, owner: 'bob');
    expect(sent, isEmpty);
  });
}
