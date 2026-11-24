import 'dart:async';

import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/core/usage_analytics_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

class ChoiceAnalyticsSpy extends AnalyticsSpy {
  final enabledCalls = <bool>[];
  @override
  Future<void> enabled(bool value) async {
    enabledCalls.add(value);
    await super.enabled(value);
  }
}

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
  Map<String, Object?>? readResponse;
  UsageAnalyticsChoiceResult? saveResult;
  Completer<UsageAnalyticsChoiceResult>? pendingSave;
  @override
  Future<UsageAnalyticsChoice> read(String owner) async {
    if (readStarted?.isCompleted == false) readStarted!.complete();
    if (failRead) throw StateError('network');
    if (readResponse != null) {
      return UsageAnalyticsChoice.fromJson(readResponse);
    }
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
    if (pendingSave != null) return pendingSave!.future;
    if (saveResult != null) return saveResult!;
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
  late ChoiceAnalyticsSpy analytics;
  late DiagnosticsSpy diagnostics;
  late MeasurementController controller;
  final syncs = <bool>[];
  Future<void> setup([Map<String, Object> saved = const {}]) async {
    SharedPreferences.setMockInitialValues(saved);
    store = ChoiceStore();
    analytics = ChoiceAnalyticsSpy();
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
    'only the current notice on a real revision proves an explicit choice',
    () {
      final legacy = UsageAnalyticsChoice.fromJson({
        'has_choice': true,
        'consent': false,
        'revision': 12,
        'notice_version': null,
      });
      final confirmed = UsageAnalyticsChoice.fromJson({
        'has_choice': true,
        'consent': false,
        'revision': 13,
        'notice_version': usageAnalyticsNoticeVersion,
      });
      expect(legacy.hasCurrentExplicitChoice, isFalse);
      expect(confirmed.hasCurrentExplicitChoice, isTrue);
      expect(
        () => UsageAnalyticsChoice.fromJson({
          'has_choice': false,
          'consent': false,
          'revision': 0,
          'notice_version': usageAnalyticsNoticeVersion,
        }),
        throwsFormatException,
      );
    },
  );

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
        noticeVersion: usageAnalyticsNoticeVersion,
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
      noticeVersion: usageAnalyticsNoticeVersion,
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
        noticeVersion: usageAnalyticsNoticeVersion,
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
      expect(controller.analyticsChoiceInitialValue, isTrue);
      expect(controller.analyticsChoiceIsReview, isFalse);
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

  test(
    'legacy OFF needs review without resetting the same-owner identity',
    () async {
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
      expect(controller.analyticsChoicePending, isTrue);
      expect(controller.analyticsChoiceInitialValue, isFalse);
      expect(controller.analyticsChoiceIsReview, isTrue);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.resets, 0);
      expect(
        controller.preferences.getString('dopmi.analyticsOwner'),
        'dopmi.test.one.analytics',
      );
      expect(
        controller.preferences.getBool('dopmi.test.one.analytics'),
        isTrue,
      );
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    },
  );

  test('local OFF remains OFF even without a remote row', () async {
    await setup({'dopmi.test.one.analytics': false});
    await controller.owner('one');
    expect(controller.analyticsChoicePending, isTrue);
    expect(controller.analyticsChoiceInitialValue, isFalse);
    expect(controller.analyticsChoiceIsReview, isTrue);
    expect(controller.analyticsEnabled, isFalse);
    expect(store.writes.where((v) => v), isEmpty);
    await controller.consentReady;
    expect(syncs, isEmpty);
  });

  test(
    'cached legacy false opens review without a consent write or reset',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': false,
      });
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: false,
        revision: 12,
      );
      await controller.owner('one');
      await controller.consentReady;
      await controller.event('contact_started');
      expect(controller.analyticsChoicePending, isTrue);
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.events, isEmpty);
      expect(analytics.resets, 0);
      expect(store.state.revision, 12);
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    },
  );

  test(
    'legacy ON is paused for review and cannot manufacture a new receipt',
    () async {
      await setup({
        'dopmi.analyticsOwner': 'dopmi.test.one.analytics',
        'dopmi.test.one.analytics': true,
      });
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: true,
        revision: 7,
      );
      await controller.owner('one');
      await controller.consentReady;
      expect(controller.analyticsChoicePending, isTrue);
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledCalls.where((value) => value), isEmpty);
      expect(analytics.resets, 0);
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    },
  );

  test(
    'legacy ON plus local OFF does not race the prompt with an implicit CAS',
    () async {
      await setup({'dopmi.test.one.analytics': false});
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: true,
        revision: 5,
      );
      await controller.owner('one');
      await controller.consentReady;
      expect(controller.analyticsChoicePending, isTrue);
      expect(syncs, isEmpty);
      expect(store.state.revision, 5);
      await controller.setAnalytics(true);
      expect(store.writes, [true]);
      expect(store.state.revision, 6);
      expect(controller.analyticsEnabled, isTrue);
    },
  );

  test(
    'a current explicit OFF is preserved without another prompt or write',
    () async {
      await setup({'dopmi.test.one.analytics': true});
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: false,
        revision: 4,
        noticeVersion: usageAnalyticsNoticeVersion,
      );
      await controller.owner('one');
      await controller.consentReady;
      expect(controller.analyticsChoicePending, isFalse);
      expect(controller.analyticsEnabled, isFalse);
      expect(
        controller.preferences.getBool('dopmi.test.one.analytics'),
        isFalse,
      );
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    },
  );

  test(
    'an applied ON without the current receipt cannot enable analytics',
    () async {
      await setup();
      await controller.owner('one');
      store.saveResult = const UsageAnalyticsChoiceResult(
        applied: true,
        state: UsageAnalyticsChoice(
          hasChoice: true,
          consent: true,
          revision: 1,
        ),
      );
      await expectLater(controller.setAnalytics(true), throwsStateError);
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledCalls.where((value) => value), isEmpty);
    },
  );

  test(
    'a conflicting ON observes a current explicit OFF without another prompt',
    () async {
      await setup({'dopmi.analyticsOwner': 'dopmi.test.one.analytics'});
      await controller.owner('one');
      store.saveResult = const UsageAnalyticsChoiceResult(
        applied: false,
        state: UsageAnalyticsChoice(
          hasChoice: true,
          consent: false,
          revision: 4,
          noticeVersion: usageAnalyticsNoticeVersion,
        ),
      );
      await expectLater(controller.setAnalytics(true), throwsStateError);
      expect(controller.analyticsChoicePending, isFalse);
      expect(controller.analyticsEnabled, isFalse);
      expect(
        controller.preferences.getBool('dopmi.test.one.analytics'),
        isFalse,
      );
      expect(controller.preferences.getString('dopmi.analyticsOwner'), '');
      expect(analytics.enabledCalls.where((value) => value), isEmpty);
      expect(store.writes, [true]);
      expect(syncs, isEmpty);
    },
  );

  test(
    'malformed server state remains uncertain rather than new preselection',
    () async {
      await setup({'dopmi.test.one.analytics': true});
      store.readResponse = {
        'has_choice': false,
        'consent': true,
        'revision': 0,
      };
      await controller.owner('one');
      expect(controller.analyticsChoicePending, isFalse);
      expect(controller.analyticsEnabled, isFalse);
      expect(store.writes, isEmpty);
      expect(syncs, isEmpty);
    },
  );

  test(
    'an accepted ON for the previous owner cannot enable the next account',
    () async {
      await setup();
      await controller.owner('one');
      store.pendingSave = Completer<UsageAnalyticsChoiceResult>();
      final previous = controller.setAnalytics(true);
      final current = controller.owner('two');
      store.pendingSave!.complete(
        const UsageAnalyticsChoiceResult(
          applied: true,
          state: UsageAnalyticsChoice(
            hasChoice: true,
            consent: true,
            revision: 1,
            noticeVersion: usageAnalyticsNoticeVersion,
          ),
        ),
      );
      await previous;
      await current;
      expect(controller.ownerId, 'two');
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledCalls.where((value) => value), isEmpty);
      expect(
        controller.preferences.getBool('dopmi.test.two.analytics'),
        isNull,
      );
    },
  );

  test(
    'new phone can restore a confirmed ON without another consent write',
    () async {
      await setup();
      store.state = const UsageAnalyticsChoice(
        hasChoice: true,
        consent: true,
        revision: 9,
        noticeVersion: usageAnalyticsNoticeVersion,
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
