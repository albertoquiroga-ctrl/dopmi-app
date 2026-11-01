import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/location_selection.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:dopmi_mobile/features/adoption/nearby_location_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'nearby_location_test.dart' show mapConfig, FakeNearbyService;

class PendingNearbyCommunity extends FakeCommunity {
  final requests = <Json>[];
  final pending = <Completer<DataPage<Adoption>>>[];
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) {
    requests.add({...filters});
    final response = Completer<DataPage<Adoption>>();
    pending.add(response);
    return response.future;
  }
}

void main() {
  testWidgets(
    'discovery uses a coarse twenty km query and discards the older response without expanding its radius',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dopmi.nearby.prompt.v1:test:example.test:one': true,
      });
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final repo = PendingNearbyCommunity();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          configProvider.overrideWithValue(mapConfig),
          communityRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(FakeNearbyService()),
          routerInitialLocationProvider.overrideWithValue('/home'),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.requests.length, 1);
      container
          .read(nearbyLocationControllerProvider)
          .replace(
            SelectedLocation(
              latitude: 25.686614,
              longitude: -100.316113,
              city: 'Monterrey',
              region: 'Nuevo León',
            ),
            expectedOwner: 'one',
          );
      await tester.pump();
      expect(repo.requests.length, 2);
      expect(repo.requests.last, {
        'species': 'dog',
        'latitude': 25.69,
        'longitude': -100.32,
        'radius_km': 20,
      });
      repo.pending[1].complete(
        DataPage([
          Adoption({...repo.post.data, 'id': 'new', 'pet_name': 'Nueva'}),
        ], 1),
      );
      await tester.pumpAndSettle();
      repo.pending[0].complete(
        DataPage([
          Adoption({...repo.post.data, 'id': 'old', 'pet_name': 'Anterior'}),
        ], 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nueva'), findsWidgets);
      expect(find.text('Anterior'), findsNothing);
      expect(repo.requests.length, 2);
      container
          .read(nearbyLocationControllerProvider)
          .replace(
            SelectedLocation(latitude: 26, longitude: -101),
            expectedOwner: 'one',
          );
      await tester.pump();
      expect(repo.requests.length, 3);
      repo.pending[2].complete(const DataPage<Adoption>([], 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('en un radio de 20 km'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsNothing);
      await tester.tap(find.text('Cambiar ubicación'));
      await tester.pumpAndSettle();
      expect(find.text('Radio aproximado: 20 km'), findsOneWidget);
      expect(repo.requests.length, 3);
      await tester.ensureVisible(find.text('Buscar sin ubicación'));
      await tester.tap(find.text('Buscar sin ubicación'));
      await tester.pump();
      expect(repo.requests.length, 4);
      expect(repo.requests.last, {'species': 'dog'});
      repo.pending[3].complete(DataPage([repo.post], 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
