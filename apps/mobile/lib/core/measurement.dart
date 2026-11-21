import 'dart:async';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
  final PrepareAdoptionConsent? prepareAdoptionConsent;
  final Future<void> Function(String actor)? prepareAcquisition;
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

  Future<void> owner(String? value) {
    if (_requestedOwner == value) {
      final pending = _ownerSync;
      if (pending != null) return pending;
      if (!loading && _configuredOwnerRevision == _ownerRevision) {
        return Future.value();
      }
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
      final allowed = savedAnalytics ?? false;
      final diagnosticsAllowed =
          value != null &&
          (preferences.getBool(_preferenceKey(value, 'diagnostics')) ?? false);
      await _setAnalyticsOwner(
        revision == _ownerRevision && allowed ? preference : null,
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
      diagnosticsEnabled = diagnosticsAllowed;
      lastAnalyticsEvent = null;
      lastAnalyticsResult = null;
      _configuredOwnerRevision = revision;
      _configuredAnalyticsRevision = analyticsRevision;
      loading = false;
      // A new device's default is not a revocation of the account's consent.
      if (value != null && savedAnalytics != null) {
        _syncConsent(value, savedAnalytics);
      }
      notifyListeners();
    });
    _ownerSync = pending;
    return pending.whenComplete(() {
      if (identical(_ownerSync, pending)) _ownerSync = null;
    });
  }

  Future<void> setAnalytics(bool value) {
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
    _removeErrorHandler();
    super.dispose();
  }
}

final measurementControllerProvider =
    ChangeNotifierProvider<MeasurementController?>((ref) => null);
