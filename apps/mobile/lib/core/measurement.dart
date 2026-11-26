import 'dart:async';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'usage_analytics_choice.dart';

abstract interface class ProductAnalytics {
  Future<void> pause();
  Future<void> enabled(bool value);
  Future<void> event(String name, {Map<String, Object>? parameters});
}

abstract interface class ErrorDiagnostics {
  Future<void> enabled(bool value);
  Future<void> record(Object error, StackTrace stack, {String? reason});
  Future<void> sendPending();
  Future<void> discardPending();
}

class FirebaseProductAnalytics implements ProductAnalytics {
  const FirebaseProductAnalytics(this.analytics);
  final FirebaseAnalytics analytics;
  static const allowed = {
    'sign_up_completed',
    'contact_started',
    'adoption_contact_created',
    'rescuer_first_reply',
    'adoption_marked_adopted',
    'publication_submitted',
    'adoption_form_opened',
    'adoption_draft_resumed',
    'adoption_details_reached',
    'adoption_preview_reached',
    'adoption_main_photo_camera',
    'adoption_main_photo_gallery',
    'adoption_photo_prep_failed',
    'adoption_photo_picker_cancelled',
    'adoption_photo_picker_denied',
    'adoption_photo_picker_failed',
    'adoption_photo_read_failed',
    'adoption_photo_process_failed',
    'adoption_photo_upload_failed',
    'adoption_photo_attach_save_failed',
    'adoption_photo_attached',
    'adoption_submit_attempted',
    'adoption_submit_validation_failed',
    'adoption_submit_save_failed',
    'adoption_submit_transition_failed',
    'adoption_submit_accepted',
    'contribution_started',
    'contribution_confirmed',
  };
  @override
  Future<void> pause() => analytics.setAnalyticsCollectionEnabled(false);

  @override
  Future<void> enabled(bool value) async {
    if (!value) await pause();
    await analytics.setConsent(
      analyticsStorageConsentGranted: value,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    if (value) {
      await analytics.setAnalyticsCollectionEnabled(true);
    } else {
      await analytics.resetAnalyticsData();
    }
  }

  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    if (!allowed.contains(name)) throw ArgumentError.value(name, 'name');
    if (parameters != null && parameters.isNotEmpty) {
      throw ArgumentError.value(
        parameters,
        'parameters',
        'Dopmi measurement events do not accept payloads',
      );
    }
    await analytics.logEvent(name: name, parameters: parameters);
  }
}

class FirebaseErrorDiagnostics implements ErrorDiagnostics {
  const FirebaseErrorDiagnostics(this.crashlytics);
  final FirebaseCrashlytics crashlytics;
  @override
  Future<void> enabled(bool value) =>
      crashlytics.setCrashlyticsCollectionEnabled(value);
  @override
  Future<void> record(Object error, StackTrace stack, {String? reason}) =>
      crashlytics.recordError(error, stack, reason: reason, fatal: false);
  @override
  Future<void> sendPending() => crashlytics.sendUnsentReports();
  @override
  Future<void> discardPending() => crashlytics.deleteUnsentReports();
}

typedef PrepareAdoptionConsent = Future<void> Function()? Function(
  String owner,
  bool enabled,
);

