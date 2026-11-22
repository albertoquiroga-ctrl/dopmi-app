import 'dart:async';

import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/core/usage_analytics_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

class ChoiceStore implements UsageAnalyticsChoiceStore {
  UsageAnalyticsChoice state = const UsageAnalyticsChoice(
    hasChoice: false,
    consent: false,
    revision: 0,
  );
  final writes = <bool>[];
  Completer<UsageAnalyticsChoice>? pendingRead;
  Completer<void>? readStarted;
  bool failSave = false;
  bool failRead = false;
  @override
  Future<UsageAnalyticsChoice> read(String owner) async {
    if (readStarted?.isCompleted == false) readStarted!.complete();
    if (failRead) throw StateError('network');
    return pendingRead?.future ?? state;
  }

  @override
  Future<UsageAnalyticsChoiceResult> save(
    String owner,
    bool enabled,
    int expectedRevision,
  ) async {
    writes.add(enabled);
    if (failSave) throw StateError('network');
    if (expectedRevision != state.revision) {
      return UsageAnalyticsChoiceResult(state: state, applied: false);
    }
    state = UsageAnalyticsChoice(
      hasChoice: true,
      consent: enabled,
      revision: state.revision + 1,
      noticeVersion: usageAnalyticsNoticeVersion,
    );
    return UsageAnalyticsChoiceResult(state: state, applied: true);
  }
}

