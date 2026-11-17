// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_repository.dart';
import 'package:dopmi_mobile/features/store/store_screen.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';

import '../test/fake_identity_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/store_screen_test.dart' show StoreFake;
import 'capture_design_test.dart' show saveCapture;

void main() {
  if (const bool.fromEnvironment('CAPTURE_AMAZON_STORE')) {
    testWidgets('capture the Amazon Store and handoff', _captureAmazonStore);
    return;
  }

  testWidgets('capture Store widgets using test-only editorial fixtures', (
    tester,
  ) async {
    await _prepareStoreCapture(tester);
    final out = Directory('../../.tools/integral20d21-20261018/store');
    await tester.runAsync(() => out.create(recursive: true));
    for (final variant in [
      ('normal', 377.0, 852.0, 1.0, false),
      ('samsung115', 377.0, 852.0, 1.15, false),
      ('large', 320.0, 640.0, 2.0, false),
      ('preview-normal', 377.0, 852.0, 1.0, true),
      ('preview-samsung115', 377.0, 852.0, 1.15, true),
      ('preview-large', 320.0, 640.0, 2.0, true),
    ]) {
      tester.view.physicalSize = Size(variant.$2, variant.$3);
      tester.platformDispatcher.textScaleFactorTestValue = variant.$4;
      SharedPreferences.setMockInitialValues({});
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await identity.setExperience('donor');
      final repo = StoreFake();
      if (variant.$5) {
        repo.preview = true;
        repo.expiresAt = DateTime.now().add(const Duration(hours: 1));
        repo.externalLinksEnabled = false;
        repo.products = repo.products
            .map(
              (product) => StoreProduct(
                id: product.id,
                name: '${product.name} TEST',
                brand: '${product.brand} TEST',
                species: product.species,
                age: product.age,
                size: product.size,
                weightKg: product.weightKg,
                imageUrl: '',
                merchantName: 'Dopmi TEST',
                assetKey: 'croquetas-banner-pet',
              ),
            )
            .toList(growable: false);
      }
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              routerInitialLocationProvider.overrideWithValue('/store'),
              storeRepositoryProvider.overrideWithValue(repo),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            ],
            child: const DopmiApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${out.path}/store-${variant.$1}-fixture.png'),
      );
      await tester.ensureVisible(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtros').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Aplicar filtros'), findsOneWidget);
      await tester.runAsync(
        () => saveCapture(
          key,
          '${out.path}/store-filters-${variant.$1}-fixture.png',
        ),
      );
      for (final label in ['Aplicar filtros', 'Limpiar filtros']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget);
        await tester.runAsync(
          () => saveCapture(
            key,
            '${out.path}/store-filters-${variant.$1}-${label == 'Aplicar filtros' ? 'apply' : 'clear'}-fixture.png',
          ),
        );
      }
      await tester.tap(find.text('Limpiar filtros').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      await tester.scrollUntilVisible(
        find.text(variant.$5 ? 'Alimento uno TEST' : 'Alimento uno'),
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find
            .text(variant.$5 ? 'Alimento uno TEST' : 'Alimento uno')
            .hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(
        () => saveCapture(
          key,
          '${out.path}/store-${variant.$1}-product-fixture.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await repo.changes.close();
      await identity.changes.close();
    }
  });
}

Future<void> _prepareStoreCapture(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
    final loader = FontLoader(family)
      ..addFont(
        rootBundle.load(
          family == 'MaterialIcons'
              ? 'fonts/MaterialIcons-Regular.otf'
              : 'assets/fonts/$family.ttf',
        ),
      );
    await tester.runAsync(loader.load);
  }
}

Future<void> _captureAmazonStore(WidgetTester tester) async {
  await _prepareStoreCapture(tester);
  final out = Directory('../../.tools/store-amazon-review');
  await tester.runAsync(() => out.create(recursive: true));
  for (final (name, size, scale) in [
    ('normal', const Size(377, 852), 1.0),
    ('large', const Size(320, 640), 2.0),
  ]) {
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    SharedPreferences.setMockInitialValues({});
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    await identity.setExperience('donor');
    addTearDown(identity.changes.close);
    final repo = StoreReviewRepository(
      currentUser: () => identity.user?.id,
      changes: const Stream.empty(),
      preview: false,
    );
    final opened = <Uri>[];
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            routerInitialLocationProvider.overrideWithValue('/store'),
            storeRepositoryProvider.overrideWithValue(repo),
            storeLinkOpenerProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const DopmiApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final storeContext = tester.element(find.byType(StoreScreen));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/store/store-home.png'),
        storeContext,
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String screen) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${out.path}/$screen-$name.png'),
      );
    }

    final funding = find.text(
      'Las comisiones ayudan a sostener la app de adopción',
    );
    expect(tester.getBottomLeft(funding).dy, lessThan(size.height - 72));
    await capture('hero');
    final search = find.byKey(const ValueKey('store-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Pedigree adulto razas pequeñas');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final product = find.text('Adulto razas pequeñas').first;
    await tester.ensureVisible(product);
    await tester.pumpAndSettle();
    await tester.tap(product.hitTestable());
    await tester.pumpAndSettle();
    final detailAction = find.text('Ver producto en Amazon México');
    await tester.ensureVisible(detailAction);
    await tester.pumpAndSettle();
    await tester.tap(detailAction.hitTestable());
    await tester.pumpAndSettle();
    final handoff = find.byKey(const ValueKey('store-amazon-handoff'));
    expect(handoff, findsOneWidget);
    expect(tester.getBottomLeft(funding).dy, lessThan(size.height));
    await capture('handoff');

    final handoffScroll = find.descendant(
      of: handoff,
      matching: find.byType(Scrollable),
    );
    final amazon = find.text('Ir a Amazon México');
    await tester.scrollUntilVisible(amazon, 120, scrollable: handoffScroll);
    await tester.pumpAndSettle();
    expect(amazon.hitTestable(), findsOneWidget);
    if (scale > 1) await capture('handoff-actions');
    final stay = find.text('Seguir en DopMi');
    await tester.scrollUntilVisible(stay, 120, scrollable: handoffScroll);
    await tester.pumpAndSettle();
    await tester.tap(stay.hitTestable());
    await tester.pumpAndSettle();
    expect(handoff, findsNothing);
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }
}