class MeasurementController extends ChangeNotifier {
  MeasurementController(
    this.preferences,
    this.namespace,
    this.analytics,
    this.diagnostics, {
    this.prepareAdoptionConsent,
    this.prepareAcquisition,
    this.analyticsChoices,
  });
  final PrepareAdoptionConsent? prepareAdoptionConsent;
  final Future<void> Function(String actor)? prepareAcquisition;
  final UsageAnalyticsChoiceStore? analyticsChoices;
  UsageAnalyticsChoice? _analyticsChoice;
  bool _analyticsChoicePending = false;
  bool _analyticsChoiceReview = false;
  String? _confirmedSignupActor;
  bool _confirmedSignupPending = false;
  int _signupSession = 0;
  bool _signupDisposed = false;
  bool get analyticsChoicePending => ownerId != null && _analyticsChoicePending;
  bool get analyticsChoiceIsReview =>
      analyticsChoicePending && _analyticsChoiceReview;
  bool get analyticsChoiceInitialValue =>
      analyticsChoicePending && !_analyticsChoiceReview;
  Future<void> _consentSync = Future.value();
  Future<void> _settingsSync = Future.value();
  Future<void>? _ownerSync;
  String? _requestedOwner;
  int _ownerRevision = 0;
  int _configuredOwnerRevision = 0;
  int _analyticsRevision = 0;
  int _configuredAnalyticsRevision = 0;
  String? get ownerId =>
      !loading && _ownerRevision == _configuredOwnerRevision ? _owner : null;
  bool preferencesReadyFor(String? owner) => owner != null && ownerId == owner;
  int get analyticsRevision => _analyticsRevision;
  bool get analyticsConsentCurrent =>
      analyticsEnabled && _analyticsRevision == _configuredAnalyticsRevision;
  Future<void> get consentReady => _consentSync;

  Future<void> prepareAttributableAction(String actor) async {
    // Owner restoration or a just-requested opt-in can still be configuring
    // the local SDK. Its consent task is queued before this settings task ends.
    await _settingsSync;
    if (ownerId != actor || !analyticsConsentCurrent) return;
    final ownerRevision = _ownerRevision;
    final analyticsRevision = _analyticsRevision;
    await consentReady;
    if (ownerId != actor ||
        !analyticsConsentCurrent ||
        ownerRevision != _ownerRevision ||
        analyticsRevision != _analyticsRevision) {
      return;
    }
    final prepare = prepareAcquisition;
    if (prepare == null) return;
    try {
      await prepare(actor)
          .timeout(const Duration(seconds: 10), onTimeout: () {});
    } catch (_) {
      // Optional source resolution must not prevent a normal product action.
    }
  }

  Future<void> _queueSettings(Future<void> Function() apply) {
    final pending = _settingsSync.then((_) => apply());
    _settingsSync = pending.catchError((Object _) {});
    return pending;
  }

  void _syncConsent(
    String owner,
    bool enabled, {
    bool explicitRevocation = false,
  }) {
    // Preparation reserves a transport intention. An obsolete SDK completion
    // must not reserve a new ON and invalidate the current OFF before the
    // queued execution guard gets a chance to discard it.
    if (!explicitRevocation &&
        (ownerId != owner ||
            _configuredAnalyticsRevision != _analyticsRevision)) {
      return;
    }
    // Capture the authenticated request before another account can replace it.
    final request = prepareAdoptionConsent?.call(owner, enabled);
    if (request == null) return;
    if (explicitRevocation) {
      // Revocation has its own CAS-protected transport. A stalled opt-in must
      // not keep OFF waiting; the transport rejects an older late write.
      _consentSync = Future<void>.sync(request).catchError((Object _) {});
      return;
    }
    final ownerRevision = _ownerRevision;
    final analyticsRevision = _configuredAnalyticsRevision;
    _consentSync = _consentSync
        .then((_) async {
          if (ownerId == owner &&
              ownerRevision == _ownerRevision &&
              analyticsRevision == _analyticsRevision) {
            await request();
          }
        })
        .catchError((Object _) {});
  }

  final SharedPreferences preferences;
  final String namespace;
  final ProductAnalytics analytics;
  final ErrorDiagnostics diagnostics;
  String? _owner;
  bool _analyticsAllowed = false;
  bool diagnosticsEnabled = false, loading = true;
  bool get analyticsEnabled =>
      _analyticsAllowed &&
      ownerId != null &&
      _analyticsRevision == _configuredAnalyticsRevision;
  String? lastAnalyticsEvent;
  String? lastAnalyticsResult;
  bool _handlersInstalled = false;
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;

  // Firebase has one local identity. This marker scopes it to the account and
  // environment without sending either value to Firebase.
  static const _analyticsOwnerKey = 'dopmi.analyticsOwner';

  String _preferenceKey(String? owner, String kind) =>
      'dopmi.$namespace.${owner ?? 'signed-out'}.$kind';

