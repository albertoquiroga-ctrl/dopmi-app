import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceFixPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  LocationAccuracyStatus precision = LocationAccuracyStatus.precise;
  bool grantPrecise = true;
  int requests = 0, readings = 0;
  LocationSettings? settings;
  Position fix = Position(
    latitude: 25.686614,
    longitude: -100.316113,
    timestamp: DateTime.now(),
    accuracy: 8,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    permission = LocationPermission.whileInUse;
    if (grantPrecise) precision = LocationAccuracyStatus.precise;
    return permission;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => precision;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    settings = locationSettings;
    readings++;
    return fix;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform previous;
  late DeviceFixPlatform platform;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = GeolocatorPlatform.instance;
    platform = DeviceFixPlatform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = previous);
  test(
    'the device fix keeps its original coordinates and requests high accuracy',
    () async {
      final point = await LocationService().current();
      expect(point.latitude, 25.686614);
      expect(point.longitude, -100.316113);
      expect(platform.settings!.accuracy, LocationAccuracy.high);
      expect(platform.requests, 0);
    },
  );
  test(
    'an explicit choice upgrades an existing approximate grant only once',
    () async {
      platform.precision = LocationAccuracyStatus.reduced;
      final service = LocationService();
      await service.current();
      await service.current();
      expect(platform.requests, 1);
      expect(platform.readings, 2);
    },
  );
  test('precise permission cannot turn an inaccurate or stale fix into a nearby origin', () async {
    for (final sample in [
      (accuracy: 15000.0, age: const Duration(seconds: 1)),
      (accuracy: 0.0, age: const Duration(seconds: 1)),
      (accuracy: double.nan, age: const Duration(seconds: 1)),
      (accuracy: 8.0, age: const Duration(minutes: 2)),
      (accuracy: 8.0, age: const Duration(minutes: -1)),
    ]) {
      platform.fix = Position(
        latitude: 25.686614,
        longitude: -100.316113,
        timestamp: DateTime.now().subtract(sample.age),
        accuracy: sample.accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      await expectLater(
        LocationService().current(),
        throwsA(
          isA<LocationException>().having(
            (e) => e.message,
            'retry',
            contains('vuelve a intentarlo'),
          ),
        ),
      );
    }
    expect(platform.requests, 0);
    expect(platform.readings, 5);
  });
  test('foreground refresh never requests a precise upgrade or accepts a reduced fix', () async {
    platform.precision = LocationAccuracyStatus.reduced;
    await expectLater(
      LocationService().current(requestPermission: false),
      throwsA(isA<LocationException>()),
    );
    expect(platform.requests, 0);
    expect(platform.readings, 0);
  });
  test('keeping approximate access offers settings without repeated system requests, including after restart', () async {
    platform.precision = LocationAccuracyStatus.reduced;
    platform.grantPrecise = false;
    final service = LocationService();
    for (final attempt in [service, service, LocationService()]) {
      await expectLater(
        attempt.current(),
        throwsA(
          isA<LocationException>().having(
            (e) => e.settingsTarget,
            'settings',
            LocationSettingsTarget.app,
          ),
        ),
      );
    }
    expect(platform.requests, 1);
    expect(platform.readings, 0);
  });
}
