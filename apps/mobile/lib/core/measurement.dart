import 'dart:async';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'posthog_adoption.dart';

abstract interface class ProductAnalytics {
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
  Future<void> enabled(bool value) async {
    if (value) {
      await analytics.setConsent(
        analyticsStorageConsentGranted: true,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      await analytics.setAnalyticsCollectionEnabled(true);
      return;
    }
    await analytics.setAnalyticsCollectionEnabled(false);
    await analytics.setConsent(
      analyticsStorageConsentGranted: false,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    await analytics.resetAnalyticsData();
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

class MeasurementController extends ChangeNotifier {
  MeasurementController(
    this.preferences,
    this.namespace,
    this.analytics,
    this.diagnostics, {
    this.adoptionConsent,
    this._postHog,
    this._authenticatedOwner,
  });
  final Future<void> Function(String owner, bool consent)? adoptionConsent;
  final PostHogAdoptionAnalytics? _postHog;
  final String? Function()? _authenticatedOwner;
  Future<void> _consentSync = Future.value();
  Future<void> _analyticsPreferences = Future.value();
  int _adoptionConsentVersion = 0;
  bool _adoptionAnalyticsEnabled = false;
  final _pendingAdoptionRevocations = <String>{};
  String? get ownerId => _owner;
  bool preferencesReadyFor(String? owner) =>
      owner != null && _owner == owner && _readyOwner == owner;
  Future<void> get consentReady => _consentSync;
  bool get hasAdoptionAnalytics => _postHog != null;
  bool get adoptionAnalyticsSelected =>
      _adoptionAnalyticsEnabled &&
      preferencesReadyFor(_owner) &&
      _authenticatedOwner?.call() == _owner;
  bool get adoptionAnalyticsEnabled =>
      adoptionAnalyticsSelected &&
      !_pendingAdoptionRevocations.contains(_owner);

  void _syncConsent() {
    final callback = adoptionConsent;
    final expectedOwner = _owner;
    if (expectedOwner == null || callback == null) return;
    final enabled = analyticsEnabled;
    _consentSync = _consentSync
        .then((_) async {
          if (_owner == expectedOwner) await callback(expectedOwner, enabled);
        })
        .catchError((Object _) {});
  }

  final SharedPreferences preferences;
  final String namespace;
  final ProductAnalytics analytics;
  final ErrorDiagnostics diagnostics;
  String? _owner;
  String? _readyOwner;
  bool analyticsEnabled = false, diagnosticsEnabled = false, loading = true;
  String? lastAnalyticsEvent;
  String? lastAnalyticsResult;
  bool _handlersInstalled = false;
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;

  String key(String kind) => 'dopmi.$namespace.${_owner ?? 'signed-out'}.$kind';

  // The SDK is shared by all accounts on a device. Finish an in-flight
  // preference change before restoring another account's configuration.
  Future<void> _configureAnalytics(Future<void> Function() action) {
    final result = _analyticsPreferences.then((_) => action());
    _analyticsPreferences = result.catchError((Object _) {});
    return result;
  }

  Future<void> owner(String? value) => _configureAnalytics(() async {
    if (_owner == value && !loading && _readyOwner == value) return;
    _readyOwner = null;
    _adoptionConsentVersion++;
    _adoptionAnalyticsEnabled = false;
    await analytics.enabled(false);
    await diagnostics.enabled(false);
    _removeErrorHandler();
    if (_owner != null && _owner != value) {
      await diagnostics.discardPending();
    }
    _owner = value;
    lastAnalyticsEvent = null;
    lastAnalyticsResult = null;
    analyticsEnabled =
        value != null && (preferences.getBool(key('analytics')) ?? false);
    _adoptionAnalyticsEnabled =
        _postHog != null &&
        value != null &&
        (preferences.getBool(key('posthog-adoption-v1')) ?? false);
    diagnosticsEnabled =
        value != null && (preferences.getBool(key('diagnostics')) ?? false);
    await analytics.enabled(analyticsEnabled);
    if (diagnosticsEnabled) {
      await diagnostics.enabled(true);
    } else if (value != null) {
      await diagnostics.discardPending();
    }
    if (diagnosticsEnabled) _installErrorHandler();
    loading = false;
    _readyOwner = value;
    _syncConsent();
    notifyListeners();
  });

  Future<void> setAnalytics(bool value) {
    final requestingOwner = _owner;
    return _configureAnalytics(() async {
      if (!preferencesReadyFor(requestingOwner)) return;
      await analytics.enabled(value);
      await preferences.setBool(key('analytics'), value);
      analyticsEnabled = value;
      _syncConsent();
      if (!value) {
        lastAnalyticsEvent = null;
        lastAnalyticsResult = null;
      }
      notifyListeners();
    });
  }

  Future<void> setAdoptionAnalytics(bool value) {
    final actor = _owner;
    if (actor == null ||
        _postHog == null ||
        !preferencesReadyFor(actor) ||
        _authenticatedOwner?.call() != actor) {
      return Future.value();
    }
    final version = ++_adoptionConsentVersion;
    final preferenceKey = key('posthog-adoption-v1');
    if (!value) _pendingAdoptionRevocations.add(actor);
    return _configureAnalytics(() async {
      if (!await preferences.setBool(preferenceKey, value)) {
        throw StateError('posthog_consent_not_saved');
      }
      _pendingAdoptionRevocations.remove(actor);
      if (version == _adoptionConsentVersion &&
          preferencesReadyFor(actor) &&
          _authenticatedOwner?.call() == actor) {
        _adoptionAnalyticsEnabled = value;
      }
      notifyListeners();
    });
  }

  Future<void> Function(String)? adoptionAttempt(String? actor) {
    final postHog = _postHog;
    if (postHog == null ||
        !preferencesReadyFor(actor) ||
        !adoptionAnalyticsEnabled) {
      return null;
    }
    final consentVersion = _adoptionConsentVersion;
    final attempt = const Uuid().v4();
    DateTime? lastTimestamp;
    Future<void> pending = Future.value();
    return (event) {
      if (!PostHogAdoptionAnalytics.allowed.contains(event)) {
        return Future.value();
      }
      final previous = lastTimestamp;
      final now = DateTime.now().toUtc();
      final timestamp =
          previous != null &&
              now.millisecondsSinceEpoch <= previous.millisecondsSinceEpoch
          ? previous.add(const Duration(milliseconds: 1))
          : now;
      lastTimestamp = timestamp;
      return pending = pending.then((_) async {
        if (consentVersion == _adoptionConsentVersion &&
            preferencesReadyFor(actor) &&
            adoptionAnalyticsEnabled) {
          await postHog.capture(event, attempt, timestamp);
        }
      });
    };
  }

  Future<void> setDiagnostics(bool value) async {
    if (_owner == null) return;
    if (value) {
      await diagnostics.discardPending();
      await diagnostics.enabled(true);
    } else {
      await diagnostics.enabled(false);
      await diagnostics.discardPending();
    }
    await preferences.setBool(key('diagnostics'), value);
    diagnosticsEnabled = value;
    value ? _installErrorHandler() : _removeErrorHandler();
    notifyListeners();
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
    if (!analyticsEnabled) {
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
    _adoptionConsentVersion++;
    _postHog?.close();
    _removeErrorHandler();
    super.dispose();
  }
}

final measurementControllerProvider =
    ChangeNotifierProvider<MeasurementController?>((ref) => null);