  Future<void> prepareStartup() async {
    await analytics.pause();
    await diagnostics.enabled(false);
  }

  Future<void> _setAnalyticsOwner(String? allowedPreference) async {
    final previous = preferences.getString(_analyticsOwnerKey);
    final next = allowedPreference ?? '';
    if (previous == next) return;
    // A missing marker may come from a build that never scoped its identity.
    // Reset that legacy state once; a same-account restart only pauses.
    if (previous != '') await analytics.enabled(false);
    if (!await preferences.setString(_analyticsOwnerKey, next)) {
      await preferences.reload();
      throw StateError('analytics_owner_not_saved');
    }
  }

  Future<void> owner(String? value, {bool refresh = false}) {
    if (!refresh && _requestedOwner == value) {
      final pending = _ownerSync;
      if (pending != null) return pending;
      if (!loading && _configuredOwnerRevision == _ownerRevision) {
        return Future.value();
      }
    }
    if (_requestedOwner != value) {
      _signupSession++;
      _confirmedSignupActor = null;
      _confirmedSignupPending = false;
    }
    _requestedOwner = value;
    final revision = ++_ownerRevision;
    final analyticsRevision = ++_analyticsRevision;
    final pending = _queueSettings(() async {
      if (revision != _ownerRevision) return;
      await analytics.pause();
      await diagnostics.enabled(false);
      _removeErrorHandler();
      if (_owner != null && _owner != value) {
        await diagnostics.discardPending();
      }
      final preference = _preferenceKey(value, 'analytics');
      final savedAnalytics = value == null
          ? null
          : preferences.getBool(preference);
      var allowed = savedAnalytics ?? false;
      UsageAnalyticsChoice? remote;
      var pendingChoice = false;
      var reviewChoice = false;
      if (analyticsChoices != null && value != null) {
        // Never turn a restored preference into a new ON write. In particular,
        // a remote OFF/revision0 must survive reinstall and another phone.
        try {
          remote = await analyticsChoices!.read(value);
          if (revision != _ownerRevision) return;
          pendingChoice = !remote.hasCurrentExplicitChoice;
          reviewChoice =
              pendingChoice && (remote.hasChoice || savedAnalytics != null);
          allowed =
              savedAnalytics != false &&
              remote.hasCurrentExplicitChoice &&
              remote.consent;
          if (remote.hasCurrentExplicitChoice && !remote.consent) {
            if (!await preferences.setBool(preference, false)) {
              throw StateError('analytics_preference_not_saved');
            }
          }
        } catch (_) {
          // Uncertain state permits normal product use, with measurement OFF.
          allowed = false;
        }
      }
      if (revision != _ownerRevision) return;
      // Uncertainty or a pending review is not a new opt-out. Retain the same
      // account/environment identity while collection stays paused. A failed
      // read still honors the existing local OFF veto.
      final keepPausedIdentity =
          analyticsChoices != null &&
          value != null &&
          (pendingChoice || (remote == null && savedAnalytics != false)) &&
          preferences.getString(_analyticsOwnerKey) == preference;
      final diagnosticsAllowed =
          value != null &&
          (preferences.getBool(_preferenceKey(value, 'diagnostics')) ?? false);
      await _setAnalyticsOwner(
        allowed || keepPausedIdentity ? preference : null,
      );
      if (revision != _ownerRevision) return;
      if (allowed) {
        await analytics.enabled(true);
        if (revision != _ownerRevision) {
          await analytics.pause();
          return;
        }
      }
      if (diagnosticsAllowed) {
        await diagnostics.enabled(true);
      } else if (value != null) {
        await diagnostics.discardPending();
      }
      if (revision != _ownerRevision) {
        await diagnostics.enabled(false);
        return;
      }
      if (diagnosticsAllowed) _installErrorHandler();
      _owner = value;
      _analyticsAllowed = allowed;
      _analyticsChoice = remote;
      _analyticsChoicePending = pendingChoice;
      _analyticsChoiceReview = reviewChoice;
      if (!pendingChoice && !allowed) _discardConfirmedSignup(value);
      diagnosticsEnabled = diagnosticsAllowed;
      lastAnalyticsEvent = null;
      lastAnalyticsResult = null;
      _configuredOwnerRevision = revision;
      _configuredAnalyticsRevision = analyticsRevision;
      loading = false;
      // A new device's default is not a revocation of the account's consent.
      if (value != null) {
        if (analyticsChoices == null && savedAnalytics != null) {
          _syncConsent(value, savedAnalytics);
        } else if (analyticsChoices != null &&
            remote != null &&
            !pendingChoice) {
          if (allowed) {
            _syncConsent(value, true);
          } else if (savedAnalytics == false &&
              (!remote.hasChoice || remote.consent)) {
            _syncConsent(value, false);
          }
        }
      }
      notifyListeners();
    });
    _ownerSync = pending;
    return pending
        .whenComplete(() {
          if (identical(_ownerSync, pending)) _ownerSync = null;
        })
        .then((_) => _flushConfirmedSignup());
  }

