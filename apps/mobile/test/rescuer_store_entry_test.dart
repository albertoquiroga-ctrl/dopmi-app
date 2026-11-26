import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/config/adoption_only_build.dart';
import 'package:dopmi_mobile/core/navigation.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/experience_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/store/store_promotion.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'store_screen_test.dart' show StoreFake;

const _copy =
    'Compra a través de nuestra tienda y ayuda a que las mascotas en DopMi lleguen a más personas.';

Future<ProviderContainer> startRescuerStore(
  WidgetTester tester, {
  StoreFake? store,
  bool mismatchedActor = false,
  bool large = false,
}) async {
  tester.view.physicalSize = large
      ? const Size(320, 640)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final repository = store ?? StoreFake();
  final legal = legalVersionsForEnvironment(
    AppConfig.environment().environment,
  )!;
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true)
    ..profile = Profile(
      id: 'one',
      name: 'Ana',
      phone: '',
      city: '',
      mode: 'rescuer',
      intent: 'rescue',
      status: 'active',
      termsVersion: legal.terms,
      privacyVersion: legal.privacy,
      adultConfirmed: false,
    );
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(FakeCommunity()),
      rescueRepositoryProvider.overrideWithValue(FakeRescue()),
      storeRepositoryProvider.overrideWithValue(repository),
      if (mismatchedActor)
        storeActorProvider.overrideWith((ref) => Stream.value('other')),
      routerInitialLocationProvider.overrideWithValue('/rescuer'),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await identity.changes.close();
    await repository.changes.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DopmiApp()),
  );
  await tester.pumpAndSettle();
  expect(container.read(routerProvider).state.uri.path, '/rescuer');
  return container;
}

Future<void> openRescuerStore(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Croquetas con causa'),
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Ver más'));
  await tester.pumpAndSettle();
  expect(find.text('Ver más').hitTestable(), findsOneWidget);
  await tester.tap(find.text('Ver más'));
  await tester.pumpAndSettle();
  expect(find.byType(StoreScreen), findsOneWidget);
}

void expectRescuerNavigation(WidgetTester tester) {
  final bar = tester.widget<DopmiBottomBar>(find.byType(DopmiBottomBar).last);
  expect(bar.rescuer, isTrue);
  for (final label in ['Inicio', 'Casos', 'Publicar', 'Mensajes', 'Perfil']) {
    expect(find.bySemanticsLabel(label), findsOneWidget);
  }
  expect(find.bySemanticsLabel('Tienda'), findsNothing);
  expect(find.bySemanticsLabel('Adoptar'), findsNothing);
}

void main() {
  final enabledBuild = !adoptionOnlyBuild || storeAmazonAvailable;
  testWidgets(
    'rescuer home opens shared Store and Back retains home and five tabs',
    (tester) async {
      final container = await startRescuerStore(tester);
      await openRescuerStore(tester);
      expect(container.read(routerProvider).state.uri.path, '/store');
      expect(find.byType(StoreScreen), findsOneWidget);
      expect(find.text('Tienda Dopmi'), findsOneWidget);
      expectRescuerNavigation(tester);
      expect(
        container.read(experienceProvider).value,
        AccountExperience.rescuer,
      );
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/rescuer');
      expect(find.text('Croquetas con causa'), findsOneWidget);
      expect(find.text(_copy), findsOneWidget);
      expectRescuerNavigation(tester);
      expect(tester.takeException(), isNull);
    },
    skip: !enabledBuild,
  );

  for (final entry in {
    'Inicio': '/rescuer',
    'Casos': '/my-cases',
    'Perfil': '/profile',
  }.entries) {
    testWidgets('Store can return through rescuer ${entry.key}', (
      tester,
    ) async {
      final container = await startRescuerStore(tester);
      await openRescuerStore(tester);
      await tester.tap(find.bySemanticsLabel(entry.key));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, entry.value);
      expect(
        container.read(experienceProvider).value,
        AccountExperience.rescuer,
      );
      expectRescuerNavigation(tester);
      expect(tester.takeException(), isNull);
    }, skip: !enabledBuild);
  }

  for (final state in ['disabled', 'error', 'mismatched']) {
    testWidgets('home hides Store when catalog/actor is $state', (
      tester,
    ) async {
      final store = StoreFake()
        ..enabled = state != 'disabled'
        ..fail = state == 'error';
      await startRescuerStore(
        tester,
        store: store,
        mismatchedActor: state == 'mismatched',
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(find.text('Croquetas con causa'), findsNothing);
      expect(find.text('Ver más'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('adoption-only without Amazon does not expose the banner', (
    tester,
  ) async {
    await startRescuerStore(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
    await tester.pumpAndSettle();
    expect(find.byType(StorePromotion), findsNothing);
    expect(find.text('Croquetas con causa'), findsNothing);
  }, skip: enabledBuild);

  testWidgets('rescuer banner remains reachable at 320px and 200% text', (
    tester,
  ) async {
    await startRescuerStore(tester, large: true);
    await tester.scrollUntilVisible(
      find.text('Croquetas con causa'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_copy), findsOneWidget);
    await tester.ensureVisible(find.text('Ver más'));
    await tester.pumpAndSettle();
    expect(find.text('Ver más').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen), findsOneWidget);
    expectRescuerNavigation(tester);
    expect(tester.takeException(), isNull);
  }, skip: !enabledBuild);

  testWidgets('private preview retains TEST warning instead of buying copy', (
    tester,
  ) async {
    final container = await startRescuerStore(
      tester,
      store: StoreFake()
        ..preview = true
        ..expiresAt = DateTime.now().add(const Duration(hours: 1))
        ..externalLinksEnabled = false,
    );
    await tester.scrollUntilVisible(
      find.text('Vista previa de Tienda'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Catálogo TEST privado. No permite compras reales.'),
      findsOneWidget,
    );
    expect(find.text(_copy), findsNothing);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  }, skip: !enabledBuild);
}
