import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_repository.dart';
import 'package:dopmi_mobile/features/store/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;

const _adoptionFunding = 'Las comisiones ayudan a sostener la app de adopción';
const _affiliateDisclosure =
    'Como afiliado de Amazon, DopMi puede recibir una comisión por compras elegibles hechas desde esta Tienda.';

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
  final amazonStoreModes = ValueVariant<bool>({true, false});

  testWidgets(
    'cat kit explains the affiliate link and opens only after confirmation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(377, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final opened = <Uri>[];
      final changes = StreamController<String?>.broadcast();
      addTearDown(() => unawaited(changes.close()));
      String? actor = 'play-tester';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeRepositoryProvider.overrideWithValue(
              StoreReviewRepository(
                currentUser: () => actor,
                changes: changes.stream,
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
      expect(find.text('Más hogares para más mascotas'), findsOneWidget);
      expect(
        find.text('Elige un producto y compra en Amazon MX.'),
        findsOneWidget,
      );
      expect(find.text('Precio y pago en Amazon México'), findsOneWidget);
      final fundingHeading = find.text(_adoptionFunding);
      final affiliateNotice = find.text(_affiliateDisclosure);
      expect(fundingHeading, findsOneWidget);
      expect(affiliateNotice, findsOneWidget);
      expect(
        tester.getBottomLeft(affiliateNotice).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('store-search'))).dy,
        ),
      );
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
      final handoff = find.byKey(const ValueKey('store-amazon-handoff'));
      expect(handoff, findsOneWidget);
      final journey = find.byKey(const ValueKey('store-amazon-journey'));
      expect(journey, findsOneWidget);
      expect(
        find.descendant(of: journey, matching: find.text('DopMi')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: journey, matching: find.text('Amazon México')),
        findsOneWidget,
      );
      expect(find.text('Precio y pago'), findsOneWidget);
      expect(find.text('Código de afiliado incluido'), findsOneWidget);
      expect(find.text('Tu compra continúa en Amazon'), findsOneWidget);
      expect(fundingHeading, findsOneWidget);
      expect(affiliateNotice, findsOneWidget);
      expect(opened, isEmpty);
      await tester.tap(find.text('Seguir en DopMi'));
      await tester.pumpAndSettle();
      expect(handoff, findsNothing);
      expect(collar, findsOneWidget);
      expect(opened, isEmpty);
      await tester.tap(collar);
      await tester.pumpAndSettle();
      final openAmazon = find.text('Ir a Amazon México');
      await tester.ensureVisible(openAmazon);
      await tester.pumpAndSettle();
      await tester.tap(openAmazon);
      await tester.pumpAndSettle();
      expect(
        opened.single.toString(),
        'https://www.amazon.com.mx/dp/B0D8LZRS6H?tag=albertoquir0f-20',
      );
      await tester.tap(collar);
      await tester.pumpAndSettle();
      expect(handoff, findsOneWidget);
      actor = null;
      changes.add(null);
      await tester.pumpAndSettle();
      expect(handoff, findsNothing);
      expect(find.byKey(const ValueKey('store-kit-screen')), findsNothing);
      expect(opened, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Amazon Store opens the selected presentation', (tester) async {
    final preview = amazonStoreModes.currentValue!;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(377, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final opened = <Uri>[];
    final repository = StoreReviewRepository(
      currentUser: () => 'play-tester',
      changes: const Stream.empty(),
      preview: preview,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(repository),
          storePreviewImageProvider.overrideWithValue(
            storeReviewAmazonArtworkFor,
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
    expect(
      find.text(preview ? 'Vista previa de Tienda' : 'Tienda Dopmi'),
      findsOneWidget,
    );
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
    expect(
      find.text('Vista previa TEST'),
      preview ? findsOneWidget : findsNothing,
    );
    expect(find.textContaining('Enlace de afiliado'), findsOneWidget);
    final size = find.byKey(
      const ValueKey('store-variant-pedigree-mini-0-10000'),
    );
    await tester.ensureVisible(size);
    await tester.tap(size);
    await tester.pumpAndSettle();
    final image = find.byKey(
      const ValueKey('store-product-image-pedigree-mini-0-10000'),
    );
    expect(tester.widget<Image>(image).image, isA<NetworkImage>());
    expect(opened, isEmpty);
    await tester.tap(find.text('Ver producto en Amazon México'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store-amazon-handoff')), findsOneWidget);
    expect(opened, isEmpty);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    final handoffScroll = find.descendant(
      of: find.byKey(const ValueKey('store-amazon-handoff')),
      matching: find.byType(Scrollable),
    );
    final funding = find.text(_adoptionFunding);
    await tester.scrollUntilVisible(funding, 120, scrollable: handoffScroll);
    expect(funding, findsOneWidget);
    final continueToAmazon = find.text('Ir a Amazon México');
    await tester.scrollUntilVisible(
      continueToAmazon,
      120,
      scrollable: handoffScroll,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(continueToAmazon);
    tester.view.physicalSize = const Size(377, 852);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();
    expect(
      opened.single.toString(),
      'https://www.amazon.com.mx/dp/B00DUAMJDS?tag=albertoquir0f-20',
    );
  }, variant: amazonStoreModes);

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
    'Irlanda storefront separates branding and puts species before search',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, StoreFake());
      final wordmark = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/dopmi-wordmark.png',
      );
      expect(wordmark, findsOneWidget);
      final title = find.text('Tienda Dopmi');
      final dogs = find.byKey(const ValueKey('store-species-dog'));
      final cats = find.byKey(const ValueKey('store-species-cat'));
      final search = find.byKey(const ValueKey('store-search'));
      final filters = find.byTooltip('Filtros');
      expect(
        tester.getBottomLeft(wordmark).dy,
        lessThanOrEqualTo(tester.getTopLeft(title).dy),
      );
      expect(
        tester.getBottomLeft(dogs).dy,
        lessThanOrEqualTo(tester.getTopLeft(search).dy),
      );
      expect(
        tester.getBottomLeft(cats).dy,
        lessThanOrEqualTo(tester.getTopLeft(search).dy),
      );
      expect(
        tester.getCenter(filters).dy,
        closeTo(tester.getCenter(search).dy, 1),
      );
      expect(tester.getSize(filters).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(filters).height, greaterThanOrEqualTo(48));
    },
  );
  testWidgets(
    'Irlanda storefront keeps product sorting with the catalog heading',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, StoreFake());
      final sort = find.byKey(const ValueKey('store-sort'));
      final heading = find.text('Alimento para perros');
      final search = find.byKey(const ValueKey('store-search'));
      expect(
        tester.getCenter(sort).dy,
        closeTo(tester.getCenter(heading).dy, 1),
      );
      expect(
        tester.getTopLeft(sort).dy,
        greaterThan(tester.getBottomLeft(search).dy),
      );
      await tester.tap(sort);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Alimento uno')).dy,
        closeTo(tester.getTopLeft(find.text('Alimento dos')).dy, 1),
      );
      expect(
        tester.getTopLeft(find.text('Alimento uno')).dx,
        lessThan(tester.getTopLeft(find.text('Alimento dos')).dx),
      );
    },
  );
  testWidgets(
    'Irlanda product filters narrow brand flavor and presentation choices',
    (tester) async {
      final repo = StoreFake()
        ..products = [
          ..._foodVariants,
          const StoreProduct(
            id: 'res-2000',
            name: 'Adulto res',
            brand: 'Marca B',
            species: 'dog',
            age: 'adult',
            size: 'medium',
            weightKg: 2,
            imageUrl: '',
            merchantName: 'Comercio de prueba',
            flavor: 'Res',
          ),
          const StoreProduct(
            id: 'puppy-3000',
            name: 'Cachorro pollo',
            brand: 'Marca C',
            species: 'dog',
            age: 'puppy',
            size: 'medium',
            weightKg: 3,
            imageUrl: '',
            merchantName: 'Comercio de prueba',
            flavor: 'Pollo',
          ),
        ];
      await open(tester, repo);
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      Future<void> choose(String label) async {
        final option = find.widgetWithText(OutlinedButton, label);
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
      }

      await choose('Adulto');
      expect(find.widgetWithText(OutlinedButton, 'Marca C'), findsNothing);
      await choose('Marca A');
      expect(find.widgetWithText(OutlinedButton, 'Res'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '2 kg'), findsNothing);
      await choose('Salmón');
      expect(find.widgetWithText(OutlinedButton, '15 kg'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '1.5 kg'), findsOneWidget);
      await choose('Pollo');
      expect(find.widgetWithText(OutlinedButton, '1.5 kg'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '15 kg'), findsOneWidget);
      await choose('1.5 kg');
      await choose('15 kg');
      await tester.ensureVisible(find.text('Aplicar filtros'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('2 variantes'), findsOneWidget);
      expect(find.text('Adulto res'), findsNothing);
      expect(find.text('Cachorro pollo'), findsNothing);
      await tester.ensureVisible(find.text('Alimento adulto'));
      await tester.tap(find.text('Alimento adulto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('store-flavor-Salmón')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('store-variant-salmon-1500')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('store-variant-pollo-15000')),
        findsNothing,
      );
    },
  );
  testWidgets('Irlanda species changes discard incompatible brand filters', (
    tester,
  ) async {
    final repo = StoreFake()
      ..products = [
        ...storeFixtureProducts.where((item) => item.species == 'dog'),
        const StoreProduct(
          id: 'cat-puppy',
          name: 'Alimento felino cachorro',
          brand: 'Marca A',
          species: 'cat',
          age: 'puppy',
          size: 'small',
          weightKg: 1,
          imageUrl: '',
          merchantName: 'Comercio de prueba',
        ),
        const StoreProduct(
          id: 'cat-adult',
          name: 'Alimento felino adulto',
          brand: 'Marca B',
          species: 'cat',
          age: 'adult',
          size: 'small',
          weightKg: 2,
          imageUrl: '',
          merchantName: 'Comercio de prueba',
        ),
      ];
    await open(tester, repo);
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Adulto'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Marca A'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Marca A'));
    await tester.ensureVisible(find.text('Aplicar filtros'));
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    final cats = find.byKey(const ValueKey('store-species-cat'));
    await tester.ensureVisible(cats);
    await tester.tap(cats);
    await tester.pumpAndSettle();
    expect(find.text('Alimento felino adulto'), findsOneWidget);
    expect(find.text('Alimento felino cachorro'), findsNothing);
  });
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
      expect(find.text('Más hogares para más mascotas'), findsNothing);
      expect(find.text(_adoptionFunding), findsNothing);
      expect(
        find.textContaining('Catálogo TEST. No permite compras reales.'),
        findsOneWidget,
      );
      expect(find.text(_affiliateDisclosure), findsNothing);
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
    'storefront keeps its branded header visible and opens a centered filter dialog',
    (tester) async {
      await open(tester, StoreFake());
      final title = tester.widget<Text>(find.text('Tienda Dopmi'));
      expect(title.style?.fontFamily, 'Inter');
      expect(title.style?.fontSize, 28);
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
      await tester.ensureVisible(find.byTooltip('Ordenar: Menor a mayor kg'));
      await tester.tap(find.byTooltip('Ordenar: Menor a mayor kg'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Filtros'));
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
      FontWeight.w600,
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
