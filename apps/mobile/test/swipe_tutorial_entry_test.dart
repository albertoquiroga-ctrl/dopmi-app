import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:dopmi_mobile/features/adoption/swipe_tutorial.dart';
import 'package:dopmi_mobile/features/adoption/swipe_tutorial_store.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'nearby_location_test.dart'
    show mapConfig, locationProfile, FakeNearbyService;
import 'rescue_test.dart' show FakeRescue;
import 'swipe_tutorial_gate_test.dart' show TutorialReceipts;

class TutorialCatalog extends FakeCommunity {
  int reads = 0;
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) {
    reads++;
    return super.discovery(filters, page);
  }
}

void main() {
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<({TutorialReceipts receipts, TutorialCatalog catalog})> start(
    WidgetTester tester, {
    bool maps = false,
    bool accepted = true,
    FakeNearbyService? locationService,
    String mode = 'donor',
    String route = '/adoptions',
  }) async {
    SharedPreferences.setMockInitialValues({});
    final receipts = TutorialReceipts();
    final catalog = TutorialCatalog();
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'one@example.test', verified: true)
      ..profile = accepted
          ? locationProfile(mode)
          : const Profile(
              id: 'one',
              name: 'Ana',
              phone: '',
              city: '',
              mode: 'donor',
              intent: 'adopt',
              status: 'active',
              termsVersion: '',
              privacyVersion: '',
              adultConfirmed: false,
            );
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(catalog),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        swipeTutorialStoreProvider.overrideWithValue(receipts),
        routerInitialLocationProvider.overrideWithValue(route),
        if (maps) configProvider.overrideWithValue(mapConfig),
        if (maps)
          locationServiceProvider.overrideWithValue(
            locationService ?? FakeNearbyService(),
          ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await frames(tester);
    return (receipts: receipts, catalog: catalog);
  }

  testWidgets(
    'app teaches before loading any real pet; skip opens unchanged catalog',
    (tester) async {
      final state = await start(tester);
      expect(find.byType(SwipeTutorial), findsOneWidget);
      expect(state.catalog.reads, 0);
      expect(state.catalog.seen, isEmpty);
      expect(state.receipts.writes, isEmpty);
      await tester.tap(find.text('Omitir'));
      await frames(tester);
      expect(find.byType(SwipeTutorial), findsNothing);
      expect(state.catalog.reads, greaterThan(0));
      expect(find.text('Luna'), findsWidgets);
      expect(state.receipts.writes, ['one']);
    },
  );

  testWidgets(
    'location explanation resolves before the tutorial even if declined',
    (tester) async {
      final state = await start(tester, maps: true);
      expect(find.text('Mascotas cerca de ti'), findsOneWidget);
      expect(find.byType(SwipeTutorial), findsNothing);
      expect(state.receipts.reads, ['one']);
      expect(state.receipts.writes, isEmpty);
      await tester.tap(find.byKey(const ValueKey('nearby-location-dismiss')));
      await frames(tester);
      expect(find.text('Mascotas cerca de ti'), findsNothing);
      expect(find.byType(SwipeTutorial), findsOneWidget);
      expect(state.catalog.reads, 0);
      await tester.tap(find.text('Omitir'));
      await frames(tester);
      expect(find.text('Activar ubicación'), findsWidgets);
      expect(state.catalog.reads, 0);
    },
  );

  testWidgets('unaccepted terms cannot trigger the tutorial', (tester) async {
    final state = await start(tester, accepted: false);
    expect(find.byType(SwipeTutorial), findsNothing);
    expect(state.receipts.reads, isEmpty);
    expect(state.receipts.writes, isEmpty);
    expect(state.catalog.reads, 0);
  });

  testWidgets('background and resume keep step two while GPS refreshes', (
    tester,
  ) async {
    final service = FakeNearbyService()
      ..pending = Future.value(const ApproximateLocation(25.69, -100.32));
    await start(tester, maps: true, locationService: service);
    await tester.tap(find.byKey(const ValueKey('nearby-location-allow')));
    await frames(tester);
    await tester.ensureVisible(find.text('Probar guardar'));
    await tester.tap(find.text('Probar guardar'));
    await tester.pump();
    expect(find.text('Desliza a la izquierda'), findsOneWidget);
    final refresh = Completer<ApproximateLocation>();
    service.pending = refresh.future;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Desliza a la izquierda'), findsOneWidget);
    refresh.complete(const ApproximateLocation(25.69, -100.32));
    await frames(tester);
    expect(find.text('Desliza a la izquierda'), findsOneWidget);
    expect(service.permissionRequests, contains(false));
  });

  for (final scenario in ['rescuer', 'detail', 'owner']) {
    testWidgets('$scenario does not teach the discovery gesture', (
      tester,
    ) async {
      final state = await start(
        tester,
        mode: scenario == 'rescuer' ? 'rescuer' : 'donor',
        route: scenario == 'rescuer'
            ? '/home'
            : scenario == 'owner'
            ? '/adoptions?owner=other'
            : '/adoptions/post',
      );
      expect(find.byType(SwipeTutorial), findsNothing);
      expect(state.receipts.reads, isEmpty);
    });
  }
}
