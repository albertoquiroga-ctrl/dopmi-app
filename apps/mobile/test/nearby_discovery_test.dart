import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:dopmi_mobile/features/adoption/nearby_location_controller.dart';
import 'package:dopmi_mobile/features/identity/experience_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

const _config = AppConfig(
  url: 'https://example.test',
  key: 'sb_publishable_fixture',
  redirect: 'io.dopmi.app://auth/callback',
  mapsEnabled: true,
);

class PendingNearbyCommunity extends FakeCommunity {
  final requests = <Json>[];
  final pending = <Completer<DataPage<Adoption>>>[];
  int supportRequests = 0;
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) {
    requests.add({...filters});
    final response = Completer<DataPage<Adoption>>();
    pending.add(response);
    return response.future;
  }

  @override
  Future<List<SupportOpportunity>> discoverySupport() async {
    supportRequests++;
    return supportItems;
  }
}

class PendingDeviceLocation extends LocationService {
  final permissionRequests = <bool>[];
  final pending = <Completer<ApproximateLocation>>[];
  @override
  Future<ApproximateLocation> current({bool requestPermission = true}) {
    permissionRequests.add(requestPermission);
    final result = Completer<ApproximateLocation>();
    pending.add(result);
    return result.future;
  }
}

Future<ProviderContainer> startNearbyDiscovery(
  WidgetTester tester, {
  required PendingNearbyCommunity repo,
  required PendingDeviceLocation service,
  required FakeIdentityRepository identity,
  AppConfig config = _config,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      configProvider.overrideWithValue(config),
      communityRepositoryProvider.overrideWithValue(repo),
      locationServiceProvider.overrideWithValue(service),
      routerInitialLocationProvider.overrideWithValue('/home'),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await identity.changes.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DopmiApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

FakeIdentityRepository nearbyIdentity() =>
    FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);

void expectNoManualOrigin() {
  expect(find.byType(Slider), findsNothing);
  expect(find.text('Elegir en mapa'), findsNothing);
  expect(find.text('Buscar por ciudad'), findsNothing);
  expect(find.text('Buscar sin ubicación'), findsNothing);
  expect(find.text('Ciudad o zona'), findsNothing);
  expect(find.byTooltip('Elegir ubicación'), findsNothing);
}

void main() {
  testWidgets(
    'only explanatory approval requests GPS and discovery uses its coarse fixed twenty km origin',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = PendingNearbyCommunity();
      final service = PendingDeviceLocation();
      await startNearbyDiscovery(
        tester,
        repo: repo,
        service: service,
        identity: nearbyIdentity(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mascotas cerca de ti'), findsOneWidget);
      expect(repo.requests, isEmpty);
      expect(service.permissionRequests, isEmpty);
      expectNoManualOrigin();

      await tester.tap(find.byKey(const ValueKey('nearby-location-dismiss')));
      await tester.pumpAndSettle();
      expect(repo.requests, isEmpty);
      expect(find.text('Luna'), findsNothing);
      expect(find.text('Activar ubicación'), findsOneWidget);
      expect(find.text('Ver casos para apoyar'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('discovery-location-activate')),
      );
      await tester.pumpAndSettle();
      expect(service.permissionRequests, isEmpty);
      await tester.tap(find.byKey(const ValueKey('nearby-location-allow')));
      await tester.pump();
      expect(service.permissionRequests, [true]);
      expect(repo.requests, isEmpty);

      service.pending.single.complete(
        const ApproximateLocation(25.686614, -100.316113),
      );
      await tester.pump();
      expect(repo.requests, [
        {
          'species': 'dog',
          'latitude': 25.69,
          'longitude': -100.32,
          'radius_km': 20,
        },
      ]);
      repo.pending.single.complete(DataPage([repo.post], 1));
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsWidgets);
      expect(repo.supportRequests, 1);
      expect(
        find.text('Mascotas en adopción a 20 km de tu ubicación actual'),
        findsOneWidget,
      );
      expectNoManualOrigin();
      final logo = find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == 'Dopmi',
      );
      expect(logo, findsOneWidget);
      expect(
        find.ancestor(of: logo, matching: find.byType(TextButton)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('denied GPS keeps adoptions empty even after changing filters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dopmi.nearby.prompt.v2:test:example.test:one': true,
    });
    final repo = PendingNearbyCommunity();
    final service = PendingDeviceLocation();
    await startNearbyDiscovery(
      tester,
      repo: repo,
      service: service,
      identity: nearbyIdentity(),
    );
    await tester.pumpAndSettle();
    expect(repo.requests, isEmpty);
    await tester.tap(find.byKey(const ValueKey('discovery-location-activate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nearby-location-allow')));
    await tester.pump();
    service.pending.single.completeError(
      const LocationException('No diste permiso para usar tu ubicación.'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No diste permiso para usar tu ubicación.'),
      findsOneWidget,
    );
    expect(find.text('Luna'), findsNothing);
    expect(find.text('Activar ubicación'), findsOneWidget);
    expect(find.text('Ver casos para apoyar'), findsOneWidget);
    await tester.tap(find.text('Gatos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    expect(repo.requests, isEmpty);
    expect(service.permissionRequests, [true]);
    expectNoManualOrigin();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'losing the device origin and changing mode discard pending adoption responses',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dopmi.nearby.prompt.v2:test:example.test:one': true,
      });
      final repo = PendingNearbyCommunity();
      final service = PendingDeviceLocation();
      final identity = nearbyIdentity();
      final container = await startNearbyDiscovery(
        tester,
        repo: repo,
        service: service,
        identity: identity,
      );
      await tester.pumpAndSettle();
      final nearby = container.read(nearbyLocationControllerProvider);
      Future<void> locate(double latitude, double longitude) async {
        final request = nearby.requestCurrentLocation(expectedOwner: 'one');
        await tester.pump();
        service.pending.last.complete(ApproximateLocation(latitude, longitude));
        await request;
        await tester.pump();
      }

      await locate(25.686614, -100.316113);
      expect(repo.requests.length, 1);
      final secondLocation = nearby.requestCurrentLocation(
        expectedOwner: 'one',
      );
      await tester.pump();
      repo.pending.first.complete(
        DataPage([
          Adoption({...repo.post.data, 'id': 'old', 'pet_name': 'Anterior'}),
        ], 1),
      );
      await tester.pump();
      expect(find.text('Anterior'), findsNothing);
      expect(repo.requests.length, 1);
      service.pending.last.complete(const ApproximateLocation(26, -101));
      await secondLocation;
      await tester.pump();
      expect(repo.requests.last, {
        'species': 'dog',
        'latitude': 26.0,
        'longitude': -101.0,
        'radius_km': 20,
      });
      repo.pending.last.complete(
        DataPage([
          Adoption({...repo.post.data, 'id': 'new', 'pet_name': 'Nueva'}),
        ], 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nueva'), findsWidgets);
      expect(find.text('Anterior'), findsNothing);
      expect(repo.supportRequests, 1);

      await locate(27, -102);
      expect(repo.requests.length, 3);
      container
          .read(experienceProvider)
          .applyProfile(await identity.setExperience('rescuer'));
      await tester.pump();
      repo.pending.last.complete(
        DataPage([
          Adoption({...repo.post.data, 'id': 'stale', 'pet_name': 'Obsoleta'}),
        ], 1),
      );
      await tester.pumpAndSettle();
      expect(nearby.isAdopter, isFalse);
      expect(nearby.selection, isNull);
      expect(find.text('Nueva'), findsNothing);
      expect(find.text('Obsoleta'), findsNothing);
      expect(repo.requests.length, 3);
      expect(repo.supportRequests, 1);
      expect(service.permissionRequests, [true, true, true]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled maps preserves the legacy discovery query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = PendingNearbyCommunity();
    final service = PendingDeviceLocation();
    await startNearbyDiscovery(
      tester,
      repo: repo,
      service: service,
      identity: nearbyIdentity(),
      config: const AppConfig(
        url: 'https://example.test',
        key: 'sb_publishable_fixture',
        redirect: 'io.dopmi.app://auth/callback',
      ),
    );
    expect(repo.requests, [
      {'species': 'dog'},
    ]);
    repo.pending.single.complete(DataPage([repo.post], 1));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsWidgets);
    expect(find.text('Activar ubicación'), findsNothing);
    expect(service.permissionRequests, isEmpty);
    expect(repo.supportRequests, 1);
    expect(tester.takeException(), isNull);
  });
}
