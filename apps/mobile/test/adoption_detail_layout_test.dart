import 'dart:ui' as ui;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/adoption_detail_layout.dart';
import 'package:dopmi_mobile/features/adoption/community_ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class DetailRepository extends FakeCommunity {
  bool verified = false;
  bool available = true;
  bool loadPhotos = false;
  final signed = <String>[];
  @override
  Future<Adoption?> detail(String id) async => available ? post : null;

  @override
  Future<Json?> publicProfile(String id) async => {
    ...?await super.publicProfile(id),
    'verified': verified,
  };
  @override
  Future<String> photoUrl(String path) async {
    signed.add(path);
    if (loadPhotos) return 'https://example.test/$path.png';
    throw Exception('offline');
  }
}

class DistanceRepository extends DetailRepository {
  @override
  Future<Adoption?> detail(String id) async =>
      Adoption(Map<String, dynamic>.from(post.data)..remove('distance_km'));
}

void main() {
  testWidgets(
    'changing publication resets gallery even with shared photo paths',
    (tester) async {
      final repo = DetailRepository();
      final container = ProviderContainer(
        overrides: [communityRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      Future<void> show(String id) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: AdoptionDetailLayout(
                  post: Adoption({
                    ...repo.post.data,
                    'id': id,
                    'photos': ['approved/one', 'approved/two'],
                  }),
                  saved: false,
                  busy: false,
                  owner: false,
                  favorite: () {},
                  contact: () {},
                  share: () {},
                  report: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final semantics = tester.ensureSemantics();
      await show('first');
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
      await show('second');
      expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(PageView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(position.pixels, 0);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  Future<DetailRepository> open(
    WidgetTester tester, {
    bool large = false,
    bool photos = false,
    bool readyPhotos = false,
    bool verified = false,
    DetailRepository? repository,
    String initialLocation = '/adoptions/post',
    GlobalKey? boundaryKey,
  }) async {
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final repo = (repository ?? DetailRepository())
      ..verified = verified
      ..loadPhotos = readyPhotos;
    repo.post = Adoption({
      ...repo.post.data,
      'photos': photos ? ['approved/one', 'approved/two'] : <String>[],
      'vaccinated': true,
      'special_care': 'Necesita su medicamento cada mañana.',
    });
    final runtime = readyPhotos
        ? await tester.runAsync(() async {
            final landscape = img.encodePng(img.Image(width: 24, height: 8));
            final portrait = img.encodePng(img.Image(width: 8, height: 24));
            final runtime = PhotoRuntime(
              store: MemoryPhotoStore(),
              download: (url, _) async =>
                  url.path.endsWith('/one.png') ? landscape : portrait,
            );
            for (final path in repo.post.photos) {
              await runtime.load(adoptionPhotoSource(repo, path), width: 384);
            }
            return runtime;
          })
        : null;
    if (runtime != null) addTearDown(runtime.dispose);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        routerInitialLocationProvider.overrideWithValue(initialLocation),
        if (runtime != null) photoRuntimeProvider.overrideWithValue(runtime),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  for (final large in [false, true]) {
    for (final back in [false, true]) {
      testWidgets('detail header press pixels and navigation: $large/$back', (
        tester,
      ) async {
        final font = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
        await tester.runAsync(font.load);
        final key = GlobalKey();
        await open(tester, large: large, boundaryKey: key);
        final target = back
            ? find.byTooltip('Volver')
            : find.text('Refugio Luna');
        final router = GoRouter.of(tester.element(target));
        Future<List<int>?> pixels() => tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = data!.buffer.asUint8List().toList();
          image.dispose();
          return bytes;
        });
        final before = await pixels();
        final rect = tester.getRect(target);
        final held = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 200));
        expect(await pixels(), before);
        expect(tester.getRect(target), rect);
        expect(router.state.uri.path, '/adoptions/post');
        await held.cancel();
        await tester.pumpAndSettle();
        expect(await pixels(), before);
        expect(router.state.uri.path, '/adoptions/post');
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, back ? '/adoptions' : '/people/owner');
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final large in [false, true]) {
    for (final report in [false, true]) {
      testWidgets(
        'detail action pixels and callback on release: $large/$report',
        (tester) async {
          tester.view.physicalSize = large
              ? const Size(320, 640)
              : const Size(377, 852);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final font = FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
          await tester.runAsync(font.load);
          final key = GlobalKey();
          var shares = 0, reports = 0;
          final repo = FakeCommunity();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [communityRepositoryProvider.overrideWithValue(repo)],
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  home: Scaffold(
                    body: AdoptionDetailLayout(
                      post: repo.post,
                      saved: false,
                      busy: false,
                      owner: false,
                      favorite: () {},
                      contact: () {},
                      share: () => shares++,
                      report: () => reports++,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final target = report
              ? find.text('Reportar publicación')
              : find.byTooltip('Compartir');
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          Future<List<int>?> pixels() => tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final bytes = data!.buffer.asUint8List().toList();
            image.dispose();
            return bytes;
          });
          final rect = tester.getRect(target);
          final before = await pixels();
          final held = await tester.startGesture(rect.center);
          await tester.pump(const Duration(milliseconds: 200));
          expect(await pixels(), before);
          expect(tester.getRect(target), rect);
          expect(shares + reports, 0);
          await held.cancel();
          await tester.pumpAndSettle();
          expect(await pixels(), before);
          expect(shares + reports, 0);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(shares, report ? 0 : 1);
          expect(reports, report ? 1 : 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'saved detail favorite carries reference shadow and removes it on unsave',
    (tester) async {
      await open(tester);
      BoxDecoration decoration(String tooltip) {
        final button = find.byTooltip(tooltip);
        return tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(of: button, matching: find.byType(DecoratedBox))
                      .first,
                )
                .decoration
            as BoxDecoration;
      }

      expect(decoration('Guardar').boxShadow, isNull);
      await tester.tap(find.byTooltip('Guardar'));
      await tester.pumpAndSettle();
      // Server-backed favorite state uses .pet-detail-save.is-on treatment.
      expect(decoration('Guardada').boxShadow, const [
        BoxShadow(color: Color(0x24eb6425), spreadRadius: 1),
        BoxShadow(color: Color(0x47eb6425), blurRadius: 10),
        BoxShadow(color: Color(0x24eb6425), blurRadius: 16),
      ]);
      await tester.tap(find.byTooltip('Guardada'));
      await tester.pumpAndSettle();
      expect(decoration('Guardar').boxShadow, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final bottomInset in [0.0, 24.0]) {
    testWidgets(
      'adoption actions sit above the native safe area and stay fixed on scroll: $bottomInset',
      (tester) async {
        tester.view.padding = FakeViewPadding(bottom: bottomInset);
        addTearDown(tester.view.resetPadding);
        await open(tester);
        final cta = find.widgetWithText(FilledButton, 'Quiero saber más');
        final before = tester.getRect(cta);
        // b9 CSS11531–11538 keeps grid padding14 + native safe area.
        // Final save height58 (14489–14504) sets the grid row; CTA stretches
        // to that row despite its base min-height52. Preserve the bottom edge.
        expect(before.bottom, 852 - bottomInset - 14);
        expect(before.height, 58);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -350),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(cta), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'detail carries server-calculated discovery distance without fabricating it',
    (tester) async {
      final repository = DistanceRepository();
      repository.post = Adoption({...repository.post.data, 'distance_km': 3.4});
      await open(tester, repository: repository, initialLocation: '/adoptions');
      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3.4 km'), findsOneWidget);
      expect(find.text('Quiero saber más'), findsOneWidget);
    },
  );

  testWidgets(
    'badge requires server verification and health is visible without accordions',
    (tester) async {
      await open(tester, verified: false);
      expect(find.text('Rescatista verificado'), findsNothing);
      expect(find.text('Necesita su medicamento cada mañana.'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Más sobre su salud y cuidados'), findsNothing);
      expect(find.text('Vacunado'), findsOneWidget);
      expect(find.text('Requiere cuidados especiales'), findsOneWidget);
      expect(find.text('Raza'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real gallery tracks swipes and retries only approved photo paths',
    (tester) async {
      final repo = await open(tester, photos: true, verified: true);
      final semantics = tester.ensureSemantics();
      expect(find.text('Rescatista verificado'), findsOneWidget);
      expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Ver foto 1'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);
      expect(repo.signed.toSet(), {'approved/one', 'approved/two'});
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping a photo opens it uncropped and allows swiping and navigating back',
    (tester) async {
      await open(tester, photos: true, readyPhotos: true);
      final semantics = tester.ensureSemantics();

      final close = find.byTooltip('Cerrar fotos');
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
      expect(close, findsNothing);

      Finder photo(String path, BoxFit fit) => find.byWidgetPredicate(
        (widget) =>
            widget is RemotePhoto &&
            widget.source.path == path &&
            widget.fit == fit,
      );
      await tester.tap(photo('approved/two', BoxFit.cover));
      await tester.pumpAndSettle();
      expect(close, findsOneWidget);
      expect(find.text('Foto 2 de 2'), findsOneWidget);

      void expectUncropped(String path) {
        final image = find.descendant(
          of: photo(path, BoxFit.contain),
          matching: find.byType(Image),
        );
        expect(tester.widget<Image>(image).fit, BoxFit.contain);
      }

      expectUncropped('approved/two');
      await tester.tap(find.byTooltip('Foto anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Foto 1 de 2'), findsOneWidget);
      expectUncropped('approved/one');

      await tester.tap(find.byTooltip('Siguiente foto'));
      await tester.pumpAndSettle();
      final gallery = find.ancestor(
        of: photo('approved/two', BoxFit.contain),
        matching: find.byType(PageView),
      );
      await tester.drag(gallery, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Foto 1 de 2'), findsOneWidget);

      await tester.drag(
        find.ancestor(
          of: photo('approved/one', BoxFit.contain),
          matching: find.byType(PageView),
        ),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foto 2 de 2'), findsOneWidget);

      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(close, findsNothing);
      expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
      expect(find.text('Quiero saber más'), findsOneWidget);

      await tester.tap(find.byTooltip('Ver foto en pantalla completa'));
      await tester.pumpAndSettle();
      expect(find.text('Foto 2 de 2'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(close, findsNothing);
      expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty photo placeholder does not open a viewer', (
    tester,
  ) async {
    await open(tester);
    await tester.tapAt(tester.getCenter(find.byIcon(Icons.pets).first));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ver foto en pantalla completa'), findsNothing);
    expect(find.byTooltip('Cerrar fotos'), findsNothing);
  });

  testWidgets('refreshing a publication closes a viewer of removed photos', (
    tester,
  ) async {
    final repo = await open(tester, photos: true);
    await tester.tap(find.byTooltip('Ver foto en pantalla completa'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cerrar fotos'), findsOneWidget);

    repo.post = Adoption({
      ...repo.post.data,
      'photos': ['approved/two'],
    });
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Cerrar fotos'), findsNothing);
    expect(find.text('Quiero saber más'), findsOneWidget);
    final photo = tester.widget<RemotePhoto>(find.byType(RemotePhoto));
    expect(photo.source.path, 'approved/two');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'withdrawing a publication closes the viewer and keeps the detail route',
    (tester) async {
      final repo = await open(tester, photos: true);
      await tester.tap(find.byTooltip('Ver foto en pantalla completa'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cerrar fotos'), findsOneWidget);

      repo.available = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Cerrar fotos'), findsNothing);
      final notice = find.textContaining(
        'Esta publicación ya no está disponible',
      );
      expect(notice, findsOneWidget);
      expect(
        GoRouter.of(tester.element(notice)).state.uri.path,
        '/adoptions/post',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a single approved photo has no carousel controls', (
    tester,
  ) async {
    final repo = DetailRepository();
    final container = ProviderContainer(
      overrides: [communityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AdoptionDetailLayout(
              post: Adoption({
                ...repo.post.data,
                'photos': ['approved/one'],
              }),
              saved: false,
              busy: false,
              owner: false,
              favorite: () {},
              contact: () {},
              share: () {},
              report: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp(r'^Ver foto \d+$')), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(repo.signed.toSet(), {'approved/one'});
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview exposes real traits and gallery with no outgoing actions',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final repo = DetailRepository();
      final container = ProviderContainer(
        overrides: [communityRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      var calls = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AdoptionDetailLayout(
                preview: true,
                post: Adoption({
                  ...repo.post.data,
                  'photos': ['approved/one', 'approved/two'],
                  'age_band': 'adult',
                  'personality': ['playful', 'affectionate'],
                  'coexistence': ['apartment', 'first_time'],
                  'vaccinated': true,
                  'sterilized': false,
                }),
                saved: false,
                busy: false,
                owner: false,
                favorite: () => calls++,
                contact: () => calls++,
                share: () => calls++,
                report: () => calls++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Adulto'), findsOneWidget);
      expect(find.text('Juguetón'), findsOneWidget);
      expect(find.text('Cariñoso'), findsOneWidget);
      expect(find.text('Ideal para departamento'), findsOneWidget);
      expect(find.text('Ideal para primerizos'), findsOneWidget);
      expect(find.text('Vacunado'), findsOneWidget);
      expect(find.text('Esterilizado'), findsNothing);
      expect(find.text('Quiero saber más'), findsNothing);
      expect(find.byTooltip('Volver'), findsNothing);
      expect(find.byTooltip('Guardar'), findsNothing);
      expect(find.byTooltip('Compartir'), findsNothing);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
      await tester.tapAt(
        tester.getCenter(find.byType(PageView)).translate(0, -60),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ver foto en pantalla completa'), findsNothing);
      expect(find.byTooltip('Cerrar fotos'), findsNothing);
      expect(calls, 0);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text keeps contact and save fixed while content scrolls', (
    tester,
  ) async {
    await open(tester, large: true);
    expect(
      tester.getRect(find.text('Quiero saber más')).bottom,
      lessThanOrEqualTo(640),
    );
    expect(
      tester.getRect(find.byTooltip('Guardar')).bottom,
      lessThanOrEqualTo(640),
    );
    await tester.tap(find.text('Quiero saber más'));
    await tester.pumpAndSettle();
    expect(find.text('Conectar con Luna'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
