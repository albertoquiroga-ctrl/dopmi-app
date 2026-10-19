import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;

const storeFixtureProducts = [
  StoreProduct(
    id: 'a',
    name: 'Alimento uno',
    brand: 'Marca A',
    species: 'dog',
    age: 'adult',
    size: 'small',
    weightKg: 10,
    imageUrl: 'https://shop.example/a.jpg',
    merchantName: 'Comercio de prueba',
  ),
  StoreProduct(
    id: 'b',
    name: 'Alimento dos',
    brand: 'Marca B',
    species: 'dog',
    age: 'puppy',
    size: 'large',
    weightKg: 2,
    imageUrl: 'https://shop.example/b.jpg',
    merchantName: 'Comercio de prueba',
  ),
  StoreProduct(
    id: 'c',
    name: 'Alimento felino',
    brand: 'Marca A',
    species: 'cat',
    age: 'adult',
    size: 'small',
    weightKg: 1,
    imageUrl: 'https://shop.example/c.jpg',
    merchantName: 'Comercio de prueba',
  ),
];

class StoreFake implements StoreRepository {
  bool enabled = true, fail = false;
  String? actor = 'one';
  List<StoreProduct> products = storeFixtureProducts;
  Uri? link = Uri.parse('https://shop.example/exact');
  final linked = <String>[];
  final changes = StreamController<String?>.broadcast();
  @override
  String? get userId => actor;
  @override
  Stream<String?> get actorChanges => changes.stream;
  @override
  Future<StoreCatalog> catalog() async {
    if (fail) throw StateError('offline');
    return StoreCatalog(enabled: enabled, products: products);
  }

  @override
  Future<Uri?> productLink(String productId) async {
    linked.add(productId);
    return link;
  }

  void switchActor(String? next) {
    actor = next;
    changes.add(next);
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    StoreFake repo, {
    Future<bool> Function(Uri)? opener,
    Widget? child,
    double scale = 1,
  }) async {
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(repo),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          storeLinkOpenerProvider.overrideWithValue(
            opener ?? (_) async => true,
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child ?? const StoreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reference composition uses paw header, Inter title, inline species and a centered white filter dialog',
    (tester) async {
      await open(tester, StoreFake());
      final title = tester.widget<Text>(find.text('Tienda Dopmi'));
      expect(title.style?.fontFamily, 'Inter');
      expect(title.style?.fontSize, 28);
      expect(find.byTooltip('Regresar'), findsNothing);
      expect(find.text('Perros'), findsOneWidget);
      expect(find.text('Gatos'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        Colors.white,
      );
      expect(find.text('Tamaño de Raza'), findsOneWidget);
      expect(find.text('Chico'), findsOneWidget);
      expect(find.text('Grande'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Marca A'),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'clearing filters immediately clears applied values and closes the dialog',
    (tester) async {
      await open(tester, StoreFake());
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Marca A'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Marca A'));
      await tester.ensureVisible(find.text('Aplicar filtros'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Alimento dos'), findsNothing);
      await tester.tap(find.byTooltip('Filtros activos'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Limpiar filtros'));
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byTooltip('Filtros'), findsOneWidget);
      expect(find.text('Alimento dos'), findsOneWidget);
    },
  );
  test(
    'filters use real brands and numeric kg, independent from display names',
    () {
      expect(
        filterStoreProducts(
          storeFixtureProducts,
          species: 'dog',
        ).map((item) => item.id),
        ['b', 'a'],
      );
      expect(
        filterStoreProducts(
          storeFixtureProducts,
          species: 'dog',
          descending: true,
        ).map((item) => item.id),
        ['a', 'b'],
      );
      expect(
        filterStoreProducts(
          storeFixtureProducts,
          species: 'dog',
          brands: {'Marca A'},
          age: 'adult',
          size: 'small',
        ).single.id,
        'a',
      );
      expect(
        StoreCatalog.fromJson({
          'enabled': false,
          'items': [
            {'bad': 'stale'},
          ],
        }).products,
        isEmpty,
      );
    },
  );
  testWidgets(
    'disabled server gate hides entry and blocks deep route inventory',
    (tester) async {
      final repo = StoreFake()..enabled = false;
      await open(
        tester,
        repo,
        child: const Column(
          children: [
            StoreEntry.visible(child: Text('Entrada tienda')),
            Expanded(child: StoreScreen()),
          ],
        ),
      );
      expect(find.text('Entrada tienda'), findsNothing);
      expect(
        find.text('La Tienda Dopmi todavía no está disponible.'),
        findsOneWidget,
      );
      expect(find.text('Alimento uno'), findsNothing);
      expect(repo.linked, isEmpty);
    },
  );
  testWidgets(
    'brand filters and sort survive external merchant return without claiming a purchase',
    (tester) async {
      final repo = StoreFake();
      final opened = <Uri>[];
      await open(
        tester,
        repo,
        opener: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await tester.tap(find.text('Ordenar: Menor a mayor kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Marca A'));
      await tester.ensureVisible(find.text('Aplicar filtros'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Alimento dos'), findsNothing);
      await tester.ensureVisible(find.text('Alimento uno'));
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final beforeOpening = position.pixels;
      await tester.tap(find.text('Alimento uno'));
      await tester.pumpAndSettle();
      expect(opened.single, Uri.parse('https://shop.example/exact'));
      expect(repo.linked, ['a']);
      expect(find.byTooltip('Filtros activos'), findsOneWidget);
      expect(find.text('Ordenar: Mayor a menor kg'), findsOneWidget);
      expect(position.pixels, beforeOpening);
      expect(find.textContaining('Compra confirmada'), findsNothing);
      expect(find.textContaining('5%'), findsNothing);
    },
  );
  testWidgets('revoked link reports failure and keeps catalog usable', (
    tester,
  ) async {
    final repo = StoreFake()..link = null;
    var opens = 0;
    await open(
      tester,
      repo,
      opener: (_) async {
        opens++;
        return true;
      },
    );
    await tester.ensureVisible(find.text('Alimento dos'));
    await tester.tap(find.text('Alimento dos'));
    await tester.pumpAndSettle();
    expect(opens, 0);
    expect(find.textContaining('No pudimos abrir el comercio'), findsOneWidget);
    expect(find.text('Alimento dos'), findsOneWidget);
  });
  testWidgets('account change clears filters and replaces the catalog', (
    tester,
  ) async {
    final repo = StoreFake();
    await open(tester, repo);
    await tester.tap(find.text('Gatos'));
    await tester.pumpAndSettle();
    expect(find.text('Alimento felino'), findsOneWidget);
    repo.products = const [];
    repo.switchActor('two');
    await tester.pumpAndSettle();
    expect(find.text('Alimento felino'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('store-species-dog')))
          .style
          ?.textStyle
          ?.resolve({})
          ?.fontWeight,
      FontWeight.w700,
    );
  });
  testWidgets(
    'load failure offers retry and large text reflows without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = StoreFake()..fail = true;
      await open(tester, repo, scale: 2);
      expect(find.text('Reintentar'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Alimento dos'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
