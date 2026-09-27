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

  Future<ApproximateLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Activa la ubicación del dispositivo o escribe tu ciudad.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'No diste permiso. Puedes buscar manualmente por ciudad.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return ApproximateLocation(position.latitude, position.longitude);
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}
