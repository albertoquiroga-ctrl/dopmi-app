import 'dart:async';

import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/core/usage_analytics_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;
import 'usage_analytics_choice_test.dart' show ChoiceStore;

void main() {
  late SharedPreferences preferences;
  late ChoiceStore store;
  late AnalyticsSpy analytics;
  late MeasurementController controller;
  late Completer<void> consent, consentStarted;
  var holdConsent = false;
  var disposed = false;
  setUp(() async {
    disposed = false;
    consent = Completer<void>();
    consentStarted = Completer<void>();
    holdConsent = false;
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = ChoiceStore();
    analytics = AnalyticsSpy();
    controller = MeasurementController(
      preferences,
      'test',
      analytics,
      DiagnosticsSpy(),
      analyticsChoices: store,
      prepareAdoptionConsent: (_, _) => () async {
        if (holdConsent) {
          if (!consentStarted.isCompleted) consentStarted.complete();
          await consent.future;
        }
      },
    );
    await controller.owner('one');
  });
  tearDown(() {
    if (!disposed) controller.dispose();
  });

  test(
    'only a confirmed current-actor signup waits for the first ON',
    () async {
      final before = {
        for (final key in preferences.getKeys()) key: preferences.get(key),
      };
      await controller.confirmedSignup('one');
      await controller.confirmedSignup('one');
      expect(analytics.events, isEmpty);
      expect(store.writes, isEmpty);
      expect({
        for (final key in preferences.getKeys()) key: preferences.get(key),
      }, before);
      await controller.setAnalytics(true);
      await controller.confirmedSignup('one');
      await controller.owner('one', refresh: true);
      expect(analytics.events, ['sign_up_completed']);
    },
  );

  test('unconfirmed restoration never reconstructs a signup', () async {
    await controller.setAnalytics(true);
    await controller.owner('one', refresh: true);
    expect(analytics.events, isEmpty);
  });

  test(
    'declining permanently consumes the pending fact in this session',
    () async {
      await controller.confirmedSignup('one');
      await controller.setAnalytics(false);
      await controller.setAnalytics(true);
      await controller.confirmedSignup('one');
      expect(analytics.events, isEmpty);
    },
  );

  test(
    'OFF during same-owner refresh still consumes the pending signup',
    () async {
      await controller.confirmedSignup('one');
      final read = Completer<UsageAnalyticsChoice>();
      store.pendingRead = read;
      final refresh = controller.owner('one', refresh: true);
      expect(controller.ownerId, isNull);
      await controller.setAnalytics(false);
      read.complete(store.state);
      await refresh;
      store.pendingRead = null;
      await controller.setAnalytics(true);
      expect(analytics.events, isEmpty);
    },
  );

  test('a late signup ACK during OFF cannot survive the decline', () async {
    // 1. The account has no observed signup fact yet.
    final response = Completer<UsageAnalyticsChoiceResult>();
    store.pendingSave = response;
    // 2. OFF starts, with its authenticated response still in flight.
    final off = controller.setAnalytics(false);
    // 3. The business ACK arrives before OFF has completed.
    await controller.confirmedSignup('one');
    expect(analytics.events, isEmpty);
    // 4. OFF is acknowledged by the server.
    store.state = const UsageAnalyticsChoice(
      hasChoice: true,
      consent: false,
      revision: 1,
      noticeVersion: usageAnalyticsNoticeVersion,
    );
    response.complete(
      UsageAnalyticsChoiceResult(state: store.state, applied: true),
    );
    await off;
    // 5. A later deliberate ON succeeds in the same session.
    store.pendingSave = null;
    await controller.setAnalytics(true);
    // 6. The discarded registration is never resurrected.
    expect(analytics.events, isEmpty);
  });

  test('a signup ACK after failed ON cannot survive until a retry', () async {
    store.failSave = true;
    await expectLater(controller.setAnalytics(true), throwsStateError);
    expect(controller.analyticsEnabled, isFalse);
    await controller.confirmedSignup('one');
    store.failSave = false;
    await controller.setAnalytics(true);
    expect(analytics.events, isEmpty);
  });

  test(
    'an old A failure cannot close the signup scope of a new A session',
    () async {
      final response = Completer<UsageAnalyticsChoiceResult>();
      store.pendingSave = response;
      final oldSave = controller.setAnalytics(true);
      final switchToB = controller.owner('two');
      final returnToA = controller.owner('one');
      response.completeError(StateError('old session network failure'));
      await Future.wait([oldSave, switchToB, returnToA]);
      store.pendingSave = null;
      await controller.confirmedSignup('one');
      await controller.setAnalytics(true);
      expect(analytics.events, ['sign_up_completed']);
    },
  );

  test('an existing current explicit OFF never defers a signup', () async {
    store.state = const UsageAnalyticsChoice(
      hasChoice: true,
      consent: false,
      revision: 2,
      noticeVersion: usageAnalyticsNoticeVersion,
    );
    await controller.owner('one', refresh: true);
    await controller.confirmedSignup('one');
    await controller.setAnalytics(true);
    await controller.confirmedSignup('one');
    expect(analytics.events, isEmpty);
  });

  test(
    'read failure discards an already pending fact without a write',
    () async {
      await controller.confirmedSignup('one');
      store.failRead = true;
      await controller.owner('one', refresh: true);
      expect(analytics.events, isEmpty);
      expect(store.writes, isEmpty);
      expect(controller.analyticsEnabled, isFalse);
      store.failRead = false;
      await controller.setAnalytics(true);
      expect(analytics.events, isEmpty);
    },
  );

  test('failed ON cannot replay after a later successful ON', () async {
    await controller.confirmedSignup('one');
    store.failSave = true;
    await expectLater(controller.setAnalytics(true), throwsStateError);
    expect(controller.analyticsEnabled, isFalse);
    expect(analytics.events, isEmpty);
    store.failSave = false;
    await controller.setAnalytics(true);
    expect(analytics.events, isEmpty);
  });

  test(
    'a superseded ON failure also discards signup before a later retry',
    () async {
      await controller.confirmedSignup('one');
      final response = Completer<UsageAnalyticsChoiceResult>();
      store.pendingSave = response;
      final save = controller.setAnalytics(true);
      final refresh = controller.owner('one', refresh: true);
      response.completeError(StateError('network'));
      await Future.wait([save, refresh]);
      expect(controller.analyticsEnabled, isFalse);
      store.pendingSave = null;
      await controller.setAnalytics(true);
      expect(analytics.events, isEmpty);
    },
  );

  test('CAS rejection cannot release the pending signup', () async {
    await controller.confirmedSignup('one');
    store.saveResult = const UsageAnalyticsChoiceResult(
      applied: false,
      state: UsageAnalyticsChoice(
        hasChoice: true,
        consent: false,
        revision: 3,
        noticeVersion: usageAnalyticsNoticeVersion,
      ),
    );
    await expectLater(controller.setAnalytics(true), throwsStateError);
    expect(controller.analyticsEnabled, isFalse);
    store.state = store.saveResult!.state;
    store.saveResult = null;
    await controller.setAnalytics(true);
    expect(analytics.events, isEmpty);
  });

  for (final nextOwner in <String?>[null, 'two']) {
    test(
      'leaving for $nextOwner clears pending, including a late producer',
      () async {
        await controller.confirmedSignup('one');
        await controller.owner(nextOwner);
        await controller.confirmedSignup('one');
        await controller.owner('one');
        await controller.setAnalytics(true);
        expect(analytics.events, isEmpty);
      },
    );
  }

  test(
    'a restart with the same receipt cannot replay a pending fact',
    () async {
      await controller.confirmedSignup('one');
      final restartedAnalytics = AnalyticsSpy();
      final restarted = MeasurementController(
        preferences,
        'test',
        restartedAnalytics,
        DiagnosticsSpy(),
        analyticsChoices: store,
      );
      addTearDown(restarted.dispose);
      await restarted.owner('one');
      await restarted.setAnalytics(true);
      expect(restartedAnalytics.events, isEmpty);
      expect(analytics.events, isEmpty);
    },
  );

  test(
    'an existing ON dispatches once and never accepts another actor',
    () async {
      await controller.setAnalytics(true);
      await controller.confirmedSignup('two');
      await Future.wait([
        controller.confirmedSignup('one'),
        controller.confirmedSignup('one'),
      ]);
      expect(analytics.events, ['sign_up_completed']);
    },
  );

  test(
    'late consent completion after actor change never emits for replacement',
    () async {
      await controller.confirmedSignup('one');
      holdConsent = true;
      final saved = controller.setAnalytics(true);
      await consentStarted.future;
      await controller.owner('two');
      consent.complete();
      await saved;
      expect(analytics.events, isEmpty);
      holdConsent = false;
    },
  );

  test('dispose while consent is pending clears the fact', () async {
    await controller.confirmedSignup('one');
    holdConsent = true;
    final saved = controller.setAnalytics(true);
    await consentStarted.future;
    disposed = true;
    controller.dispose();
    consent.complete();
    await saved;
    expect(analytics.events, isEmpty);
  });

  test(
    'a producer arriving after disposal cannot repopulate the fact',
    () async {
      await controller.setAnalytics(true);
      disposed = true;
      controller.dispose();
      await controller.confirmedSignup('one');
      expect(analytics.events, isEmpty);
    },
  );

  test(
    'an SDK failure is optional and never retried by another producer',
    () async {
      final failing = SignupFailureAnalytics();
      final measured = MeasurementController(
        preferences,
        'test',
        failing,
        DiagnosticsSpy(),
        analyticsChoices: store,
      );
      addTearDown(measured.dispose);
      await measured.owner('one');
      await measured.confirmedSignup('one');
      await measured.setAnalytics(true);
      await measured.confirmedSignup('one');
      await measured.owner('one', refresh: true);
      expect(failing.attempts, 1);
    },
  );
}

class SignupFailureAnalytics extends AnalyticsSpy {
  int attempts = 0;
  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    attempts++;
    throw StateError('SDK unavailable');
  }
}