  Future<void> setAnalytics(bool value) {
    final actor = ownerId ?? _requestedOwner;
    final signupSession = _signupSession;
    // A same-owner refresh temporarily hides ownerId. An explicit OFF still
    // closes this signup scope before a delayed business ACK can arrive.
    if (!value) _discardConfirmedSignup(actor, session: signupSession);
    if (analyticsChoices != null) {
      return _setAnalyticsChoice(value).then(
        (_) => _flushConfirmedSignup(),
        onError: (Object error, StackTrace stack) {
          _discardConfirmedSignup(actor, session: signupSession);
          Error.throwWithStackTrace(error, stack);
        },
      );
    }
    final owner = ownerId;
    if (owner == null) return Future.value();
    final preferenceKey = _preferenceKey(owner, 'analytics');
    final revision = _ownerRevision;
    final analyticsRevision = ++_analyticsRevision;
    if (!value) _syncConsent(owner, false, explicitRevocation: true);
    return _queueSettings(() async {
      if (!value) await analytics.pause();
      if (!await preferences.setBool(preferenceKey, value)) {
        await preferences.reload();
        throw StateError('analytics_preference_not_saved');
      }
      if (revision != _ownerRevision) return;
      await _setAnalyticsOwner(value ? preferenceKey : null);
      if (value) {
        await analytics.enabled(true);
        if (revision != _ownerRevision) {
          await analytics.pause();
          return;
        }
      }
      if (revision != _ownerRevision) return;
      _analyticsAllowed = value;
      _configuredAnalyticsRevision = analyticsRevision;
      if (value) _syncConsent(owner, true);
      if (!value) {
        lastAnalyticsEvent = null;
        lastAnalyticsResult = null;
      }
      notifyListeners();
    });
  }

