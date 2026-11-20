import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:dopmi_mobile/core/measurement.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsSpy implements ProductAnalytics {
  bool enabledValue = false;
  int resets = 0;
  final events = <String>[];
  @override
  Future<void> pause() async => enabledValue = false;
  @override
  Future<void> enabled(bool value) async {
    enabledValue = value;
    if (!value) resets++;
  }

  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    events.add(name);
  }
}

class FirebaseAnalyticsSpy implements FirebaseAnalytics {
  final collections = <bool>[];
  final consents = <Map<String, bool?>>[];
  int resets = 0;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collections.add(enabled);
  }

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {
    consents.add({
      'analytics': analyticsStorageConsentGranted,
      'ads': adStorageConsentGranted,
      'adUserData': adUserDataConsentGranted,
      'adPersonalization': adPersonalizationSignalsConsentGranted,
    });
  }

  @override
  Future<void> resetAnalyticsData() async {
    resets++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class BlockingEnableAnalytics extends AnalyticsSpy {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> enabled(bool value) async {
    if (value) {
      started.complete();
      await release.future;
    }
    await super.enabled(value);
  }
}

class FailingAnalytics extends AnalyticsSpy {
  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    throw StateError('provider unavailable');
  }
}

class PendingOptInAnalytics extends AnalyticsSpy {
  final optInStarted = Completer<void>();
  final finishOptIn = Completer<void>();

  @override
  Future<void> enabled(bool value) async {
    if (value && !optInStarted.isCompleted) {
      optInStarted.complete();
      await finishOptIn.future;
    }
    await super.enabled(value);
  }
}

class PendingPauseAnalytics extends AnalyticsSpy {
  final pauseStarted = Completer<void>();
  final resumePause = Completer<void>();
  bool holdPause = false;

  @override
  Future<void> pause() async {
    if (holdPause && !pauseStarted.isCompleted) {
      pauseStarted.complete();
      await resumePause.future;
    }
    await super.pause();
  }
}

class DiagnosticsSpy implements ErrorDiagnostics {
  bool enabledValue = false;
  int reports = 0;
  int sends = 0;
  int discards = 0;
  @override
  Future<void> enabled(bool value) async => enabledValue = value;
  @override
  Future<void> record(Object error, StackTrace stack, {String? reason}) async {
    reports++;
  }

  @override
  Future<void> sendPending() async {
    sends++;
  }

  @override
  Future<void> discardPending() async {
    discards++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Firebase pause preserves consent and stored Analytics identity',
    () async {
      final firebase = FirebaseAnalyticsSpy();
      final analytics = FirebaseProductAnalytics(firebase);
      await analytics.enabled(true);
      await analytics.pause();

      expect(firebase.collections, [true, false]);
      expect(firebase.resets, 0);
      expect(firebase.consents, [
        {
          'analytics': true,
          'ads': false,
          'adUserData': false,
          'adPersonalization': false,
        },
      ]);
    },
  );

  test('Firebase withdrawal denies all consent and clears Analytics', () async {
    final firebase = FirebaseAnalyticsSpy();
    await FirebaseProductAnalytics(firebase).enabled(false);

    expect(firebase.collections, [false]);
    expect(firebase.resets, 1);
    expect(firebase.consents, [
      {
        'analytics': false,
        'ads': false,
        'adUserData': false,
        'adPersonalization': false,
      },
    ]);
  });

