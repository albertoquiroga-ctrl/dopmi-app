import 'dart:async';

import 'package:dopmi_mobile/core/android_rescuer_acquisition.dart';
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
}) async {
  if (resetPreferences) SharedPreferences.setMockInitialValues({});
  return AndroidRescuerAcquisition(
    await SharedPreferences.getInstance(),
    'test',
    readInstall: read,
    now: () => now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
