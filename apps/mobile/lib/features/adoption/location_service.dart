import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class ApproximateLocation {
  const ApproximateLocation(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  double get roundedLatitude => (latitude * 100).round() / 100;
  double get roundedLongitude => (longitude * 100).round() / 100;
}

final locationServiceProvider = Provider<LocationService>(
  (_) => const LocationService(),
);

class LocationService {
  const LocationService();

  Future<ApproximateLocation> current({bool requestPermission = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Activa la ubicación del dispositivo para usar tu ubicación actual.',
        settingsTarget: LocationSettingsTarget.device,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (requestPermission && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return ApproximateLocation(
      (position.latitude * 100).round() / 100,
      (position.longitude * 100).round() / 100,
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