  Future<void> _setAnalyticsChoice(bool value) {
    final actor = ownerId;
    if (actor == null) return Future.value();
    final ownerRevision = _ownerRevision;
    final revision = ++_analyticsRevision;
    final key = _preferenceKey(actor, 'analytics');
    final signupSession = _signupSession;
    bool current() =>
        ownerRevision == _ownerRevision && revision == _analyticsRevision;

    // Start the authenticated intention now: a stalled ON must not block OFF
    // behind the SDK settings queue. OFF is also saved locally while offline.
    final known = _analyticsChoice;
    final decision = known != null
        ? analyticsChoices!.save(actor, value, known.revision)
        : () async {
            final before = await analyticsChoices!.read(actor);
            if (!current()) throw StateError('analytics_owner_changed');
            return analyticsChoices!.save(actor, value, before.revision);
          }();
    final localOff =
        (value ? Future.value(true) : preferences.setBool(key, false)).then(
          (saved) => saved,
          onError: (Object _) => false,
        );
    final pause = analytics.pause().catchError((Object _) {});
    // Register the error handler immediately, before this task reaches its
    // place in the settings queue (a prior SDK call may still be pending).
    final observed = decision
        .then<({UsageAnalyticsChoiceResult? result, Object? error})>(
          (result) => (result: result, error: null),
          onError: (Object error) => (result: null, error: error),
        );
    return _queueSettings(() async {
      await pause;
      await analytics.pause();
      final outcome = await observed;
      final offSaved = await localOff;
      final result = outcome.result;
      if (outcome.error != null ||
          (value &&
              (result?.applied != true ||
                  result!.state.consent != true ||
                  !result.state.hasCurrentExplicitChoice))) {
        // A same-session refresh can supersede this task before its error is
        // reported. It must still consume the unconfirmed signup, while a late
        // result from a previous login cannot consume another session's fact.
        _discardConfirmedSignup(actor, session: signupSession);
      }
      if (!offSaved) throw StateError('analytics_preference_not_saved');
      if (!current()) return;
      _analyticsAllowed = false;
      if (value && outcome.error != null) {
        notifyListeners();
        throw StateError('analytics_choice_not_confirmed');
      }
      if (result != null) _analyticsChoice = result.state;
      if (value &&
          (result?.applied != true ||
              result!.state.consent != true ||
              !result.state.hasCurrentExplicitChoice)) {
        // A definitive conflict can reveal another client's explicit OFF.
        // Observe it without creating a second consent write.
        if (result?.state.hasCurrentExplicitChoice == true &&
            !result!.state.consent) {
          if (!await preferences.setBool(key, false)) {
            throw StateError('analytics_preference_not_saved');
          }
          if (!current()) return;
          await _setAnalyticsOwner(null);
          if (!current()) return;
          _analyticsChoicePending = false;
          _configuredAnalyticsRevision = revision;
        }
        notifyListeners();
        throw StateError('analytics_choice_changed');
      }
      if (!await preferences.setBool(key, value)) {
        await preferences.reload();
        throw StateError('analytics_preference_not_saved');
      }
      if (!current()) return;
      await _setAnalyticsOwner(value ? key : null);
      if (!current()) return;
      if (value) await analytics.enabled(true);
      if (!current()) {
        await analytics.pause();
        return;
      }
      _analyticsAllowed = value;
      _analyticsChoicePending = false;
      _configuredAnalyticsRevision = revision;
      if (value) {
        _syncConsent(actor, true);
      } else {
        // An uncertain versioned OFF must not be repeated through legacy v2.
        // The next state read reconciles it; local withdrawal is immediate.
        lastAnalyticsEvent = null;
        lastAnalyticsResult = null;
      }
      notifyListeners();
    });
  }

  /// Apply an observed server OFF locally, without making another consent write.
  Future<void> observeAnalyticsRevoked(
    String actor, {
    required int expectedRevision,
  }) {
    if (ownerId != actor || _analyticsRevision != expectedRevision) {
      return Future.value();
    }
    _discardConfirmedSignup(actor);
    final ownerRevision = _ownerRevision;
    final revision = ++_analyticsRevision;
    return _queueSettings(() async {
      if (ownerRevision != _ownerRevision || revision != _analyticsRevision) {
        return;
      }
      await analytics.pause();
      await _setAnalyticsOwner(null);
      if (!await preferences.setBool(
        _preferenceKey(actor, 'analytics'),
        false,
      )) {
        throw StateError('analytics_preference_not_saved');
      }
      if (ownerRevision != _ownerRevision || revision != _analyticsRevision) {
        return;
      }
      _analyticsAllowed = false;
      _analyticsChoice = null;
      _analyticsChoicePending = false;
      _configuredAnalyticsRevision = revision;
      lastAnalyticsEvent = null;
      lastAnalyticsResult = null;
      notifyListeners();
    });
  }

  Future<void> setDiagnostics(bool value) {
    final owner = ownerId;
    if (owner == null) return Future.value();
    final revision = _ownerRevision;
    return _queueSettings(() async {
      if (revision != _ownerRevision) return;
      if (value) {
        await diagnostics.discardPending();
        if (revision != _ownerRevision) return;
        await diagnostics.enabled(true);
      } else {
        await diagnostics.enabled(false);
        await diagnostics.discardPending();
      }
      await preferences.setBool(_preferenceKey(owner, 'diagnostics'), value);
      if (revision != _ownerRevision) return;
      diagnosticsEnabled = value;
      value ? _installErrorHandler() : _removeErrorHandler();
      notifyListeners();
    });
  }