void main() {
  late ChoiceStore store;
  late AnalyticsSpy analytics;
  late DiagnosticsSpy diagnostics;
  late MeasurementController controller;
  final syncs = <bool>[];
  Future<void> setup([Map<String, Object> saved = const {}]) async {
    SharedPreferences.setMockInitialValues(saved);
    store = ChoiceStore();
    analytics = AnalyticsSpy();
    diagnostics = DiagnosticsSpy();
    syncs.clear();
    controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      diagnostics,
      analyticsChoices: store,
      prepareAdoptionConsent: (_, value) =>
          () async => syncs.add(value),
    );
    addTearDown(controller.dispose);
    await controller.prepareStartup();
  }

  test(
    'uncertain read keeps local ON paused without global revocation',
    () async {
      await setup({'dopmi.test.one.analytics': true});
      store.failRead = true;
      await controller.owner('one');
      await controller.consentReady;
      expect(controller.analyticsEnabled, isFalse);
      expect(syncs, isEmpty);
      expect(store.writes, isEmpty);
    },
  );

  test(
    'uncertain same-owner startup pauses without resetting Analytics identity',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': true,
      });
      store.failRead = true;

      await controller.owner('one');
      await controller.consentReady;

      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
      expect(analytics.resets, 0);
      expect(
        controller.preferences.getString('dopmi.analyticsOwner'),
        'dopmi.test.one.analytics',
      );
    },
  );

  test(
    'uncertain same-owner refresh recovers the original Analytics identity',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': true,
      });
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: true,
        revision: 9,
      );
      await controller.owner('one');
      await controller.consentReady;
      expect(controller.analyticsEnabled, isTrue);
      expect(analytics.resets, 0);

      store.failRead = true;
      await controller.owner('one', refresh: true);
      await controller.event('contact_started');
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.events, isEmpty);
      expect(syncs, [true]);

      store.failRead = false;
      await controller.owner('one', refresh: true);
      await controller.consentReady;
      await controller.event('contact_started');

      expect(controller.analyticsEnabled, isTrue);
      expect(analytics.enabledValue, isTrue);
      expect(analytics.events, ['contact_started']);
      expect(store.writes, isEmpty);
      expect(syncs, [true, true]);
      expect(analytics.resets, 0);
      expect(
        controller.preferences.getString('dopmi.analyticsOwner'),
        'dopmi.test.one.analytics',
      );
    },
  );

  test('restored remote ON retains its identity through uncertainty without a local preference', () async {
    await setup({'dopmi.analyticsOwner': 'dopmi.test.one.analytics'});
    store.state = const UsageAnalyticsChoice(
      hasChoice: true,
      consent: true,
      revision: 9,
    );
    await controller.owner('one');
    expect(controller.analyticsEnabled, isTrue);
    expect(controller.preferences.getBool('dopmi.test.one.analytics'), isNull);

    store.failRead = true;
    await controller.owner('one', refresh: true);

    expect(controller.analyticsEnabled, isFalse);
    expect(analytics.enabledValue, isFalse);
    expect(analytics.resets, 0);
    expect(
      controller.preferences.getString('dopmi.analyticsOwner'),
      'dopmi.test.one.analytics',
    );
    expect(store.writes, isEmpty);
  });

  test(
    'a superseded failed refresh cannot reset the current owner identity',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': true,
      });
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: true,
        revision: 9,
      );
      await controller.owner('one');
      await controller.consentReady;
      final delayedRead = Completer<UsageAnalyticsChoice>();
      store.pendingRead = delayedRead;
      store.readStarted = Completer<void>();
      final stale = controller.owner('one', refresh: true);
      await store.readStarted!.future;

      final current = controller.owner('one', refresh: true);
      store.pendingRead = null;
      delayedRead.completeError(StateError('network'));
      await stale;
      await current;
      await controller.consentReady;

      expect(controller.analyticsEnabled, isTrue);
      expect(analytics.enabledValue, isTrue);
      expect(analytics.resets, 0);
      expect(
        controller.preferences.getString('dopmi.analyticsOwner'),
        'dopmi.test.one.analytics',
      );
      expect(store.writes, isEmpty);
    },
  );

  for (final previous in [
    (scope: 'another account', key: 'dopmi.test.two.analytics'),
    (scope: 'another environment', key: 'dopmi.other.one.analytics'),
  ]) {
    test('uncertain read resets identity from ${previous.scope}', () async {
      await setup({
        'dopmi.analyticsOwner': previous.key,
        'dopmi.test.one.analytics': true,
      });
      store.failRead = true;

      await controller.owner('one');
      await controller.event('contact_started');

      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.events, isEmpty);
      expect(analytics.resets, 1);
      expect(controller.preferences.getString('dopmi.analyticsOwner'), '');
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    });
  }

  test(
    'local OFF resets identity even when the server state is uncertain',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': false,
      });
      store.failRead = true;

      await controller.owner('one');
      await controller.event('contact_started');

      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.events, isEmpty);
      expect(analytics.resets, 1);
      expect(controller.preferences.getString('dopmi.analyticsOwner'), '');
      expect(
        controller.preferences.getBool('dopmi.test.one.analytics'),
        isFalse,
      );
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    },
  );

  test(
    'explicit local OFF clears the identity retained during uncertainty',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': true,
      });
      store.failRead = true;
      await controller.owner('one');
      expect(analytics.resets, 0);

      await controller.setAnalytics(false);
      await controller.event('contact_started');

      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.events, isEmpty);
      expect(analytics.resets, 1);
      expect(controller.preferences.getString('dopmi.analyticsOwner'), '');
      expect(
        controller.preferences.getBool('dopmi.test.one.analytics'),
        isFalse,
      );
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    },
  );

  test(
    'signout clears an identity retained during an uncertain same-owner read',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': true,
      });
      store.failRead = true;
      await controller.owner('one');
      expect(analytics.resets, 0);

      await controller.owner(null);

      expect(controller.ownerId, isNull);
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.resets, 1);
      expect(controller.preferences.getString('dopmi.analyticsOwner'), '');
      expect(store.writes, isEmpty);
    },
  );

  test(
    'uncertain OFF is local and does not issue a second unversioned POST',
    () async {
      await setup();
      await controller.owner('one');
      store.failSave = true;
      await controller.setAnalytics(false);
      await controller.consentReady;
      expect(controller.analyticsEnabled, isFalse);
      expect(store.writes, [false]);
      expect(syncs, isEmpty);
    },
  );

  test(
    'new account offers a choice without collecting or manufacturing consent',
    () async {
      await setup();
      await controller.owner('one');
      expect(controller.analyticsChoicePending, isTrue);
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(store.writes, isEmpty);
      await controller.event('contact_started');
      expect(analytics.events, isEmpty);
    },
  );

  test(
    'explicit ON confirms server receipt before enabling only analytics',
    () async {
      await setup();
      await controller.owner('one');
      await controller.setAnalytics(true);
      expect(store.writes, [true]);
      expect(store.state.noticeVersion, usageAnalyticsNoticeVersion);
      expect(controller.analyticsChoicePending, isFalse);
      expect(controller.analyticsEnabled, isTrue);
      expect(diagnostics.enabledValue, isFalse);
    },
  );

  test(
    'continuing without analytics saves OFF and does not ask again',
    () async {
      await setup();
      await controller.owner('one');
      await controller.setAnalytics(false);
      await controller.owner(null);
      await controller.owner('one');
      expect(controller.analyticsChoicePending, isFalse);
      expect(controller.analyticsEnabled, isFalse);
      expect(store.writes, [false]);
    },
  );

  test('remote OFF at revision zero wins over restored local ON', () async {
    await setup({
      'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
      'dopmi.test.one.analytics': true,
    });
    store.state = const UsageAnalyticsChoice(
      hasChoice: true,
      consent: false,
      revision: 0,
    );
    await controller.owner('one');
    expect(controller.analyticsEnabled, isFalse);
    expect(controller.analyticsChoicePending, isFalse);
    expect(analytics.enabledValue, isFalse);
    expect(analytics.resets, 1);
    expect(controller.preferences.getString('dopmi.analyticsOwner'), '');
    expect(controller.preferences.getBool('dopmi.test.one.analytics'), isFalse);
    expect(store.writes, isEmpty);
  });

  test('local OFF remains OFF even without a remote row', () async {
    await setup({'dopmi.test.one.analytics': false});
    await controller.owner('one');
    expect(controller.analyticsChoicePending, isFalse);
    expect(controller.analyticsEnabled, isFalse);
    expect(store.writes.where((v) => v), isEmpty);
  });

  test(
    'new phone can restore a confirmed ON without another consent write',
    () async {
      await setup();
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: true,
        revision: 9,
      );
      await controller.owner('one');
      expect(controller.analyticsEnabled, isTrue);
      expect(controller.analyticsChoicePending, isFalse);
      expect(store.writes, isEmpty);
    },
  );

  test(
    'uncertain opt-in never enables the SDK and OFF can still continue',
    () async {
      await setup();
      await controller.owner('one');
      store.failSave = true;
      await expectLater(controller.setAnalytics(true), throwsStateError);
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      await controller.setAnalytics(false);
      expect(controller.analyticsChoicePending, isFalse);
      expect(controller.analyticsEnabled, isFalse);
    },
  );

  test('choice for an older account cannot enable the next account', () async {
    await setup();
    store.pendingRead = Completer<UsageAnalyticsChoice>();
    final first = controller.owner('one');
    final next = controller.owner('two');
    store.pendingRead!.complete(
      const UsageAnalyticsChoice(hasChoice: true, consent: true, revision: 3),
    );
    await first;
    await next;
    expect(controller.ownerId, 'two');
    await controller.owner(null);
    expect(controller.analyticsEnabled, isFalse);
  });
}
