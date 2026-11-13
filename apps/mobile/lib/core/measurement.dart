import 'dart:async';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
  final Future<void> Function(String owner, bool enabled)? adoptionConsent;
  Future<void> _consentSync = Future.value();
  Future<void> _settingsSync = Future.value();
  Future<void>? _ownerSync;
  String? _requestedOwner;
  int _ownerRevision = 0;
  int _configuredOwnerRevision = 0;
  int _analyticsRevision = 0;
  int _configuredAnalyticsRevision = 0;
  String? get ownerId =>
      _ownerRevision == _configuredOwnerRevision ? _owner : null;
  bool preferencesReadyFor(String? owner) => owner != null && ownerId == owner;
  int get analyticsRevision => _analyticsRevision;
  bool get analyticsConsentCurrent =>
      analyticsEnabled && _analyticsRevision == _configuredAnalyticsRevision;
  Future<void> get consentReady => _consentSync;

  Future<void> _queueSettings(Future<void> Function() apply) {
    final pending = _settingsSync.then((_) => apply());
    _settingsSync = pending.catchError((Object _) {});
    return pending;
  }

  void _syncConsent() {
    final callback = adoptionConsent;
    final expectedOwner = ownerId;
    if (expectedOwner == null || callback == null) return;
    final enabled = analyticsEnabled;
    final ownerRevision = _ownerRevision;
    final analyticsRevision = _configuredAnalyticsRevision;
    _consentSync = _consentSync
        .then((_) async {
          if (ownerId == expectedOwner &&
              ownerRevision == _ownerRevision &&
              analyticsRevision == _analyticsRevision) {
            await callback(expectedOwner, enabled);
          }
        })
        .catchError((Object _) {});
  }

  final SharedPreferences preferences;
  final String namespace;
  final ProductAnalytics analytics;
  final ErrorDiagnostics diagnostics;
  String? _owner;
  bool analyticsEnabled = false, diagnosticsEnabled = false, loading = true;
  String? lastAnalyticsEvent;
  String? lastAnalyticsResult;
  bool _handlersInstalled = false;
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;

  String key(String kind) => 'dopmi.$namespace.${_owner ?? 'signed-out'}.$kind';

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
      diagnosticsEnabled =
          value != null && (preferences.getBool(key('diagnostics')) ?? false);
      await analytics.enabled(analyticsEnabled);
      if (diagnosticsEnabled) {
        await diagnostics.enabled(true);
      } else if (value != null) {
        await diagnostics.discardPending();
      }
      if (diagnosticsEnabled) _installErrorHandler();
      if (revision != _ownerRevision) return;
      _configuredOwnerRevision = revision;
      _configuredAnalyticsRevision = analyticsRevision;
      loading = false;
      _syncConsent();
      notifyListeners();
    });
    _ownerSync = pending;
    return pending.whenComplete(() {
      if (identical(_ownerSync, pending)) _ownerSync = null;
    });
  }

  Future<void> setAnalytics(bool value) {
    if (ownerId == null) return Future.value();
    final preferenceKey = key('analytics');
    final revision = _ownerRevision;
    final analyticsRevision = ++_analyticsRevision;
    return _queueSettings(() async {
      if (revision == _ownerRevision) await analytics.enabled(value);
      await preferences.setBool(preferenceKey, value);
      if (revision != _ownerRevision) return;
      analyticsEnabled = value;
      _configuredAnalyticsRevision = analyticsRevision;
      _syncConsent();
      if (!value) {
        lastAnalyticsEvent = null;
        lastAnalyticsResult = null;
      }
      notifyListeners();
    });
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
