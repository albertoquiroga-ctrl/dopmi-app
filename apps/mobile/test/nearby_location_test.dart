import 'dart:async';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/adoption/location_map_picker.dart';
import 'package:dopmi_mobile/features/adoption/location_selection.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:dopmi_mobile/features/adoption/nearby_location_controller.dart';
import 'package:dopmi_mobile/features/adoption/nearby_location_gate.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/experience_controller.dart';
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
  final settings = <LocationSettingsTarget>[];
  @override
  Future<bool> openSettings(LocationSettingsTarget target) async {
    settings.add(target);
    return true;
  }

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

Profile locationProfile(String mode, {String owner = 'one'}) => Profile(
  id: owner,
  name: 'Ana',
  phone: '',
  city: '',
  mode: mode,
  intent: 'adopt',
  status: 'active',
  termsVersion: currentTermsVersion,
  privacyVersion: currentPrivacyVersion,
  adultConfirmed: true,
);

Future<
  ({
    FakeIdentityRepository repo,
    ExperienceController experience,
    NearbyLocationController controller,
    FakeNearbyService service,
  })
>
locationFixture({String mode = 'donor', FakeNearbyService? service}) async {
  final repo = FakeIdentityRepository()
    ..user = const Identity('one', 'one@example.test', verified: true)
    ..profile = locationProfile(mode);
  final identity = IdentityController(repo);
  await identity.initialize();
  final experience = ExperienceController(identity);
  final gps = service ?? FakeNearbyService();
  final controller = NearbyLocationController(
    identity: identity,
    experience: experience,
    service: gps,
    environment: 'test:example.test',
  );
  addTearDown(() {
    controller.dispose();
    experience.dispose();
    identity.dispose();
  });
  await Future<void>.delayed(Duration.zero);
  return (
    repo: repo,
    experience: experience,
    controller: controller,
    service: gps,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('selected location retains precise private coordinates and rejects an absent pair', () {
    final point = SelectedLocation(latitude: 25.686614, longitude: -100.316113);
    expect(point.payload, {
      'location_precision_version': 1,
      'approximate_latitude': 25.686614,
      'approximate_longitude': -100.316113,
    });
    expect(SelectedLocation.fromData(point.payload)?.latitude, point.latitude);
    expect(
      SelectedLocation.fromData(point.payload)?.longitude,
      point.longitude,
    );
    expect(SelectedLocation.fromData({'approximate_latitude': 25.69}), isNull);
    expect(
      () => SelectedLocation(latitude: 90.001, longitude: 0),
      throwsA(isA<LocationException>()),
    );
  });
  test(
    'legacy manual-map choice cannot consume adopter explanation or start GPS',
    () async {
      SharedPreferences.setMockInitialValues({
        'dopmi.nearby.prompt.v1:test:example.test:one': true,
        'dopmi.nearby.follow-device.v1:test:example.test:one': true,
      });
      final f = await locationFixture();
      expect(f.controller.ready, isTrue);
      expect(f.controller.promptSeen, isFalse);
      expect(f.controller.selection, isNull);
      expect(f.service.permissionRequests, isEmpty);
      await f.controller.markPromptSeen(expectedOwner: 'one');
      await f.controller.refreshIfAllowed();
      expect(f.service.permissionRequests, isEmpty);
      expect(f.controller.discoveryFilters, isEmpty);
    },
  );
  test('adopter uses precise device position at twenty km and stores only booleans', () async {
    SharedPreferences.setMockInitialValues({});
    final f = await locationFixture(
      service: FakeNearbyService()
        ..pending = Future.value(
          const ApproximateLocation(25.686614, -100.316113),
        ),
    );
    await f.controller.markPromptSeen(expectedOwner: 'one');
    await f.controller.requestCurrentLocation(expectedOwner: 'one');
    expect(f.controller.discoveryFilters, {
      'latitude': 25.686614,
      'longitude': -100.316113,
      'radius_km': 20,
    });
    expect(f.service.permissionRequests, [true]);
    final prefs = await SharedPreferences.getInstance();
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getKeys().length, 2);
    expect(prefs.getKeys().every((key) => prefs.get(key) is bool), isTrue);
  });
  test('rescuer startup and foreground never read GPS even with saved adopter consent', () async {
    SharedPreferences.setMockInitialValues({
      'dopmi.nearby.prompt.v2:test:example.test:one': true,
      'dopmi.nearby.follow-device.v2:test:example.test:one': true,
    });
    final f = await locationFixture(
      mode: 'rescuer',
      service: FakeNearbyService()
        ..pending = Future.value(const ApproximateLocation(25.69, -100.32)),
    );
    await f.controller.refreshIfAllowed();
    await f.controller.requestCurrentLocation(expectedOwner: 'one');
    expect(f.service.permissionRequests, isEmpty);
    expect(f.controller.beginExplanation(), isFalse);
    f.experience.applyProfile(locationProfile('donor'));
    await Future<void>.delayed(Duration.zero);
    expect(f.service.permissionRequests, [false]);
    expect(f.controller.selection, isNotNull);
    f.experience.applyProfile(locationProfile('rescuer'));
    expect(f.controller.selection, isNull);
    await f.controller.refreshIfAllowed();
    expect(f.service.permissionRequests, [false]);
  });
  test('same-owner mode change invalidates an in-flight permission and its coordinates', () async {
    SharedPreferences.setMockInitialValues({});
    final gps = Completer<ApproximateLocation>();
    final f = await locationFixture(
      service: FakeNearbyService()..pending = gps.future,
    );
    await f.controller.markPromptSeen(expectedOwner: 'one');
    final request = f.controller.requestCurrentLocation(expectedOwner: 'one');
    f.experience.applyProfile(locationProfile('rescuer'));
    gps.complete(const ApproximateLocation(25.69, -100.32));
    await request;
    expect(f.controller.isAdopter, isFalse);
    expect(f.controller.discoveryFilters, isEmpty);
    expect(f.controller.busy, isFalse);
  });
  test('owner change drops the prior result and cannot restore another owner consent', () async {
    SharedPreferences.setMockInitialValues({});
    final gps = Completer<ApproximateLocation>();
    final f = await locationFixture(
      service: FakeNearbyService()..pending = gps.future,
    );
    await f.controller.markPromptSeen(expectedOwner: 'one');
    final request = f.controller.requestCurrentLocation(expectedOwner: 'one');
    f.repo.profile = locationProfile('donor', owner: 'two');
    f.repo.emit(
      const IdentityEvent(Identity('two', 'two@example.test', verified: true)),
    );
    gps.complete(const ApproximateLocation(25.69, -100.32));
    await request;
    await Future<void>.delayed(Duration.zero);
    expect(f.controller.ownerId, 'two');
    expect(f.controller.selection, isNull);
    expect(f.controller.promptSeen, isFalse);
    expect(f.service.permissionRequests, [true]);
  });
  test(
    'revoked permission clears the old position; settings recovery is explicit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final f = await locationFixture(
        service: FakeNearbyService()
          ..pending = Future.value(const ApproximateLocation(25.69, -100.32)),
      );
      await f.controller.markPromptSeen(expectedOwner: 'one');
      await f.controller.requestCurrentLocation(expectedOwner: 'one');
      f.service.pending = Future.error(
        const LocationException(
          'Activa ubicación.',
          settingsTarget: LocationSettingsTarget.app,
        ),
      );
      await f.controller.refreshIfAllowed();
      expect(f.controller.selection, isNull);
      expect(f.controller.error, 'Activa ubicación.');
      expect(f.service.permissionRequests, [true, false]);
      await f.controller.requestCurrentLocation(expectedOwner: 'one');
      expect(f.service.settings, [LocationSettingsTarget.app]);
      expect(f.service.permissionRequests, [true, false]);
    },
  );
  testWidgets(
    'explanation precedes permission; system inactive transition keeps the first result',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'one@example.test', verified: true);
      final gps = Completer<ApproximateLocation>();
      final service = FakeNearbyService()..pending = gps.future;
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          configProvider.overrideWithValue(mapConfig),
          locationServiceProvider.overrideWithValue(service),
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
      expect(find.text('Mascotas cerca de ti'), findsOneWidget);
      expect(find.text('Elegir en mapa'), findsNothing);
      expect(service.permissionRequests, isEmpty);
      await tester.tap(find.byKey(const ValueKey('nearby-location-allow')));
      await tester.pumpAndSettle();
      expect(service.permissionRequests, [true]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.permissionRequests, [true]);
      gps.complete(const ApproximateLocation(25.69, -100.32));
      await tester.pumpAndSettle();
      expect(
        container.read(nearbyLocationControllerProvider).selection,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dismissal never requests GPS and same-owner rescuer closes an open explanation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'one@example.test', verified: true);
      final service = FakeNearbyService();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          configProvider.overrideWithValue(mapConfig),
          locationServiceProvider.overrideWithValue(service),
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
      container
          .read(experienceProvider)
          .applyProfile(locationProfile('rescuer'));
      await tester.pumpAndSettle();
      expect(find.text('Mascotas cerca de ti'), findsNothing);
      expect(service.permissionRequests, isEmpty);
      container.read(experienceProvider).applyProfile(locationProfile('donor'));
      await tester.pumpAndSettle();
      // Explanation already seen; the later CTA can show it without a repeated startup interruption.
      expect(find.text('Mascotas cerca de ti'), findsNothing);
      expect(service.permissionRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('maps disabled does not offer location', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: NearbyLocationGate(child: Text('Inicio'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mascotas cerca de ti'), findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
  });
  test('late preferences restore cannot start GPS in the background', () async {
    SharedPreferences.setMockInitialValues({
      'dopmi.nearby.prompt.v2:test:example.test:one': true,
      'dopmi.nearby.follow-device.v2:test:example.test:one': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final restore = Completer<SharedPreferences>();
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'one@example.test', verified: true);
    final identity = IdentityController(repo);
    await identity.initialize();
    final experience = ExperienceController(identity);
    await Future<void>.delayed(Duration.zero);
    var foreground = true;
    final service = FakeNearbyService()
      ..pending = Future.value(const ApproximateLocation(25.69, -100.32));
    final controller = NearbyLocationController(
      identity: identity,
      experience: experience,
      service: service,
      environment: 'test:example.test',
      preferences: () => restore.future,
      isForeground: () => foreground,
    );
    addTearDown(() {
      controller.dispose();
      experience.dispose();
      identity.dispose();
    });
    foreground = false;
    controller.cancelForegroundRefresh();
    restore.complete(prefs);
    await Future<void>.delayed(Duration.zero);
    expect(controller.ready, isTrue);
    expect(service.permissionRequests, isEmpty);
    expect(controller.beginExplanation(), isFalse);
    foreground = true;
    await controller.refreshIfAllowed();
    expect(service.permissionRequests, [false]);
    expect(controller.selection, isNotNull);
    final pending = Completer<ApproximateLocation>();
    service.pending = pending.future;
    final request = controller.refreshIfAllowed();
    foreground = false; // The home gate may already be unmounted on Profile.
    pending.complete(const ApproximateLocation(26, -101));
    await request;
    expect(controller.selection, isNull);
    expect(controller.busy, isFalse);
    foreground = true;
    service.pending = Future.value(const ApproximateLocation(25.69, -100.32));
    await controller.refreshIfAllowed();
    expect(controller.selection, isNotNull);
  });
  testWidgets(
    'pet map requests GPS only from its own button and never enables adopter tracking',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'one@example.test', verified: true)
        ..profile = locationProfile('rescuer');
      final gps = Completer<ApproximateLocation>();
      final service = FakeNearbyService()..pending = gps.future;
      final lookup = PendingPlaceLookup();
      ApproximateLocation? shownPoint;
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          configProvider.overrideWithValue(mapConfig),
          locationServiceProvider.overrideWithValue(service),
          placeLookupProvider.overrideWithValue(lookup),
          locationMapBuilderProvider.overrideWithValue((
            context,
            point,
            select,
          ) {
            shownPoint = point;
            return const Text('Mapa de mascota');
          }),
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
      expect(service.permissionRequests, isEmpty);
      await tester.tap(find.text('Cerca de mi ubicación actual'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      gps.complete(const ApproximateLocation(25.686614, -100.316113));
      await tester.pump();
      lookup.requests.single.complete(
        SelectedLocation(
          latitude: 25.69,
          longitude: -100.32,
          city: 'Monterrey',
          region: 'Nuevo León',
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.permissionRequests, [true]);
      // Reverse geocoding supplies address metadata, never a substitute point.
      expect(shownPoint?.latitude, 25.686614);
      expect(shownPoint?.longitude, -100.316113);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('location-map-city')))
            .controller!
            .text,
        'Monterrey',
      );
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'map selection ignores an earlier lookup and returns the latest precise point',
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
      expect(result?.latitude, 26.224);
      expect(result?.longitude, -101.115);
      expect(result?.city, 'Zona reciente');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'geocoding failure keeps a precise map point usable with manual city and state',
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
        'location_precision_version': 1,
        'approximate_latitude': 25.686614,
        'approximate_longitude': -100.316113,
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
