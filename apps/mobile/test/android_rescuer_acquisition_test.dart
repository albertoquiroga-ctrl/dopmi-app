import 'dart:async';

import 'package:dopmi_mobile/core/android_rescuer_acquisition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const referrer =
    'utm_source=facebook&utm_medium=organic_comment'
    '&utm_campaign=dopmi_rescatistas_mty_pagina-a&utm_content=pagina-a';
final now = DateTime.utc(2026, 11, 12);

PlayInstall install({
  String source = referrer,
  Duration age = const Duration(days: 2),
  Duration installDelay = Duration.zero,
}) => (
  referrer: source,
  clickedAtSeconds: now.subtract(age).millisecondsSinceEpoch ~/ 1000,
  installedAtSeconds:
      now.subtract(age).add(installDelay).millisecondsSinceEpoch ~/ 1000,
);

Future<AndroidRescuerAcquisition> service(
  Future<PlayInstall?> Function() read, {
  bool resetPreferences = true,
  void Function(String)? onDiagnostic,
}) async {
  if (resetPreferences) SharedPreferences.setMockInitialValues({});
  return AndroidRescuerAcquisition(
    await SharedPreferences.getInstance(),
    'test',
    readInstall: read,
    now: () => now,
    onDiagnostic: onDiagnostic,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native diagnostic request is off by default and explicitly opt-in',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('io.dopmi.app/play_install_referrer');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {
          'referrer': referrer,
          'clickedAtSeconds': install().clickedAtSeconds,
          'installedAtSeconds': install().installedAtSeconds,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      expect(await readAndroidPlayInstall(), install());
      expect(await readAndroidPlayInstall(diagnosticsEnabled: true), install());
      expect(calls.map((call) => call.method), ['read', 'read']);
      expect(calls.map((call) => call.arguments), [
        {'diagnostics': false},
        {'diagnostics': true},
      ]);
    },
  );

  test('unknown campaign values and parameter counts stay bounded', () async {
    final diagnostics = <String>[];
    final extra = List.generate(20, (i) => '&x$i=v').join();
    final acquisition = await service(
      () async => install(
        source:
            '${referrer.replaceAll('pagina-a', 'private@example.test')}$extra',
      ),
      onDiagnostic: diagnostics.add,
    );
    final sent = <String>[];
    await acquisition.record(
      owner: 'private-account-id',
      sessionStillEligible: () => true,
      send: (variant, _) async => sent.add(variant),
    );
    expect(sent, isEmpty);
    final checks = diagnostics.singleWhere(
      (line) => line.startsWith('state=referrerRejected '),
    );
    expect(
      checks,
      contains('campaign=false content=false variant=none unknown=16'),
    );
    expect(diagnostics.join('\n'), isNot(contains('private')));
    expect(diagnostics.join('\n'), isNot(contains('@')));
  });

  test(
    'diagnostics explain clock rejection without exposing timestamps',
    () async {
      final samples = [
        (
          sample: (
            referrer: referrer,
            clickedAtSeconds: 0,
            installedAtSeconds: install().installedAtSeconds,
          ),
          check: 'positive=false',
        ),
        (
          sample: install(installDelay: const Duration(seconds: -1)),
          check: 'order=false',
        ),
        (
          sample: install(installDelay: const Duration(days: 3)),
          check: 'notFuture=false',
        ),
        (sample: install(age: const Duration(days: 14)), check: 'window=false'),
      ];
      for (final sample in samples) {
        final diagnostics = <String>[];
        final acquisition = await service(
          () async => sample.sample,
          onDiagnostic: diagnostics.add,
        );
        final sent = <String>[];
        await acquisition.record(
          owner: 'private-account-id',
          sessionStillEligible: () => true,
          send: (variant, _) async => sent.add(variant),
        );
        expect(sent, isEmpty);
        final checks = diagnostics.singleWhere(
          (line) => line.startsWith('state=referrerRejected '),
        );
        expect(checks, contains(sample.check));
        expect(
          checks,
          isNot(contains(sample.sample.installedAtSeconds.toString())),
        );
      }
    },
  );

  test('unrecognized encoding reports only an exact-match failure', () async {
    final diagnostics = <String>[];
    final acquisition = await service(
      () async => install(source: 'utm_source=%ZZ'),
      onDiagnostic: diagnostics.add,
    );
    final sent = <String>[];
    await acquisition.record(
      owner: 'private-account-id',
      sessionStillEligible: () => true,
      send: (variant, _) async => sent.add(variant),
    );
    expect(sent, isEmpty);
    final checks = diagnostics.singleWhere(
      (line) => line.startsWith('state=referrerRejected '),
    );
    expect(checks, contains('parsed=true source=false'));
    expect(checks, isNot(contains('%ZZ')));
  });

  test(
    'diagnostics expose bounded checks without referral or owner data',
    () async {
      final diagnostics = <String>[];
      const privateValue = 'private.person@example.test';
      final acquisition = await service(
        () async => install(
          source:
              '$referrer&email=$privateValue'
              '&email=Bearer-private-token&owner=private-owner',
        ),
        onDiagnostic: diagnostics.add,
      );
      final sent = <String>[];
      await acquisition.record(
        owner: 'private-account-id',
        sessionStillEligible: () => true,
        send: (variant, _) async => sent.add(variant),
      );

      expect(sent, isEmpty);
      expect(diagnostics, contains('state=readStarted'));
      expect(diagnostics, contains(startsWith('state=referrerRejected ')));
      final checks = diagnostics.singleWhere(
        (line) => line.startsWith('state=referrerRejected '),
      );
      expect(
        checks,
        contains('source=true medium=true campaign=true content=true'),
      );
      expect(checks, contains('variant=pagina-a unknown=2 duplicate=1'));
      final output = diagnostics.join('\n');
      for (final value in [
        privateValue,
        'Bearer',
        'private-owner',
        'private-account-id',
        referrer,
        install().clickedAtSeconds.toString(),
      ]) {
        expect(output, isNot(contains(value)));
      }
    },
  );

  test(
    'diagnostics distinguish missing and failed reads without error text',
    () async {
      final samples = <({Future<PlayInstall?> Function() read, String state})>[
        (read: () async => null, state: 'readNull'),
        (
          read: () async => throw PlatformException(
            code: 'play_referrer_unavailable',
            message: 'Bearer-private-token',
          ),
          state: 'readUnavailable',
        ),
        (
          read: () async => throw StateError('private.person@example.test'),
          state: 'readError',
        ),
      ];
      for (final sample in samples) {
        final diagnostics = <String>[];
        final acquisition = await service(
          sample.read,
          onDiagnostic: diagnostics.add,
        );
        final sent = <String>[];
        await acquisition.record(
          owner: 'private-account-id',
          sessionStillEligible: () => true,
          send: (variant, _) async => sent.add(variant),
        );
        expect(sent, isEmpty);
        expect(diagnostics, contains('state=${sample.state}'));
        final output = diagnostics.join('\n');
        expect(output, isNot(contains('private')));
        expect(output, isNot(contains('Bearer')));
        expect(output, isNot(contains('@')));
      }
    },
  );

  test(
    'diagnostics report send outcomes and cannot interrupt attribution',
    () async {
      final diagnostics = <String>[];
      final acquisition = await service(
        () async => install(),
        onDiagnostic: diagnostics.add,
      );
      await acquisition.record(
        owner: 'private-account-id',
        sessionStillEligible: () => true,
        send: (_, _) async => throw StateError('Bearer-private-token'),
      );
      expect(diagnostics, contains('state=sendAttempted'));
      expect(diagnostics, contains('state=sendError'));
      expect(diagnostics.join('\n'), isNot(contains('private')));

      final sent = <String>[];
      final observerFails = await service(
        () async => install(),
        onDiagnostic: (_) => throw StateError('local observer failed'),
      );
      await observerFails.record(
        owner: 'private-account-id',
        sessionStillEligible: () => true,
        send: (variant, _) async => sent.add(variant),
      );
      expect(sent, ['pagina-a']);
    },
  );

  test('an eligible Play install sends only its variant once', () async {
    var reads = 0;
    final acquisition = await service(() async {
      reads++;
      return install(
        age: const Duration(days: 14) - const Duration(seconds: 1),
      );
    });
    final sent = <(String, DateTime)>[];

    for (final owner in ['alice', 'alice', 'bob']) {
      await acquisition.record(
        owner: owner,
        sessionStillEligible: () => true,
        send: (variant, clickedAt) async => sent.add((variant, clickedAt)),
      );
    }

    expect(reads, 1);
    expect(sent, [
      (
        'pagina-a',
        now.subtract(const Duration(days: 14)).add(const Duration(seconds: 1)),
      ),
    ]);
  });

  test('off, changed and signed-out sessions never send', () async {
    var reads = 0;
    final started = Completer<void>();
    final pending = Completer<PlayInstall>();
    final acquisition = await service(() {
      reads++;
      started.complete();
      return pending.future;
    });
    var active = false;
    final sent = <String>[];

    Future<void> record() => acquisition.record(
      owner: 'alice',
      sessionStillEligible: () => active,
      send: (variant, _) async => sent.add(variant),
    );

    await record();
    expect(reads, 0);

    active = true;
    final result = record();
    await started.future;
    active = false;
    pending.complete(install());
    await result;
    expect(reads, 1);
    expect(sent, isEmpty);
  });

  test('an ambiguous send only retries for the original account', () async {
    final acquisition = await service(() async => install());
    final attempted = <String>[];

    await acquisition.record(
      owner: 'alice',
      sessionStillEligible: () => true,
      send: (variant, _) async {
        attempted.add('alice:$variant');
        throw TimeoutException('connection closed');
      },
    );

    final restarted = await service(
      () async => install(),
      resetPreferences: false,
    );
    for (final owner in ['bob', 'alice', 'bob']) {
      await restarted.record(
        owner: owner,
        sessionStillEligible: () => true,
        send: (variant, _) async => attempted.add('$owner:$variant'),
      );
    }
    expect(attempted, ['alice:pagina-a', 'alice:pagina-a']);
    expect(
      restarted.preferences.getString('dopmi.test.play_acquisition_owner'),
      isNull,
    );
  });

  test('a transient Play error can retry with the next consent sync', () async {
    var attempts = 0;
    final acquisition = await service(() async {
      if (attempts++ == 0) throw TimeoutException('Play unavailable');
      return install();
    });
    final sent = <String>[];
    for (var i = 0; i < 2; i++) {
      await acquisition.record(
        owner: 'alice',
        sessionStillEligible: () => true,
        send: (variant, _) async => sent.add(variant),
      );
    }
    expect(attempts, 2);
    expect(sent, ['pagina-a']);
  });

  test(
    'organic, invalid, duplicate and out-of-window referrals are ignored',
    () async {
      for (final sample in [
        install(source: 'utm_source=google-play&utm_medium=organic'),
        install(source: '$referrer&utm_content=personal-a'),
        install(source: '$referrer&extra=anything'),
        install(source: referrer.replaceFirst('pagina-a', 'personal-a')),
        install(source: referrer.replaceAll('pagina-a', 'unknown')),
        install(age: const Duration(days: 14)),
        install(installDelay: const Duration(seconds: -1)),
        install(installDelay: const Duration(days: 3)),
        install(
          age: now.difference(
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        ),
        install(age: const Duration(seconds: -1)),
      ]) {
        final acquisition = await service(() async => sample);
        final sent = <String>[];
        await acquisition.record(
          owner: 'alice',
          sessionStillEligible: () => true,
          send: (variant, _) async => sent.add(variant),
        );
        expect(sent, isEmpty, reason: 'Unexpected attribution for $sample');
      }
    },
  );
}