  test(
    'same consenting account retains Analytics across process restarts',
    () async {
      SharedPreferences.setMockInitialValues({
        'dopmi.test.alice.analytics': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final analytics = AnalyticsSpy();
      MeasurementController start() => MeasurementController(
        preferences,
        'test',
        analytics,
        DiagnosticsSpy(),
      );

      final original = start();
      await original.prepareStartup();
      await original.owner('alice');
      expect(analytics.enabledValue, isTrue);
      expect(analytics.resets, 1); // One-time cleanup of unscoped legacy state.
      original.dispose();

      final restarted = start();
      await restarted.prepareStartup();
      expect(analytics.enabledValue, isFalse);
      await restarted.event('contact_started');
      expect(analytics.events, isEmpty);
      await restarted.owner('alice');
      await restarted.event('contact_started');
      expect(analytics.enabledValue, isTrue);
      expect(analytics.resets, 1);
      expect(analytics.events, ['contact_started']);
      restarted.dispose();
    },
  );

  test('withdrawal resets once and stays off on restart', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final analytics = AnalyticsSpy();
    final original = MeasurementController(
      preferences,
      'test',
      analytics,
      DiagnosticsSpy(),
    );
    await original.owner('alice');
    await original.setAnalytics(true);
    final beforeWithdrawal = analytics.resets;
    await original.setAnalytics(false);
    expect(analytics.resets, beforeWithdrawal + 1);
    original.dispose();

    final restarted = MeasurementController(
      preferences,
      'test',
      analytics,
      DiagnosticsSpy(),
    );
    await restarted.prepareStartup();
    await restarted.owner('alice');
    await restarted.event('sign_up_completed');
    expect(analytics.enabledValue, isFalse);
    expect(analytics.resets, beforeWithdrawal + 1);
    expect(analytics.events, isEmpty);
    restarted.dispose();
  });

  test(
    'restoring a different consenting account resets the previous identity',
    () async {
      SharedPreferences.setMockInitialValues({
        'dopmi.analyticsOwner': 'dopmi.test.alice.analytics',
        'dopmi.test.bob.analytics': true,
      });
      final analytics = AnalyticsSpy();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        DiagnosticsSpy(),
      );
      await controller.prepareStartup();
      await controller.owner('bob');
      expect(analytics.resets, 1);
      expect(analytics.enabledValue, isTrue);
      await controller.owner(null);
      expect(analytics.resets, 2);
      expect(analytics.enabledValue, isFalse);
      controller.dispose();
    },
  );

