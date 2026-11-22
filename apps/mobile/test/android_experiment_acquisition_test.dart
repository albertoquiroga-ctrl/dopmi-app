import 'dart:async';

import 'package:dopmi_mobile/core/android_rescuer_acquisition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _token = '0123456789abcdef0123456789abcdef';
const _referrer =
    'utm_source=facebook&utm_medium=organic_comment'
    '&utm_campaign=dopmi_rescatistas_mty_p60_v1&utm_content=$_token';
final _now = DateTime.utc(2026, 11, 21);

PlayInstall _install({String referrer = _referrer, int ageDays = 1}) => (
  referrer: referrer,
  clickedAtSeconds:
      _now.subtract(Duration(days: ageDays)).millisecondsSinceEpoch ~/ 1000,
  installedAtSeconds: _now.millisecondsSinceEpoch ~/ 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await SharedPreferences.getInstance();
  });

  AndroidRescuerAcquisition acquisition({
    Future<PlayInstall?> Function()? read,
    void Function(String)? diagnostics,
  }) => AndroidRescuerAcquisition(
    store,
    'test',
    now: () => _now,
    readInstall: read ?? () async => _install(),
    onDiagnostic: diagnostics,
  );

  test(
    'new campaign sends only its opaque token and valid Play click',
    () async {
      final diagnostics = <String>[];
      final claims = <({String token, DateTime click})>[];
      var legacyCalls = 0;
      await acquisition(diagnostics: diagnostics.add).record(
        owner: 'alice',
        sessionStillEligible: () => true,
        send: (_, _) async => legacyCalls++,
        sendPlacement: (token, click) async {
          claims.add((token: token, click: click));
          return AndroidExperimentClaimResult.recorded;
        },
      );
      expect(legacyCalls, 0);
      expect(claims, [
        (token: _token, click: _now.subtract(const Duration(days: 1))),
      ]);
      expect(store.getBool('dopmi.test.play_acquisition_processed'), isTrue);
      expect(store.getString('dopmi.test.play_acquisition_owner'), isNull);
      expect(diagnostics.join(), isNot(contains(_token)));
      expect(diagnostics.join(), isNot(contains(_referrer)));
    },
  );

  test(
    'legacy campaigns retain their original claim and skip placement RPC',
    () async {
      final sent = <String>[];
      await acquisition(
        read: () async => _install(
          referrer:
              'utm_source=facebook&utm_medium=organic_comment'
              '&utm_campaign=dopmi_rescatistas_mty_personal-a&utm_content=personal-a',
        ),
      ).record(
        owner: 'alice',
        sessionStillEligible: () => true,
        send: (variant, _) async => sent.add(variant),
        sendPlacement: (_, _) async => fail('Legacy claim used new RPC'),
      );
      expect(sent, ['personal-a']);
    },
  );

  test(
    'only exact campaign grammar is accepted, without a legacy fallback',
    () async {
      final invalid = [
        '$_referrer&utm_extra=1',
        '$_referrer&utm_content=$_token',
        _referrer.replaceFirst('facebook', 'instagram'),
        _referrer.replaceFirst('organic_comment', 'cpc'),
        _referrer.replaceFirst('p60_v1', 'p60_v2'),
        _referrer.replaceFirst(_token, _token.toUpperCase()),
        _referrer.replaceFirst(_token, _token.substring(1)),
        _referrer.replaceFirst(_token, '${_token}a'),
        _referrer.replaceFirst(_token, 'personal-a'),
        _referrer.replaceFirst(_token, '${_token.substring(0, 31)}g'),
        '$_referrer#fragment',
      ];
      for (final sample in invalid) {
        SharedPreferences.setMockInitialValues({});
        store = await SharedPreferences.getInstance();
        var calls = 0;
        await acquisition(read: () async => _install(referrer: sample)).record(
          owner: 'alice',
          sessionStillEligible: () => true,
          send: (_, _) async => calls++,
          sendPlacement: (_, _) async {
            calls++;
            return AndroidExperimentClaimResult.recorded;
          },
        );
        expect(calls, 0, reason: sample);
      }
    },
  );

  test('expired Play clicks never claim a placement', () async {
    await acquisition(read: () async => _install(ageDays: 14)).record(
      owner: 'alice',
      sessionStillEligible: () => true,
      send: (_, _) async => fail('Expired click used legacy RPC'),
      sendPlacement: (_, _) async => fail('Expired click was sent'),
    );
  });

  test(
    'consent conflict stays pending for its owner and can retry after sync',
    () async {
      final service = acquisition();
      var aliceCalls = 0;
      var bobCalls = 0;
      Future<void> attempt(String owner) => service.record(
        owner: owner,
        sessionStillEligible: () => true,
        send: (_, _) async => fail('Placement fell back to legacy'),
        sendPlacement: (_, _) async {
          if (owner == 'bob') bobCalls++;
          aliceCalls++;
          return aliceCalls == 1
              ? AndroidExperimentClaimResult.consentChanged
              : AndroidExperimentClaimResult.recorded;
        },
      );
      await attempt('alice');
      expect(
        store.getBool('dopmi.test.play_acquisition_processed'),
        isNot(isTrue),
      );
      expect(store.getString('dopmi.test.play_acquisition_owner'), 'alice');
      await attempt('bob');
      expect(bobCalls, 0);
      await attempt('alice');
      expect(aliceCalls, 2);
      expect(store.getBool('dopmi.test.play_acquisition_processed'), isTrue);
      await attempt('alice');
      expect(aliceCalls, 2);
    },
  );

  for (final result in [
    AndroidExperimentClaimResult.recorded,
    AndroidExperimentClaimResult.alreadyRecorded,
    AndroidExperimentClaimResult.ineligible,
    AndroidExperimentClaimResult.invalidPlacement,
  ]) {
    test(
      '$result is terminal without falling back or enrolling twice',
      () async {
        var calls = 0;
        final service = acquisition();
        Future<void> attempt() => service.record(
          owner: 'alice',
          sessionStillEligible: () => true,
          send: (_, _) async => fail('Placement fell back to legacy'),
          sendPlacement: (_, _) async {
            calls++;
            return result;
          },
        );
        await attempt();
        await attempt();
        expect(calls, 1);
        expect(store.getBool('dopmi.test.play_acquisition_processed'), isTrue);
      },
    );
  }

  test('missing placement handler does not burn a valid placement', () async {
    await acquisition().record(
      owner: 'alice',
      sessionStillEligible: () => true,
      send: (_, _) async => fail('Placement fell back to legacy'),
    );
    expect(
      store.getBool('dopmi.test.play_acquisition_processed'),
      isNot(isTrue),
    );
  });

  test('uncertain RPC keeps the pending owner and never falls back', () async {
    final service = acquisition();
    await service.record(
      owner: 'alice',
      sessionStillEligible: () => true,
      send: (_, _) async => fail('Placement fell back to legacy'),
      sendPlacement: (_, _) async => throw StateError('Uncertain response'),
    );
    expect(
      store.getBool('dopmi.test.play_acquisition_processed'),
      isNot(isTrue),
    );
    expect(store.getString('dopmi.test.play_acquisition_owner'), 'alice');
  });

  test(
    'explicit OFF does not read the referrer or create owner state',
    () async {
      var reads = 0;
      await acquisition(
        read: () async {
          reads++;
          return _install();
        },
      ).record(
        owner: 'alice',
        sessionStillEligible: () => false,
        send: (_, _) async => fail('OFF used legacy RPC'),
        sendPlacement: (_, _) async => fail('OFF used placement RPC'),
      );
      expect(reads, 0);
      expect(store.getKeys(), isEmpty);
    },
  );

  test(
    'withdrawal while Play is read prevents the pending placement claim',
    () async {
      final started = Completer<void>();
      final install = Completer<PlayInstall?>();
      var eligible = true;
      final pending =
          acquisition(
            read: () {
              started.complete();
              return install.future;
            },
          ).record(
            owner: 'alice',
            sessionStillEligible: () => eligible,
            send: (_, _) async => fail('Withdrawal used legacy RPC'),
            sendPlacement: (_, _) async =>
                fail('Withdrawal used placement RPC'),
          );
      await started.future;
      eligible = false;
      install.complete(_install());
      await pending;
      expect(store.getKeys(), isEmpty);
    },
  );

  test(
    'existing completed install is never reset for placement attribution',
    () async {
      await store.setBool('dopmi.test.play_acquisition_processed', true);
      await acquisition(read: () async => fail('Completed install reread Play'))
          .record(
            owner: 'alice',
            sessionStillEligible: () => true,
            send: (_, _) async => fail('Completed install claimed legacy'),
            sendPlacement: (_, _) async =>
                fail('Completed install claimed placement'),
          );
      expect(store.getBool('dopmi.test.play_acquisition_processed'), isTrue);
    },
  );
}
