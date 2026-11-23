// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_amazon_listings.dart';
import 'package:dopmi_mobile/features/store/store_screen.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';

import '../test/fake_identity_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
      final versions = legalVersionsForEnvironment(
        const String.fromEnvironment('DOPMI_ENVIRONMENT', defaultValue: 'test'),
      )!;
      identity.profile = Profile(
        id: 'one',
        name: 'Ana',
        phone: '',
        city: '',
        mode: 'donor',
        intent: 'adopt',
        status: 'active',
        termsVersion: versions.terms,
        privacyVersion: versions.privacy,
      );
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
  final out = Directory('../../.tools/store-irlanda-20261123');
  await tester.runAsync(() => out.create(recursive: true));
  final fixtures =
      await tester.runAsync(_readStoreCaptureImages) ?? <String, Uint8List>{};
  final servedImages = <String>{};
  final previousImageClient = debugNetworkImageHttpClientProvider;
  final previousPlatform = debugDefaultTargetPlatformOverride;
  debugNetworkImageHttpClientProvider = () =>
      _StoreCaptureImageClient(fixtures, servedImages);
  try {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // These bytes, when supplied, are exact-URI fixtures downloaded separately.
    // They prove layout with the real product photo, not production networking.
    debugPrint(
      fixtures.isEmpty
          ? 'Store capture: no photo manifest; network photos show unavailable.'
          : 'Store capture: ${fixtures.length} exact-URI photo fixtures available.',
    );
    for (final (name, size, scale) in [
      ('377x852', const Size(377, 852), 1.0),
      ('377x852-samsung115', const Size(377, 852), 1.15),
      ('320x640-text200', const Size(320, 640), 2.0),
    ]) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      SharedPreferences.setMockInitialValues({});
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await identity.setExperience('donor');
      addTearDown(identity.changes.close);
      final versions = legalVersionsForEnvironment(
        const String.fromEnvironment('DOPMI_ENVIRONMENT', defaultValue: 'test'),
      )!;
      identity.profile = Profile(
        id: 'one',
        name: 'Ana',
        phone: '',
        city: '',
        mode: 'donor',
        intent: 'adopt',
        status: 'active',
        termsVersion: versions.terms,
        privacyVersion: versions.privacy,
      );
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
              storePreviewImageProvider.overrideWithValue(
                storeReviewAmazonArtworkFor,
              ),
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
          const AssetImage('assets/welcome-pets.png'),
          storeContext,
        ),
      );
      await tester.pumpAndSettle();

      Future<void> capture(String screen) async {
        // Flush decoders using only supplied exact-URL photos; other URLs retain
        // the explicit unavailable state instead of borrowing another variant.
        final images = find.byType(Image).evaluate().toList(growable: false);
        await tester.runAsync(() async {
          for (final element in images) {
            final image = (element.widget as Image).image;
            if (image is NetworkImage && fixtures.containsKey(image.url)) {
              await precacheImage(image, element, onError: (_, _) {});
            }
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => saveCapture(key, '${out.path}/flutter-$screen-$name.png'),
        );
      }

      Future<void> reveal(Finder control, {required Finder within}) async {
        final scroller = find
            .descendant(of: within, matching: find.byType(Scrollable))
            .first;
        if (control.evaluate().isEmpty) {
          await tester.scrollUntilVisible(control, 120, scrollable: scroller);
        }
        expect(control, findsOneWidget);
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        expect(control.hitTestable(), findsOneWidget);
        final rect = tester.getRect(control);
        expect(rect.left, greaterThanOrEqualTo(-.5));
        expect(rect.right, lessThanOrEqualTo(size.width + .5));
        expect(rect.top, greaterThanOrEqualTo(-.5));
        expect(rect.bottom, lessThanOrEqualTo(size.height + .5));
        expect(tester.takeException(), isNull);
      }

      final home = find.byType(StoreScreen);
      final funding = find.text(
        'Las comisiones ayudan a sostener la app de adopción',
      );
      expect(funding, findsOneWidget);
      if (scale <= 1.15) {
        expect(tester.getBottomLeft(funding).dy, lessThan(size.height - 72));
      }
      await capture('home');
      if (scale > 1.15) {
        await reveal(funding, within: home);
        await capture('home-mission');
      }

      final filter = find.byTooltip('Filtros');
      await reveal(filter, within: home);
      await tester.tap(filter.hitTestable());
      await tester.pumpAndSettle();
      final filters = find.byType(Dialog).last;
      expect(filters, findsOneWidget);
      await capture('filters');
      final apply = find.widgetWithText(FilledButton, 'Aplicar filtros');
      await reveal(apply, within: filters);
      expect(tester.getSize(apply).height, greaterThanOrEqualTo(48));
      await capture('filters-apply');
      final clear = find.widgetWithText(OutlinedButton, 'Limpiar filtros');
      await reveal(clear, within: filters);
      expect(tester.getSize(clear).height, greaterThanOrEqualTo(48));
      await capture('filters-clear');
      await tester.tap(clear.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      final kitEntry = find.byKey(const ValueKey('store-kit-entry'));
      await reveal(kitEntry, within: home);
      await tester.tap(kitEntry.hitTestable());
      await tester.pumpAndSettle();
      final kit = find.byKey(const ValueKey('store-kit-screen'));
      expect(kit, findsOneWidget);
      await capture('kit');
      final kitAction = find.byKey(
        const ValueKey('store-kit-amazon-kit-dog-collar'),
      );
      await reveal(kitAction, within: kit);
      expect(tester.getSize(kitAction).height, greaterThanOrEqualTo(48));
      await capture('kit-actions');
      // Inspect the real CTA without invoking a merchant or creating an order.
      expect(opened, isEmpty);
      await tester.tap(
        find
            .descendant(of: kit, matching: find.byType(BackButton))
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(kit, findsNothing);

      final search = find.byKey(const ValueKey('store-search'));
      await reveal(search, within: home);
      await tester.enterText(search, 'Pedigree adulto razas pequeñas');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final product = find.text('Adulto razas pequeñas').first;
      await tester.ensureVisible(product);
      await tester.pumpAndSettle();
      await tester.tap(product.hitTestable());
      await tester.pumpAndSettle();
      final detail = find.byKey(const ValueKey('store-product-detail'));
      expect(detail, findsOneWidget);
      await capture('detail');
      final detailAction = find.widgetWithText(
        FilledButton,
        'Ver producto en Amazon México',
      );
      await reveal(detailAction, within: detail);
      expect(tester.getSize(detailAction).height, greaterThanOrEqualTo(48));
      expect(find.textContaining('Enlace de afiliado'), findsOneWidget);
      await capture('detail-actions');
      await tester.tap(detailAction.hitTestable());
      await tester.pumpAndSettle();
      final handoff = find.byKey(const ValueKey('store-amazon-handoff'));
      expect(handoff, findsOneWidget);
      expect(funding, findsOneWidget);
      expect(
        find.descendant(
          of: handoff,
          matching: find.textContaining('Como afiliado de Amazon'),
        ),
        findsOneWidget,
      );
      await capture('handoff');
      await reveal(funding, within: handoff);
      if (scale > 1.15) await capture('handoff-funding');
      final amazon = find.widgetWithText(FilledButton, 'Ir a Amazon México');
      await reveal(amazon, within: handoff);
      expect(tester.getSize(amazon).height, greaterThanOrEqualTo(48));
      await capture('handoff-actions');
      final stay = find.widgetWithText(TextButton, 'Seguir en DopMi');
      await reveal(stay, within: handoff);
      expect(tester.getSize(stay).height, greaterThanOrEqualTo(48));
      if (scale > 1.15) await capture('handoff-stay');
      await tester.tap(stay.hitTestable());
      await tester.pumpAndSettle();
      expect(handoff, findsNothing);
      expect(opened, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    if (fixtures.isNotEmpty) expect(servedImages, isNotEmpty);
  } finally {
    debugNetworkImageHttpClientProvider = previousImageClient;
    debugDefaultTargetPlatformOverride = previousPlatform;
  }
}

/// Optional test-only JSON object: exact catalog image URL -> absolute file path.
/// Root downloads canonical source bytes separately; this capture never fetches
/// product images and never substitutes one URL's bytes for another presentation.
Future<Map<String, Uint8List>> _readStoreCaptureImages() async {
  final manifest = File(
    const String.fromEnvironment(
      'STORE_CAPTURE_IMAGE_MANIFEST',
      defaultValue:
          '../../.tools/store-irlanda-20261123/images/manifest.private.json',
    ),
  );
  if (!await manifest.exists()) return {};
  final value = jsonDecode(await manifest.readAsString());
  if (value is! Map<String, dynamic>) {
    throw const FormatException(
      'Store photo manifest must be a URL/path object',
    );
  }
  final fixtureRepo = StoreReviewRepository(
    currentUser: () => 'capture-only',
    changes: const Stream.empty(),
    preview: false,
  );
  final catalog = await fixtureRepo.catalog();
  final allowed = {
    for (final listing in storeReviewAmazonListings.values)
      if (listing.imageUri != null) listing.imageUri.toString(),
    for (final item in catalog.kitItems)
      if (item.imageUri != null) item.imageUri.toString(),
  };
  final images = <String, Uint8List>{};
  for (final entry in value.entries) {
    if (!allowed.contains(entry.key) || entry.value is! String) {
      throw const FormatException('Photo fixture is not an exact catalog URL');
    }
    final file = File(entry.value as String);
    if (!file.isAbsolute) {
      throw const FormatException('Photo fixture path must be absolute');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const FormatException('Photo fixture is empty');
    images[entry.key] = bytes;
  }
  return images;
}

class _StoreCaptureImageClient implements HttpClient {
  _StoreCaptureImageClient(this.fixtures, this.served);
  final Map<String, Uint8List> fixtures;
  final Set<String> served;
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final bytes = fixtures[url.toString()];
    if (bytes != null) served.add(url.toString());
    return _StoreCaptureImageRequest(bytes);
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StoreCaptureImageRequest implements HttpClientRequest {
  _StoreCaptureImageRequest(this.bytes);
  final Uint8List? bytes;
  @override
  final HttpHeaders headers = _StoreCaptureImageHeaders();
  @override
  Future<HttpClientResponse> close() async => _StoreCaptureImageResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StoreCaptureImageHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StoreCaptureImageResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _StoreCaptureImageResponse(this.bytes);
  final Uint8List? bytes;
  @override
  int get statusCode => bytes == null ? 404 : 200;
  @override
  int get contentLength => bytes?.length ?? 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([?bytes]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
