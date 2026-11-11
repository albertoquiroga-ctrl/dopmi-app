import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';
import '../test/store_screen_test.dart' show StoreFake;
import 'capture_design_test.dart' show saveCapture;

import 'package:dopmi_mobile/features/store/store_review_catalog.dart';

void main() {
  testWidgets('captures native catalog, search and exact presentations', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(377, 852);
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

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    await identity.setExperience('donor');
    addTearDown(identity.changes.close);
    final repo = StoreFake()
      ..preview = true
      ..expiresAt = DateTime.now().add(const Duration(hours: 1))
      ..externalLinksEnabled = false
      ..link = null
      ..products = storeReviewProducts;
    addTearDown(repo.changes.close);
    expect(storeReviewProducts.map((item) => item.id).toSet(), hasLength(127));
    expect(groupStoreProducts(storeReviewProducts), hasLength(32));

    final out = Directory('../../.tools/store-detail-preview');
    const examplePhoto = AssetImage('assets/store/review-packshot.png');

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            routerInitialLocationProvider.overrideWithValue('/store'),
            storeRepositoryProvider.overrideWithValue(repo),
            storePreviewImageProvider.overrideWithValue(
              (id) => id == 'whiskas-adult-3-1500' ? examplePhoto : null,
            ),
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
    await tester.runAsync(() => out.create(recursive: true));
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => saveCapture(key, '${out.path}/$name.png'));
    }

    expect(find.text('Vista previa de Tienda'), findsOneWidget);
    expect(find.text('Adulto razas pequeñas').hitTestable(), findsOneWidget);
    await capture('perros');

    await tester.tap(find.text('Gatos'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('store-search'));
    await tester.enterText(search, 'whiskas');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Adulto 4 en 1').hitTestable(), findsOneWidget);
    expect(find.text('Hogareños'), findsNothing);
    await capture('busqueda');

    await tester.tap(find.text('Adulto 4 en 1'));
    await tester.pumpAndSettle();
    final atun = find.byKey(const ValueKey('store-flavor-Atún'));
    final carne = find.byKey(const ValueKey('store-flavor-Carne'));
    await tester.ensureVisible(atun);
    await tester.tap(atun);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('store-variant-whiskas-adult-3-1500')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('store-variant-whiskas-adult-1-9000')),
      findsNothing,
    );
    final detail = tester.element(atun);
    await tester.runAsync(() => precacheImage(examplePhoto, detail));
    await tester.pumpAndSettle();
    expect(find.text('Imagen ilustrativa'), findsOneWidget);
    await capture('detalle');
    await tester.ensureVisible(carne);
    await tester.tap(carne);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('store-variant-whiskas-adult-1-9000')),
      findsOneWidget,
    );
    await capture('sabores-y-presentaciones');
    await tester.tap(find.byTooltip('Cerrar opciones'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    final family = find.text('Adulto 4 en 1');
    await tester.ensureVisible(family);
    await tester.tap(family);
    await tester.pumpAndSettle();
    await tester.ensureVisible(atun);
    expect(atun.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(repo.linked, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
