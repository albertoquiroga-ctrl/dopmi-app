import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_repository.dart';
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

const _foodVariants = [
  StoreProduct(
    id: 'salmon-1500',
    name: 'Adulto salmón',
    brand: 'Marca A',
    species: 'dog',
    age: 'adult',
    size: 'medium',
    sizes: ['medium', 'large'],
    weightKg: 1.5,
    imageUrl: '',
    merchantName: 'Comercio de prueba',
    familyId: 'adult',
    familyName: 'Alimento adulto',
    flavor: 'Salmón',
  ),
  StoreProduct(
    id: 'pollo-15000',
    name: 'Adulto pollo',
    brand: 'Marca A',
    species: 'dog',
    age: 'adult',
    size: 'medium',
    weightKg: 15,
    imageUrl: '',
    merchantName: 'Comercio de prueba',
    familyId: 'adult',
    familyName: 'Alimento adulto',
    flavor: 'Pollo',
  ),
];

class StoreFake implements StoreRepository {
  bool enabled = true, fail = false;
  bool preview = false, externalLinksEnabled = true;
  DateTime? expiresAt;
  int catalogCalls = 0;
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
    catalogCalls++;
    if (fail) throw StateError('offline');
    return StoreCatalog(
      enabled: enabled,
      products: products,
      preview: preview,
      expiresAt: expiresAt,
      externalLinksEnabled: externalLinksEnabled,
    );
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
  testWidgets(
    'cat kit opens the chosen accessory only after tapping its link',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(377, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final opened = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeRepositoryProvider.overrideWithValue(
              StoreReviewRepository(
                currentUser: () => 'play-tester',
                changes: const Stream.empty(),
              ),
            ),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            storeLinkOpenerProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: StoreScreen())),
        ),
      );
      await tester.pumpAndSettle();
      final cats = find.byKey(const ValueKey('store-species-cat'));
      await tester.ensureVisible(cats);
      await tester.tap(cats);
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('store-kit-entry'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('store-kit-screen')), findsOneWidget);
      expect(find.text('Kit de adopción para gatos'), findsOneWidget);
      expect(opened, isEmpty);
      expect(
        find.byKey(const ValueKey('store-kit-amazon-kit-dog-leash')),
        findsNothing,
      );
      final collar = find.byKey(
        const ValueKey('store-kit-amazon-kit-cat-collar'),
      );
      await tester.ensureVisible(collar);
      await tester.tap(collar);
      await tester.pumpAndSettle();
      expect(
        opened.single.toString(),
        'https://www.amazon.com.mx/dp/B0D8LZRS6H?tag=albertoquir0f-20',
      );
    },
  );

  testWidgets('internal Store opens the selected presentation on Amazon', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(377, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final opened = <Uri>[];
    final repository = StoreReviewRepository(
      currentUser: () => 'play-tester',
      changes: const Stream.empty(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(repository),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          storeLinkOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: StoreScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('store-search')),
      'Pedigree adulto razas pequeñas',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final product = find.text('Adulto razas pequeñas').first;
    await tester.ensureVisible(product);
    await tester.tap(product);
    await tester.pumpAndSettle();
    expect(find.textContaining('Enlace de afiliado'), findsOneWidget);
    final size = find.byKey(
      const ValueKey('store-variant-pedigree-mini-0-10000'),
    );
    await tester.ensureVisible(size);
    await tester.tap(size);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    await tester.tap(find.text('Ver producto en Amazon México'));
    await tester.pumpAndSettle();
    expect(
      opened.single.toString(),
      'https://www.amazon.com.mx/dp/B00DUAMJDS?tag=albertoquir0f-20',
    );
  });

  test('variant matching combines flavor, presentation and breed size', () {
    expect(
      filterStoreProducts(
        _foodVariants,
        species: 'dog',
        size: 'large',
        query: 'Marca A salmon 1,5kg',
      ).map((product) => product.id),
      ['salmon-1500'],
    );
    expect(
      filterStoreProducts(
        _foodVariants,
        species: 'dog',
        query: '1500 g',
      ).map((product) => product.id),
      ['salmon-1500'],
    );
    expect(
      filterStoreProducts(
        _foodVariants,
        species: 'dog',
        flavor: 'Salmón',
        weightKg: 15,
      ),
      isEmpty,
    );
    final groups = groupStoreProducts([
      ..._foodVariants,
      storeFixtureProducts.first,
    ]);
    expect(groups.map((group) => group.name), [
      'Alimento adulto',
      'Alimento uno',
    ]);
    expect(groups.first.variants.map((product) => product.id), [
      'salmon-1500',
      'pollo-15000',
    ]);
  });

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

  Future<void> openMerchant(WidgetTester tester) async {
    final action = find.widgetWithText(
      FilledButton,
      'Ver en Comercio de prueba',
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'private TEST catalog labels the preview and cannot open an external link while closed',
    (tester) async {
      final repo = StoreFake()
        ..preview = true
        ..expiresAt = DateTime.now().add(const Duration(hours: 1))
        ..externalLinksEnabled = false;
      var opened = 0;
      await open(
        tester,
        repo,
        opener: (_) async {
          opened++;
          return true;
        },
      );
      expect(find.text('Vista previa de Tienda'), findsOneWidget);
      expect(
        find.textContaining('Catálogo TEST. No permite compras reales.'),
        findsOneWidget,
      );
      expect(find.textContaining('Las comisiones corresponden'), findsNothing);
      await tester.ensureVisible(find.text('Alimento dos'));
      await tester.tap(find.text('Alimento dos'));
      await tester.pumpAndSettle();
      expect(repo.linked, isEmpty);
      expect(opened, 0);
      expect(find.text('Salida de prueba no habilitada'), findsWidgets);
      await tester.tap(find.byTooltip('Cerrar opciones'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'foreground rechecks access and preserves selection only for the same catalog mode',
    (tester) async {
      final repo = StoreFake()
        ..preview = true
        ..expiresAt = DateTime.now().add(const Duration(hours: 1))
        ..externalLinksEnabled = false;
      await open(tester, repo);
      await tester.tap(find.text('Gatos'));
      await tester.pumpAndSettle();
      expect(find.text('Alimento felino'), findsOneWidget);
      final before = repo.catalogCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.catalogCalls, greaterThan(before));
      expect(find.text('Alimento felino'), findsOneWidget);
      repo.enabled = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Alimento felino'), findsNothing);
      expect(find.text('Vista previa de Tienda'), findsNothing);
      expect(
        find.text('La Tienda Dopmi todavía no está disponible.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'preview expiry rechecks availability and clears rendered inventory',
    (tester) async {
      final repo = StoreFake()
        ..preview = true
        ..expiresAt = DateTime.now().add(const Duration(seconds: 5));
      await open(tester, repo);
      expect(find.text('Vista previa de Tienda'), findsOneWidget);
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      repo.enabled = false;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Alimento dos'), findsNothing);
      expect(
        find.text('La Tienda Dopmi todavía no está disponible.'),
        findsOneWidget,
      );
    },
  );
  for (final reason in ['account', 'foreground']) {
    testWidgets('open private filters are removed on $reason access change', (
      tester,
    ) async {
      final repo = StoreFake()
        ..preview = true
        ..expiresAt = DateTime.now().add(const Duration(hours: 1));
      await open(tester, repo);
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      repo.enabled = false;
      if (reason == 'account') {
        repo.switchActor('ordinary');
      } else {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Marca A'), findsNothing);
      expect(
        find.text('La Tienda Dopmi todavía no está disponible.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'open private detail observes revocation while catalog is offstage',
    (tester) async {
      final repo = StoreFake()
        ..preview = true
        ..expiresAt = DateTime.now().add(const Duration(hours: 1));
      await open(tester, repo);
      final item = find.text('Alimento dos');
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      final detail = find.byKey(const ValueKey('store-product-detail'));
      expect(detail, findsOneWidget);

      repo.enabled = false;
      repo.switchActor('ordinary');
      await tester.pumpAndSettle();
      expect(detail, findsNothing);
      expect(item, findsNothing);
      expect(
        find.text('La Tienda Dopmi todavía no está disponible.'),
        findsOneWidget,
      );
      expect(repo.linked, isEmpty);
    },
  );
  testWidgets(
    'storefront keeps its compact paw header visible and opens a centered filter dialog',
    (tester) async {
      await open(tester, StoreFake());
      final title = tester.widget<Text>(find.text('Tienda Dopmi'));
      expect(title.style?.fontFamily, 'Inter');
      expect(title.style?.fontSize, 24);
      expect(find.byTooltip('Regresar'), findsNothing);
      expect(find.text('Perros'), findsOneWidget);
      expect(find.text('Gatos'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      final titlePosition = tester.getTopLeft(find.text('Tienda Dopmi'));
      final catalogScroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(catalogScroll.maxScrollExtent, greaterThan(0));
      catalogScroll.jumpTo(catalogScroll.maxScrollExtent);
      await tester.pump();
      expect(tester.getTopLeft(find.text('Tienda Dopmi')), titlePosition);
      expect(find.text('Tienda Dopmi').hitTestable(), findsOneWidget);
      catalogScroll.jumpTo(0);
      await tester.pump();
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        Colors.transparent,
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
      await tester.tap(find.byTooltip('Ordenar: Menor a mayor kg'));
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
      expect(repo.linked, isEmpty);
      await openMerchant(tester);
      expect(opened.single, Uri.parse('https://shop.example/exact'));
      expect(repo.linked, ['a']);
      await tester.tap(find.byTooltip('Cerrar opciones'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Filtros activos'), findsOneWidget);
      expect(find.byTooltip('Ordenar: Mayor a menor kg'), findsOneWidget);
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
    await openMerchant(tester);
    expect(opens, 0);
    expect(find.textContaining('No pudimos abrir el comercio'), findsOneWidget);
    expect(find.text('Alimento dos'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar opciones'));
    await tester.pumpAndSettle();
  });
  testWidgets('variant picker opens only the selected presentation', (
    tester,
  ) async {
    final repo = StoreFake()..products = _foodVariants;
    final opened = <Uri>[];
    await open(
      tester,
      repo,
      opener: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.ensureVisible(find.text('Alimento adulto'));
    await tester.tap(find.text('Alimento adulto'));
    await tester.pumpAndSettle();
    final pollo = find.byKey(const ValueKey('store-flavor-Pollo'));
    await tester.ensureVisible(pollo);
    await tester.tap(pollo);
    await tester.pumpAndSettle();
    final weight = find.byKey(const ValueKey('store-variant-pollo-15000'));
    await tester.ensureVisible(weight);
    await tester.tap(weight);
    await tester.pumpAndSettle();
    await openMerchant(tester);
    expect(repo.linked, ['pollo-15000']);
    expect(opened, [repo.link]);
    await tester.tap(find.byTooltip('Cerrar opciones'));
    await tester.pumpAndSettle();
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
