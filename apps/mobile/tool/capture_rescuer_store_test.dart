import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/store/store_promotion.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_repository.dart';
import 'package:dopmi_mobile/features/store/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/rescuer_store_entry_test.dart'
    show startRescuerStore, openRescuerStore, expectRescuerNavigation;
import '../test/store_screen_test.dart' show StoreFake;
import 'capture_design_test.dart' show saveCapture;

/// Actual bundled catalog, with only its authenticated actor supplied locally.
/// Product photos keep their explicit unavailable state in the widget test;
/// these captures do not claim remote-image or production-network verification.
class _BundledStoreCapture extends StoreFake {
  late final _bundled = StoreReviewRepository(
    currentUser: () => userId,
    changes: changes.stream,
    preview: false,
  );

  @override
  Future<StoreCatalog> catalog() => _bundled.catalog();
}

Future<void> _loadFonts(WidgetTester tester) async {
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

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  final images = find.byType(Image).evaluate().toList(growable: false);
  await tester.runAsync(() async {
    for (final element in images) {
      final provider = (element.widget as Image).image;
      if (provider is AssetImage) {
        await precacheImage(provider, element, onError: (_, _) {});
      }
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.runAsync(() => saveCapture(key, path));
}

void main() {
  for (final large in [false, true]) {
    final name = large ? '320x640-text200' : '390x844';
    testWidgets('capture rescuer Home and shared Store $name', (tester) async {
      await _loadFonts(tester);
      final out = Directory('../../.tools/qa-rescuer-store-20261124/visual');
      await tester.runAsync(() => out.create(recursive: true));
      final container = await startRescuerStore(
        tester,
        large: large,
        store: _BundledStoreCapture(),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Croquetas con causa'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(StorePromotion));
      expectRescuerNavigation(tester);
      await _capture(tester, key, '${out.path}/rescuer-home-$name.png');

      if (large) {
        await tester.ensureVisible(find.text('Ver más'));
        await tester.pumpAndSettle();
        expect(find.text('Ver más').hitTestable(), findsOneWidget);
        await _capture(
          tester,
          key,
          '${out.path}/rescuer-home-$name-action.png',
        );
      }

      await openRescuerStore(tester);
      expect(find.byType(StoreScreen), findsOneWidget);
      expect(find.text('Tienda Dopmi'), findsOneWidget);
      expectRescuerNavigation(tester);
      await _capture(tester, key, '${out.path}/rescuer-store-$name.png');
    });
  }
}
