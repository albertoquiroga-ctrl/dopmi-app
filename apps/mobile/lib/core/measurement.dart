import 'dart:async';

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
    this.diagnostics,
  );
  final SharedPreferences preferences;
  final String namespace;
  final ProductAnalytics analytics;
  final ErrorDiagnostics diagnostics;
  String? _owner;
  bool analyticsEnabled = false, diagnosticsEnabled = false, loading = true;
  FlutterExceptionHandler? _previousFlutterHandler;

  String key(String kind) => 'dopmi.$namespace.${_owner ?? 'signed-out'}.$kind';

  Future<void> owner(String? value) async {
    if (_owner == value && !loading) return;
    await analytics.enabled(false);
    await diagnostics.enabled(false);
    _removeErrorHandler();
    if (_owner != null && _owner != value) {
      await diagnostics.discardPending();
    }
    _owner = value;
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
    loading = false;
    notifyListeners();
  }

  Future<void> setAnalytics(bool value) async {
    if (_owner == null) return;
    await analytics.enabled(value);
    await preferences.setBool(key('analytics'), value);
    analyticsEnabled = value;
    notifyListeners();
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
    if (analyticsEnabled) {
      try {
        await analytics.event(name);
      } catch (_) {
        // Measurement is optional and must never change the product result.
      }
    }
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
    if (_previousFlutterHandler != null) return;
    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousFlutterHandler?.call(details);
      unawaited(
        diagnostics.record(
          details.exception,
          details.stack ?? StackTrace.current,
        ),
      );
    };
  }

  void _removeErrorHandler() {
    if (_previousFlutterHandler == null) return;
    FlutterError.onError = _previousFlutterHandler;
    _previousFlutterHandler = null;
  }

  @override
  void dispose() {
    _removeErrorHandler();
    super.dispose();
  }
}

final measurementControllerProvider =
    ChangeNotifierProvider<MeasurementController?>((ref) => null);
