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
  Future<void>? _ownerTransition;
  String? _requestedOwner;
  int _pendingAnalyticsChanges = 0;
  String? get ownerId => _ownerTransition == null && !loading ? _owner : null;
  Future<void> get consentReady => _consentSync;

  void _syncConsent() {
    final callback = adoptionConsent;
    final expectedOwner = ownerId;
    if (expectedOwner == null || callback == null) return;
    final enabled = analyticsEnabled;
    _consentSync = _consentSync
        .then((_) async {
          if (ownerId == expectedOwner && analyticsEnabled == enabled) {
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
  bool _analyticsAllowed = false;
  bool diagnosticsEnabled = false, loading = true;
  bool get analyticsEnabled =>
      _analyticsAllowed && ownerId != null && _pendingAnalyticsChanges == 0;
  String? lastAnalyticsEvent;
  String? lastAnalyticsResult;
  bool _handlersInstalled = false;
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;

  // The SDK has one local identity. Store the preference key locally to scope
  // it to both the account and environment, without sending it to Firebase.
  static const _analyticsOwnerKey = 'dopmi.analyticsOwner';

  String _preferenceKey(String? owner, String kind) =>
      'dopmi.$namespace.${owner ?? 'signed-out'}.$kind';

  Future<void> prepareStartup() async {
    await analytics.pause();
    await diagnostics.enabled(false);
  }

  Future<void> _configure(Future<void> Function() action) {
    final pending = _settingsSync.then((_) => action());
    _settingsSync = pending.catchError((Object _) {});
    return pending;
  }

  Future<void> _setAnalyticsOwner(String? allowedPreference) async {
    final previous = preferences.getString(_analyticsOwnerKey);
    final next = allowedPreference ?? '';
    if (previous != next) {
      // A missing marker can mean an upgrade from a build that never recorded
      // the owner. Clear that unscoped identity once before accepting a grant.
      if (previous != '') await analytics.enabled(false);
      if (!await preferences.setString(_analyticsOwnerKey, next)) {
        await preferences.reload();
        throw StateError('analytics_owner_not_saved');
      }
    }
  }

  Future<void> owner(String? value) {
    if (_requestedOwner == value) {
      final transition = _ownerTransition;
      if (transition != null) return transition;
      if (_owner == value && !loading) return Future.value();
    }
    _requestedOwner = value;
    late final Future<void> transition;
    transition =
        _configure(() async {
          bool isCurrent() => identical(_ownerTransition, transition);
          await analytics.pause();
          await diagnostics.enabled(false);
          _removeErrorHandler();
          if (_owner != null && _owner != value) {
            await diagnostics.discardPending();
          }
          final preference = _preferenceKey(value, 'analytics');
          final allowed =
              value != null && (preferences.getBool(preference) ?? false);
          final diagnosticsAllowed =
              value != null &&
              (preferences.getBool(_preferenceKey(value, 'diagnostics')) ??
                  false);
          await _setAnalyticsOwner(isCurrent() && allowed ? preference : null);
          if (allowed && isCurrent()) {
            await analytics.enabled(true);
            if (!isCurrent()) await analytics.pause();
          }
          if (diagnosticsAllowed && isCurrent()) {
            await diagnostics.enabled(true);
            _installErrorHandler();
          } else if (value != null) {
            await diagnostics.discardPending();
          }
          _owner = value;
          _analyticsAllowed = allowed && isCurrent();
          diagnosticsEnabled = diagnosticsAllowed && isCurrent();
          lastAnalyticsEvent = null;
          lastAnalyticsResult = null;
        }).then(
          (_) {
            if (!identical(_ownerTransition, transition)) return;
            _ownerTransition = null;
            loading = false;
            _syncConsent();
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            if (identical(_ownerTransition, transition)) {
              _ownerTransition = null;
              _analyticsAllowed = false;
              loading = true;
            }
            Error.throwWithStackTrace(error, stack);
          },
        );
    _ownerTransition = transition;
    return transition;
  }

  Future<void> setAnalytics(bool value) {
    final requestingOwner = ownerId;
    if (requestingOwner == null) return Future.value();
    final preference = _preferenceKey(requestingOwner, 'analytics');
    _pendingAnalyticsChanges++;
    return _configure(() async {
      if (!value) await analytics.pause();
      if (!await preferences.setBool(preference, value)) {
        await preferences.reload();
        throw StateError('analytics_preference_not_saved');
      }
      if (ownerId != requestingOwner) return;
      await _setAnalyticsOwner(value ? preference : null);
      if (value && ownerId == requestingOwner) {
        await analytics.enabled(true);
        if (ownerId != requestingOwner) await analytics.pause();
      }
      if (ownerId != requestingOwner) return;
      _analyticsAllowed = value;
      if (!value) {
        lastAnalyticsEvent = null;
        lastAnalyticsResult = null;
      }
    }).then(
      (_) {
        _pendingAnalyticsChanges--;
        if (_pendingAnalyticsChanges == 0 && ownerId == requestingOwner) {
          _syncConsent();
          notifyListeners();
        }
      },
      onError: (Object error, StackTrace stack) {
        _pendingAnalyticsChanges--;
        if (ownerId == requestingOwner) _analyticsAllowed = false;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  Future<void> setDiagnostics(bool value) {
    final requestingOwner = ownerId;
    if (requestingOwner == null) return Future.value();
    return _configure(() async {
      if (ownerId != requestingOwner) return;
      if (value) {
        await diagnostics.discardPending();
        if (ownerId != requestingOwner) return;
        await diagnostics.enabled(true);
      } else {
        await diagnostics.enabled(false);
        await diagnostics.discardPending();
      }
      await preferences.setBool(
        _preferenceKey(requestingOwner, 'diagnostics'),
        value,
      );
      if (ownerId != requestingOwner) return;
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
    _removeErrorHandler();
    super.dispose();
  }
}

final measurementControllerProvider =
    ChangeNotifierProvider<MeasurementController?>((ref) => null);
