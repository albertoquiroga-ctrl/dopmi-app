import 'dart:async';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/adoption/location_map_picker.dart';
import 'package:dopmi_mobile/features/adoption/location_selection.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:dopmi_mobile/features/adoption/nearby_location_controller.dart';
import 'package:dopmi_mobile/features/adoption/nearby_location_gate.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_identity_repository.dart';

const mapConfig = AppConfig(
  url: 'https://example.test',
  key: 'sb_publishable_fixture',
  redirect: 'io.dopmi.app://auth/callback',
  mapsEnabled: true,
);

class FakeNearbyService extends LocationService {
  final permissionRequests = <bool>[];
  Future<ApproximateLocation>? pending;
  @override
  Future<ApproximateLocation> current({bool requestPermission = true}) async {
    permissionRequests.add(requestPermission);
    return pending == null
        ? throw const LocationException('Sin permiso.')
        : await pending!;
  }
}

class PendingPlaceLookup implements PlaceLookup {
  final requests = <Completer<SelectedLocation>>[];
  @override
  Future<SelectedLocation> describe(ApproximateLocation location) {
    final result = Completer<SelectedLocation>();
    requests.add(result);
    return result.future;
  }

  @override
  Future<SelectedLocation> search(String query) =>
      describe(const ApproximateLocation(0, 0));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('selected location stores only coarse coordinates and never manufactures an absent pair', () {
    final point = SelectedLocation(latitude: 25.686614, longitude: -100.316113);
    expect(point.coordinates.latitude, 25.69);
    expect(point.coordinates.longitude, -100.32);
    expect(point.payload, {
      'approximate_latitude': 25.69,
      'approximate_longitude': -100.32,
    });
    expect(SelectedLocation.fromData({'approximate_latitude': 25.69}), isNull);
    expect(
      () => SelectedLocation(latitude: 90.001, longitude: 0),
      throwsA(isA<LocationException>()),
    );
  });
  test('nearby prompt stores a boolean only and denial leaves a manual origin usable at twenty km', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'one@example.test', verified: true);
    final identity = IdentityController(repo);
    await identity.initialize();
    addTearDown(identity.dispose);
    final service = FakeNearbyService();
    final controller = NearbyLocationController(
      identity: identity,
      service: service,
      environment: 'test:example.test',
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.ready, isTrue);
    expect(controller.radiusKm, 20);
    expect(service.permissionRequests, isEmpty);
    expect(await controller.markPromptSeen(expectedOwner: 'one'), isTrue);
    await controller.refreshIfAllowed();
    expect(service.permissionRequests, isEmpty);
    expect(controller.selection, isNull);
    expect(
      controller.replace(
        SelectedLocation(latitude: 25.686614, longitude: -100.316113),
        expectedOwner: 'one',
      ),
      isTrue,
    );
    expect(controller.discoveryFilters, {
      'latitude': 25.69,
      'longitude': -100.32,
      'radius_km': 20,
    });
    final prefs = await SharedPreferences.getInstance();
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getKeys(), {
      'dopmi.nearby.prompt.v1:test:example.test:one',
      'dopmi.nearby.follow-device.v1:test:example.test:one',
    });
    expect(
      prefs.getBool('dopmi.nearby.prompt.v1:test:example.test:one'),
      isTrue,
    );
    expect(
      prefs.getBool('dopmi.nearby.follow-device.v1:test:example.test:one'),
      isFalse,
    );
  });
  test('an owner change drops the prior RAM zone and ignores an in-flight foreground GPS result', () async {
    SharedPreferences.setMockInitialValues({
      'dopmi.nearby.prompt.v1:test:example.test:one': true,
      'dopmi.nearby.follow-device.v1:test:example.test:one': true,
    });
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'one@example.test', verified: true);
    final identity = IdentityController(repo);
    await identity.initialize();
    addTearDown(identity.dispose);
    final gps = Completer<ApproximateLocation>();
    final service = FakeNearbyService()..pending = gps.future;
    final controller = NearbyLocationController(
      identity: identity,
      service: service,
      environment: 'test:example.test',
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(service.permissionRequests, [false]);
    repo.emit(
      const IdentityEvent(Identity('two', 'two@example.test', verified: true)),
    );
    await Future<void>.delayed(Duration.zero);
    gps.complete(const ApproximateLocation(25.69, -100.32));
    await Future<void>.delayed(Duration.zero);
    expect(controller.ownerId, 'two');
    expect(controller.selection, isNull);
    expect(controller.promptSeen, isFalse);
    expect(
      controller.replace(
        SelectedLocation(latitude: 0, longitude: 0),
        expectedOwner: 'one',
      ),
      isFalse,
    );
    expect(controller.discoveryFilters, isEmpty);
    final prod = NearbyLocationController(
      identity: identity,
      service: service,
      environment: 'production:example.test',
    );
    addTearDown(prod.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(prod.promptSeen, isFalse);
  });
  test('foreground and restart use GPS only after the explicit device choice; manual and skipped choices stop it', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'one@example.test', verified: true);
    final identity = IdentityController(repo);
    await identity.initialize();
    addTearDown(identity.dispose);
    final service = FakeNearbyService()
      ..pending = Future.value(const ApproximateLocation(25.69, -100.32));
    NearbyLocationController create() => NearbyLocationController(
      identity: identity,
      service: service,
      environment: 'test:example.test',
    );
    var controller = create();
    await Future<void>.delayed(Duration.zero);
    await controller.markPromptSeen(expectedOwner: 'one');
    controller.replace(null, expectedOwner: 'one');
    await Future<void>.delayed(Duration.zero);
    await controller.refreshIfAllowed();
    expect(service.permissionRequests, isEmpty);
    controller.dispose();
    controller = create();
    await Future<void>.delayed(Duration.zero);
    expect(controller.selection, isNull);
    expect(service.permissionRequests, isEmpty);
    controller.replace(
      SelectedLocation(latitude: 25.69, longitude: -100.32, followDevice: true),
      expectedOwner: 'one',
    );
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    controller = create();
    await Future<void>.delayed(Duration.zero);
    expect(service.permissionRequests, [false]);
    expect(controller.selection?.followDevice, isTrue);
    controller.replace(
      SelectedLocation(latitude: 26, longitude: -101),
      expectedOwner: 'one',
    );
    await Future<void>.delayed(Duration.zero);
    await controller.refreshIfAllowed();
    expect(service.permissionRequests, [false]);
    controller.dispose();
    controller = create();
    await Future<void>.delayed(Duration.zero);
    expect(service.permissionRequests, [false]);
    expect(controller.selection, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().every((key) => prefs.get(key) is bool), isTrue);
    controller.dispose();
  });
  testWidgets(
    'first location offer is optional and does not request GPS or persist a coordinate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'one@example.test', verified: true);
      final service = FakeNearbyService();
      int mapBuilds = 0;
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          configProvider.overrideWithValue(mapConfig),
          locationServiceProvider.overrideWithValue(service),
          locationMapBuilderProvider.overrideWithValue((
            context,
            point,
            select,
          ) {
            mapBuilds++;
            return const Text('Mapa de prueba');
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: NearbyLocationGate(child: Text('Inicio'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mapBuilds, greaterThan(0));
      expect(service.permissionRequests, isEmpty);
      await tester.ensureVisible(find.text('Ahora no'));
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(find.text('Mapa de prueba'), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
      expect(
        container.read(nearbyLocationControllerProvider).selection,
        isNull,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().length, 2);
      expect(
        prefs.getBool('dopmi.nearby.prompt.v1:test:example.test:one'),
        isTrue,
      );
      expect(
        prefs.getBool('dopmi.nearby.follow-device.v1:test:example.test:one'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('disabled maps never builds a native map or prompts location', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    int mapBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(
            const AppConfig(url: '', key: '', redirect: ''),
          ),
          locationMapBuilderProvider.overrideWithValue((
            context,
            point,
            select,
          ) {
            mapBuilds++;
            return const SizedBox();
          }),
        ],
        child: const MaterialApp(
          home: NearbyLocationGate(child: Text('Inicio')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(mapBuilds, 0);
    expect(find.text('Inicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'map selection ignores an earlier lookup and returns the latest coarse point',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final lookup = PendingPlaceLookup();
      SelectedLocation? result;
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'one@example.test', verified: true);
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          configProvider.overrideWithValue(mapConfig),
          placeLookupProvider.overrideWithValue(lookup),
          locationMapBuilderProvider.overrideWithValue(
            (context, point, select) => Column(
              children: [
                TextButton(
                  onPressed: () =>
                      select(const ApproximateLocation(25.686614, -100.316113)),
                  child: const Text('Zona A'),
                ),
                TextButton(
                  onPressed: () =>
                      select(const ApproximateLocation(26.224, -101.115)),
                  child: const Text('Zona B'),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await chooseLocationOnMap(context);
                  },
                  child: const Text('Abrir mapa'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zona A'));
      await tester.pump();
      await tester.tap(find.text('Zona B'));
      await tester.pump();
      lookup.requests[1].complete(
        SelectedLocation(
          latitude: 26.224,
          longitude: -101.115,
          city: 'Zona reciente',
          region: 'Estado reciente',
        ),
      );
      await tester.pump();
      lookup.requests[0].complete(
        SelectedLocation(
          latitude: 25.686614,
          longitude: -100.316113,
          city: 'Zona anterior',
          region: 'Anterior',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('location-map-city')))
            .controller!
            .text,
        'Zona reciente',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('location-map-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('location-map-confirm')));
      await tester.pumpAndSettle();
      expect(result?.latitude, 26.22);
      expect(result?.longitude, -101.12);
      expect(result?.city, 'Zona reciente');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'geocoding failure keeps a coarse map point usable with manual city and state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final lookup = PendingPlaceLookup();
      SelectedLocation? result;
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'one@example.test', verified: true);
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          configProvider.overrideWithValue(mapConfig),
          placeLookupProvider.overrideWithValue(lookup),
          locationMapBuilderProvider.overrideWithValue(
            (context, point, select) => TextButton(
              onPressed: () =>
                  select(const ApproximateLocation(25.686614, -100.316113)),
              child: const Text('Elegir punto'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await chooseLocationOnMap(context);
                  },
                  child: const Text('Abrir mapa'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir punto'));
      await tester.pump();
      lookup.requests.single.completeError(StateError('lookup failed'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('location-map-city')),
        'Monterrey',
      );
      await tester.enterText(
        find.byKey(const ValueKey('location-map-region')),
        'Nuevo León',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('location-map-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('location-map-confirm')));
      await tester.pumpAndSettle();
      expect(result?.payload, {
        'approximate_latitude': 25.69,
        'approximate_longitude': -100.32,
      });
      expect(result?.city, 'Monterrey');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'account switch removes the map surface and rejects its pending address result',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final lookup = PendingPlaceLookup();
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'one@example.test', verified: true);
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          configProvider.overrideWithValue(mapConfig),
          placeLookupProvider.overrideWithValue(lookup),
          locationMapBuilderProvider.overrideWithValue(
            (context, point, select) => TextButton(
              onPressed: () =>
                  select(const ApproximateLocation(25.69, -100.32)),
              child: const Text('Elegir punto'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: LocationMapPicker())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir punto'));
      await tester.pump();
      repo.emit(
        const IdentityEvent(
          Identity('two', 'two@example.test', verified: true),
        ),
      );
      await tester.pump();
      lookup.requests.single.complete(
        SelectedLocation(
          latitude: 25.69,
          longitude: -100.32,
          city: 'Anterior',
          region: 'Anterior',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elegir punto'), findsNothing);
      expect(find.byKey(const ValueKey('location-map-confirm')), findsNothing);
      expect(
        find.text('La cuenta cambió. Cierra el mapa y vuelve a abrirlo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