  test('queued account switch blocks events from the previous owner', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = PendingPauseAnalytics();
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      DiagnosticsSpy(),
    );
    await controller.owner('alice');
    await controller.setAnalytics(true);
    analytics.holdPause = true;
    final switchAccount = controller.owner('bob');
    await analytics.pauseStarted.future;
    await controller.event('contact_started');
    expect(analytics.events, isEmpty);
    analytics.resumePause.complete();
    await switchAccount;
    expect(analytics.enabledValue, isFalse);
    expect(controller.ownerId, 'bob');
    controller.dispose();
  });

  test('adoption measurement syncs explicit consent without adding Firebase events', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = AnalyticsSpy();
    final sync = <(String, bool)>[];
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      DiagnosticsSpy(),
      prepareAdoptionConsent: (owner, enabled) =>
          () async => sync.add((owner, enabled)),
    );
    await controller.owner('alice');
    await controller.consentReady;
    await controller.setAnalytics(true);
    await controller.consentReady;
    await controller.setAnalytics(false);
    await controller.consentReady;
    expect(sync, [('alice', true), ('alice', false)]);
    expect(analytics.events, isEmpty);
    controller.dispose();
  });

  test(
    'an installation without a local choice leaves remote consent untouched',
    () async {
      SharedPreferences.setMockInitialValues({
        'dopmi.other.alice.analytics': false,
        'dopmi.test.bob.analytics': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final analytics = AnalyticsSpy();
      final sync = <(String, bool)>[];
      final controller = MeasurementController(
        preferences,
        'test',
        analytics,
        DiagnosticsSpy(),
        prepareAdoptionConsent: (owner, enabled) =>
            () async => sync.add((owner, enabled)),
      );

      await controller.owner('alice');
      await controller.consentReady;
      await controller.event('publication_submitted');

      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.events, isEmpty);
      expect(sync, isEmpty);
      expect(preferences.getBool('dopmi.test.alice.analytics'), isNull);

      await controller.owner('bob');
      await controller.consentReady;
      expect(sync, [('bob', true)]);
      expect(controller.analyticsConsentCurrent, isTrue);

      await controller.owner('alice');
      await controller.consentReady;
      expect(sync, [('bob', true)]);
      expect(controller.analyticsConsentCurrent, isFalse);
      expect(analytics.enabledValue, isFalse);
      controller.dispose();
    },
  );

  test(
    'an explicit opt-out saved offline is retried on the next login',
    () async {
      SharedPreferences.setMockInitialValues({
        'dopmi.test.alice.analytics': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final attempts = <(String, bool)>[];
      var offline = true;
      Future<void> Function() prepare(String owner, bool enabled) => () async {
        attempts.add((owner, enabled));
        if (!enabled && offline) throw StateError('offline');
      };
      final first = MeasurementController(
        preferences,
        'test',
        AnalyticsSpy(),
        DiagnosticsSpy(),
        prepareAdoptionConsent: prepare,
      );
      await first.owner('alice');
      await first.consentReady;
      await first.setAnalytics(false);
      await first.consentReady;
      expect(preferences.getBool('dopmi.test.alice.analytics'), isFalse);
      expect(first.analyticsConsentCurrent, isFalse);
      first.dispose();

      offline = false;
      final analytics = AnalyticsSpy();
      final restarted = MeasurementController(
        preferences,
        'test',
        analytics,
        DiagnosticsSpy(),
        prepareAdoptionConsent: prepare,
      );
      await restarted.owner('alice');
      await restarted.consentReady;

      expect(attempts, [('alice', true), ('alice', false), ('alice', false)]);
      expect(restarted.analyticsConsentCurrent, isFalse);
      expect(analytics.enabledValue, isFalse);
      restarted.dispose();
    },
  );

  test(
    'measurement is disabled initially and sends no accumulated events',
    () async {
      SharedPreferences.setMockInitialValues({});
      final analytics = AnalyticsSpy();
      final diagnostics = DiagnosticsSpy();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        diagnostics,
      );
      await controller.owner('alice');
      await controller.event('contact_started');
      expect(controller.analyticsEnabled, false);
      expect(controller.diagnosticsEnabled, false);
      expect(analytics.events, isEmpty);
      expect(analytics.enabledValue, false);
      expect(diagnostics.enabledValue, false);
      expect(controller.lastAnalyticsEvent, 'contact_started');
      expect(controller.lastAnalyticsResult, 'omitido_sin_consentimiento');
      controller.dispose();
    },
  );

  test('consent is independent, revocable and isolated by account', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = AnalyticsSpy();
    final diagnostics = DiagnosticsSpy();
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      diagnostics,
    );
    await controller.owner('alice');
    await controller.setAnalytics(true);
    await controller.event('publication_submitted');
    expect(analytics.events, ['publication_submitted']);
    expect(controller.lastAnalyticsEvent, 'publication_submitted');
    expect(controller.lastAnalyticsResult, 'aceptado_por_sdk');
    expect(diagnostics.enabledValue, false);
    expect(diagnostics.discards, 1);
    await controller.owner('bob');
    expect(controller.analyticsEnabled, false);
    await controller.owner('alice');
    expect(controller.analyticsEnabled, true);
    await controller.setAnalytics(false);
    expect(controller.lastAnalyticsEvent, isNull);
    expect(controller.lastAnalyticsResult, isNull);
    await controller.event('contact_started');
    expect(analytics.events, ['publication_submitted']);
    controller.dispose();
  });

  test(
    'a pending opt-in cannot enable analytics for the next account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final analytics = BlockingEnableAnalytics();
      final sync = <(String, bool)>[];
      final controller = MeasurementController(
        preferences,
        'test',
        analytics,
        DiagnosticsSpy(),
        prepareAdoptionConsent: (owner, enabled) =>
            () async => sync.add((owner, enabled)),
      );
      await controller.owner('alice');
      await controller.consentReady;

      final optIn = controller.setAnalytics(true);
      await analytics.started.future;
      final switched = controller.owner('bob');
      expect(controller.ownerId, isNull);
      analytics.release.complete();
      await optIn;
      await switched;
      await controller.consentReady;

      expect(sync, isEmpty);
      expect(preferences.getBool('dopmi.test.alice.analytics'), true);
      expect(preferences.getBool('dopmi.test.bob.analytics'), isNull);
      expect(controller.ownerId, 'bob');
      expect(controller.analyticsEnabled, false);
      expect(analytics.enabledValue, false);
      controller.dispose();
    },
  );

  test(
    'a queued revocation prevents the pending opt-in from syncing',
    () async {
      SharedPreferences.setMockInitialValues({});
      final analytics = BlockingEnableAnalytics();
      final sync = <bool>[];
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        DiagnosticsSpy(),
        prepareAdoptionConsent: (_, enabled) =>
            () async => sync.add(enabled),
      );
      await controller.owner('alice');
      await controller.consentReady;

      final optIn = controller.setAnalytics(true);
      await analytics.started.future;
      final revoked = controller.setAnalytics(false);
      expect(controller.analyticsConsentCurrent, false);
      analytics.release.complete();
      await optIn;
      await revoked;
      await controller.consentReady;

      expect(sync, [false]);
      expect(controller.analyticsConsentCurrent, false);
      expect(analytics.enabledValue, false);
      controller.dispose();
    },
  );

  for (final nextOwner in <String?>[null, 'bob']) {
    test(
      'an explicit revocation survives switching to ${nextOwner ?? 'signed out'}',
      () async {
        SharedPreferences.setMockInitialValues({
          'dopmi.test.alice.analytics': true,
        });
        final preferences = await SharedPreferences.getInstance();
        final priorRequestStarted = Completer<void>();
        final finishPriorRequest = Completer<void>();
        final submitted = <(String, bool)>[];
        String? authenticatedOwner = 'alice';
        final controller = MeasurementController(
          preferences,
          'test',
          AnalyticsSpy(),
          DiagnosticsSpy(),
          prepareAdoptionConsent: (owner, enabled) {
            final authorizedOwner = authenticatedOwner;
            if (authorizedOwner != owner) return null;
            return () async {
              if (enabled) {
                priorRequestStarted.complete();
                await finishPriorRequest.future;
              }
              submitted.add((owner, enabled));
            };
          },
        );
        await controller.owner('alice');
        await priorRequestStarted.future;

        final revoke = controller.setAnalytics(false);
        authenticatedOwner = nextOwner;
        await controller.owner(nextOwner);
        await revoke;
        await controller.consentReady;
        expect(submitted, [('alice', false)]);

        finishPriorRequest.complete();
        await Future<void>.delayed(Duration.zero);
        expect(submitted, [('alice', false), ('alice', true)]);
        expect(preferences.getBool('dopmi.test.alice.analytics'), false);
        controller.dispose();
      },
    );
  }

  test('an explicit opt-out does not wait for a stalled opt-in', () async {
    SharedPreferences.setMockInitialValues({
      'dopmi.test.alice.analytics': true,
    });
    final started = Completer<void>();
    final stalled = Completer<void>();
    final submitted = <bool>[];
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      AnalyticsSpy(),
      DiagnosticsSpy(),
      prepareAdoptionConsent: (_, enabled) => () async {
        if (enabled) {
          started.complete();
          await stalled.future;
        }
        submitted.add(enabled);
      },
    );
    try {
      await controller.owner('alice');
      await started.future;
      await controller.setAnalytics(false);
      await controller.consentReady.timeout(const Duration(milliseconds: 100));
      expect(submitted, [false]);
      expect(controller.analyticsConsentCurrent, isFalse);
    } finally {
      stalled.complete();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
    }
  });

  test('measurement rejects unknown events and every payload', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      AnalyticsSpy(),
      DiagnosticsSpy(),
    );
    await controller.owner('alice');
    await controller.setAnalytics(true);
    expect(() => controller.event('unknown_event'), throwsArgumentError);
    expect(
      () => controller.event(
        'contact_started',
        parameters: {'email': 'private@example.com'},
      ),
      throwsArgumentError,
    );
    controller.dispose();
  });

  test(
    'an opt-in in flight does not enable analytics for the next account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final analytics = PendingOptInAnalytics();
      final controller = MeasurementController(
        preferences,
        'test',
        analytics,
        DiagnosticsSpy(),
      );
      await controller.owner('alice');
      final optIn = controller.setAnalytics(true);
      await analytics.optInStarted.future;
      final switchAccount = controller.owner('bob');
      await Future<void>.delayed(Duration.zero);
      analytics.finishOptIn.complete();
      await Future.wait([optIn, switchAccount]);
      await controller.event('adoption_form_opened');

      expect(preferences.getBool('dopmi.test.alice.analytics'), isTrue);
      expect(preferences.getBool('dopmi.test.bob.analytics'), isNull);
      expect(controller.analyticsEnabled, isFalse);
      expect(analytics.enabledValue, isFalse);
      expect(analytics.events, isEmpty);
      controller.dispose();
    },
  );

  test(
    'every approved conversion event is forwarded without payload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final analytics = AnalyticsSpy();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        DiagnosticsSpy(),
      );
      await controller.owner('alice');
      await controller.setAnalytics(true);
      for (final name in FirebaseProductAnalytics.allowed) {
        await controller.event(name);
      }
      expect(analytics.events.toSet(), FirebaseProductAnalytics.allowed);
      controller.dispose();
    },
  );

  test('diagnostic test requires independent consent', () async {
    SharedPreferences.setMockInitialValues({});
    final diagnostics = DiagnosticsSpy();
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      AnalyticsSpy(),
      diagnostics,
    );
    await controller.owner('alice');
    await controller.diagnosticTest();
    expect(diagnostics.reports, 0);
    expect(diagnostics.sends, 0);
    await controller.setDiagnostics(true);
    expect(diagnostics.discards, 2);
    await controller.diagnosticTest();
    expect(diagnostics.reports, 1);
    expect(diagnostics.sends, 1);
    await controller.setDiagnostics(false);
    expect(diagnostics.discards, 3);
    await controller.diagnosticTest();
    expect(diagnostics.reports, 1);
    expect(diagnostics.sends, 1);
    controller.dispose();
  });

  test(
    'async platform errors are captured only while diagnostics is enabled',
    () async {
      SharedPreferences.setMockInitialValues({});
      final diagnostics = DiagnosticsSpy();
      final previous = PlatformDispatcher.instance.onError;
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        AnalyticsSpy(),
        diagnostics,
      );
      await controller.owner('alice');
      expect(PlatformDispatcher.instance.onError, same(previous));
      await controller.setDiagnostics(true);
      final installed = PlatformDispatcher.instance.onError;
      expect(installed, isNotNull);
      expect(installed, isNot(same(previous)));
      installed!(StateError('async_test'), StackTrace.current);
      await Future<void>.delayed(Duration.zero);
      expect(diagnostics.reports, 1);
      await controller.setDiagnostics(false);
      expect(PlatformDispatcher.instance.onError, same(previous));
      controller.dispose();
    },
  );

  test(
    'switching accounts discards diagnostics before the next owner',
    () async {
      SharedPreferences.setMockInitialValues({});
      final diagnostics = DiagnosticsSpy();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        AnalyticsSpy(),
        diagnostics,
      );
      await controller.owner('alice');
      expect(diagnostics.discards, 1);
      await controller.setDiagnostics(true);
      expect(diagnostics.discards, 2);
      await controller.owner('bob');
      expect(diagnostics.discards, 4);
      expect(controller.diagnosticsEnabled, false);
      controller.dispose();
    },
  );

  test('provider failure never changes the product result', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      FailingAnalytics(),
      DiagnosticsSpy(),
    );
    await controller.owner('alice');
    await controller.setAnalytics(true);
    await expectLater(controller.event('contact_started'), completes);
    expect(controller.lastAnalyticsEvent, 'contact_started');
    expect(controller.lastAnalyticsResult, 'error_StateError');
    controller.dispose();
  });
}
