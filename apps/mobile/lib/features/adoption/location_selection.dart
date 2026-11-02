import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import 'location_service.dart';

const nearbyDefaultRadiusKm = 20;

class SelectedLocation {
  SelectedLocation({
    required double latitude,
    required double longitude,
    this.city = '',
    this.region = '',
    this.followDevice = false,
  }) : coordinates = _validated(latitude, longitude);

  static ApproximateLocation _validated(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const LocationException('Elige una ubicación válida.');
    }
    return ApproximateLocation(latitude, longitude);
  }

  final ApproximateLocation coordinates;
  final String city, region;
  final bool followDevice;
  double get latitude => coordinates.latitude;
  double get longitude => coordinates.longitude;
  String get label => [
    city.trim(),
    region.trim(),
  ].where((value) => value.isNotEmpty).join(', ');
  Map<String, dynamic> get payload => {
    'location_precision_version': 1,
    'approximate_latitude': latitude,
    'approximate_longitude': longitude,
  };

  static SelectedLocation? fromData(
    Map<String, dynamic> data, {
    String city = '',
    String region = '',
  }) {
    final lat = data['approximate_latitude'];
    final lon = data['approximate_longitude'];
    if (lat is! num || lon is! num) return null;
    try {
      return SelectedLocation(
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
        city: city,
        region: region,
      );
    } on LocationException {
      return null;
    }
  }
}

abstract interface class PlaceLookup {
  Future<SelectedLocation> search(String query);
  Future<SelectedLocation> describe(ApproximateLocation location);
}

final placeLookupProvider = Provider<PlaceLookup>((_) => NativePlaceLookup());

class NativePlaceLookup implements PlaceLookup {
  Geocoding get _geocoder => Geocoding(locale: const Locale('es', 'MX'));

  @override
  Future<SelectedLocation> search(String query) async {
    final results = await _geocoder.locationFromAddress(query.trim());
    if (results.isEmpty) {
      throw const LocationException(
        'No encontramos esa zona. Prueba otra ciudad.',
      );
    }
    final point = results.first;
    try {
      return await describe(
        ApproximateLocation(point.latitude, point.longitude),
      );
    } catch (_) {
      // Forward lookup already found a point; city/state can be entered manually.
      return SelectedLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
    }
  }

  @override
  Future<SelectedLocation> describe(ApproximateLocation location) async {
    final lat = location.latitude, lon = location.longitude;
    final results = await _geocoder.placemarkFromCoordinates(lat, lon);
    if (results.isEmpty) return SelectedLocation(latitude: lat, longitude: lon);
    final place = results.first;
    return SelectedLocation(
      latitude: lat,
      longitude: lon,
      city: (place.locality ?? '').trim().isNotEmpty
          ? place.locality!.trim()
          : (place.subAdministrativeArea ?? '').trim(),
      region: (place.administrativeArea ?? '').trim(),
    );
  }
}