  /// Record a confirmed registration only with consent already effective.
  /// Enabling optional analytics later never reconstructs a past signup.
  Future<void> confirmedSignup(String actor) {
    if (_signupDisposed ||
        !preferencesReadyFor(actor) ||
        _confirmedSignupActor == actor) {
      return Future.value();
    }
    _confirmedSignupActor = actor;
    _confirmedSignupPending = analyticsConsentCurrent;
    return _flushConfirmedSignup();
  }

  void _discardConfirmedSignup(String? actor, {int? session}) {
    if (_signupDisposed ||
        actor == null ||
        _requestedOwner != actor ||
        (session != null && session != _signupSession)) {
      return;
    }
    // A decline/error may precede the registration ACK. Remember the terminal
    // actor for this session even when no pending fact has been observed yet.
    _confirmedSignupActor ??= actor;
    if (_confirmedSignupActor == actor) _confirmedSignupPending = false;
  }

  Future<void> _flushConfirmedSignup() async {
    final actor = _confirmedSignupActor;
    if (_signupDisposed ||
        actor == null ||
        !_confirmedSignupPending ||
        !analyticsConsentCurrent) {
      return;
    }
    final ownerRevision = _ownerRevision;
    final analyticsRevision = _analyticsRevision;
    // This continuation always runs outside a settings task. Waiting from
    // inside that queue would make consent wait for itself.
    await _settingsSync;
    await consentReady;
    if (_signupDisposed ||
        _confirmedSignupActor != actor ||
        !_confirmedSignupPending ||
        ownerRevision != _ownerRevision ||
        analyticsRevision != _analyticsRevision ||
        !preferencesReadyFor(actor) ||
        !analyticsConsentCurrent) {
      return;
    }
    // Consume before the SDK hop, so concurrent producers/flushes cannot repeat
    // an accepted or ambiguous event attempt.
    _confirmedSignupPending = false;
    await event('sign_up_completed');
  }

  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    if (!FirebaseProductAnalytics.allowed.contains(name)) {
      throw ArgumentError.value(name, 'name');
    }
    if (parameters != null && parameters.isNotEmpty) {
      throw ArgumentError.value(
        parameters,
        'parameters',
        'Dopmi measurement events do not accept payloads',
      );
    }
    if (!analyticsConsentCurrent || ownerId == null) {
      lastAnalyticsEvent = name;
      lastAnalyticsResult = 'omitido_sin_consentimiento';
      notifyListeners();
      return;
    }
    try {
      await analytics.event(name);
      lastAnalyticsEvent = name;
      lastAnalyticsResult = 'aceptado_por_sdk';
    } catch (cause) {
      lastAnalyticsEvent = name;
      lastAnalyticsResult = 'error_${cause.runtimeType}';
      // Measurement is optional and must never change the product result.
    }
    notifyListeners();
  }

  Future<void> diagnosticTest() async {
    if (!diagnosticsEnabled) return;
    await diagnostics.record(
      StateError('dopmi_diagnostics_test'),
      StackTrace.current,
      reason: 'internal_acceptance_test',
    );
    await diagnostics.sendPending();
  }

  void _installErrorHandler() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    _previousFlutterHandler = FlutterError.onError;
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    FlutterError.onError = (details) {
      _previousFlutterHandler?.call(details);
      unawaited(
        diagnostics.record(
          details.exception,
          details.stack ?? StackTrace.current,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(diagnostics.record(error, stack));
      return _previousPlatformHandler?.call(error, stack) ?? true;
    };
  }

  void _removeErrorHandler() {
    if (!_handlersInstalled) return;
    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;
    _previousFlutterHandler = null;
    _previousPlatformHandler = null;
    _handlersInstalled = false;
  }

  @override
  void dispose() {
    _signupDisposed = true;
    _confirmedSignupActor = null;
    _confirmedSignupPending = false;
    _removeErrorHandler();
    super.dispose();
  }
}

final measurementControllerProvider =
    ChangeNotifierProvider<MeasurementController?>((ref) => null);
