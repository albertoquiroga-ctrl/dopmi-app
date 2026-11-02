import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApproximateLocation {
  const ApproximateLocation(
    this.latitude,
    this.longitude, {
    this.accuracyMeters,
  });
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  double get roundedLatitude => (latitude * 100).round() / 100;
  double get roundedLongitude => (longitude * 100).round() / 100;
}

final locationServiceProvider = Provider<LocationService>(
  (_) => LocationService(),
);

class LocationService {
  LocationService();
  bool _precisionRequestedThisSession = false;
  static const _precisionRequestKey = 'dopmi.location.precision-requested.v1';

  Future<bool> _precisionWasRequested() async {
    if (_precisionRequestedThisSession) return true;
    try {
      return (await SharedPreferences.getInstance()).getBool(
            _precisionRequestKey,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<LocationPermission> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _precisionRequestedThisSession = true;
      try {
        await (await SharedPreferences.getInstance()).setBool(
          _precisionRequestKey,
          true,
        );
      } catch (_) {
        // Keep the current-session choice if device preferences are unavailable.
      }
    }
    return Geolocator.requestPermission();
  }

  Future<ApproximateLocation> current({bool requestPermission = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Activa la ubicación del dispositivo para usar tu ubicación actual.',
        settingsTarget: LocationSettingsTarget.device,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (requestPermission && permission == LocationPermission.denied) {
      permission = await _requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Activa el permiso de ubicación de Dopmi en los ajustes del dispositivo.',
        settingsTarget: LocationSettingsTarget.app,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Permite el acceso a tu ubicación para usar tu ubicación actual.',
      );
    }
    var precision = await Geolocator.getLocationAccuracy();
    final alreadyRequested = await _precisionWasRequested();
    if (precision == LocationAccuracyStatus.reduced &&
        requestPermission &&
        defaultTargetPlatform == TargetPlatform.android &&
        !alreadyRequested) {
      await _requestPermission();
      precision = await Geolocator.getLocationAccuracy();
    }
    if (precision != LocationAccuracyStatus.precise) {
      throw LocationException(
        'Activa la ubicación precisa de Dopmi para usar tu ubicación actual.',
        settingsTarget:
            defaultTargetPlatform == TargetPlatform.android &&
                !alreadyRequested &&
                !requestPermission
            ? null
            : LocationSettingsTarget.app,
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    // A precise permission is not a guarantee about this particular fix.
    // Reject stale or kilometre-scale estimates before they drive a 20 km feed.
    final age = DateTime.now().difference(position.timestamp);
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180 ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > 100 ||
        age > const Duration(seconds: 30) ||
        age < const Duration(seconds: -5)) {
      throw const LocationException(
        'No pudimos obtener una ubicación precisa y reciente. Busca un lugar con mejor señal y vuelve a intentarlo.',
      );
    }
    return ApproximateLocation(
      position.latitude,
      position.longitude,
      accuracyMeters: position.accuracy,
    );
  }

  Future<bool> openSettings(LocationSettingsTarget target) =>
      target == LocationSettingsTarget.app
      ? Geolocator.openAppSettings()
      : Geolocator.openLocationSettings();
}

enum LocationSettingsTarget { app, device }

class LocationException implements Exception {
  const LocationException(this.message, {this.settingsTarget});
  final String message;
  final LocationSettingsTarget? settingsTarget;
  @override
  String toString() => message;
}
