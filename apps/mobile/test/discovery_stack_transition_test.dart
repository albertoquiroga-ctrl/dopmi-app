import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_ui.dart';
import 'package:dopmi_mobile/features/adoption/discovery_card_motion.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class CardPhotoCommunity extends FakeCommunity {
  final signed = <String>[];
  final recordedViews = <String>[];
  @override
  Future<void> recordAdoptionView(
    String postId, {
    required bool consent,
  }) async {
    if (consent) recordedViews.add(postId);
  }

  @override
  Future<String> photoUrl(String path) async {
    signed.add(path);
    return 'https://fixture.test/$path';
  }
}

class CardPhotoRescue extends FakeRescue {
  final signed = <String>[];
  @override
  Future<String> fileUrl(String path) async {
    signed.add(path);
    return 'https://fixture.test/$path';
  }
}

class PendingPageCommunity extends CardPhotoCommunity {
  final nextPage = Completer<DataPage<Adoption>>();
  final requestedPages = <int>[];
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) async {
    requestedPages.add(page);
    if (page == 1) return DataPage(discoveryItems!, 4);
    return nextPage.future;
  }
}

class CardFixture {
  CardFixture(this.repository, this.rescue, this.runtime, this.frames);
  final CardPhotoCommunity repository;
  final CardPhotoRescue rescue;
  final PhotoRuntime runtime;
  final Map<String, PhotoFrame> frames;
}

const cardColors = <String, List<int>>{
  'adoption/luna.jpg': [220, 30, 30],
  'adoption/milo.jpg': [30, 210, 40],
  'rescue/choco.jpg': [30, 40, 220],
  'adoption/nube.jpg': [220, 180, 30],
};

Finder card(String id) => find.byKey(ValueKey('discovery-motion-$id'));
Finder within(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);
Finder photoIn(Finder parent) => within(parent, find.byType(RemotePhoto));
Finder frontAction(String label) => find.byTooltip(label).hitTestable();

Transform renderedMotion(WidgetTester tester, Finder parent) =>
    tester.widget<Transform>(within(parent, find.byType(Transform)).first);

ImageProvider renderedProvider(WidgetTester tester, Finder parent) =>
    tester.widget<Image>(within(photoIn(parent), find.byType(Image))).image;

Future<void> assertDecodedColor(
  WidgetTester tester,
  Finder parent,
  String path,
) async {
  final raw = tester.widget<RawImage>(
    within(photoIn(parent), find.byType(RawImage)),
  );
  expect(raw.image, isNotNull);
  final data = await tester.runAsync(
    () => raw.image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  expect(data, isNotNull);
  for (var channel = 0; channel < 3; channel++) {
    expect(data!.getUint8(channel), closeTo(cardColors[path]![channel], 5));
  }
}

Future<CardFixture> openCards(
  WidgetTester tester, {
  CardPhotoCommunity? repository,
  bool support = true,
  bool reduced = false,
  Size size = const Size(377, 852),
  double textScale = 1,
  MeasurementController? measurement,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  for (final family in ['Inter', 'Fraunces']) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
    await tester.runAsync(loader.load);
  }
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  addTearDown(identity.changes.close);
  final repo = repository ?? CardPhotoCommunity();
  repo.post = Adoption({
    ...repo.post.data,
    'photos': ['adoption/luna.jpg'],
  });
  repo.discoveryItems = [
    repo.post,
    Adoption({
      ...repo.post.data,
      'id': 'second',
      'pet_name': 'Milo',
      'story': 'Historia verde de Milo.',
      'photos': ['adoption/milo.jpg'],
    }),
    Adoption({
      ...repo.post.data,
      'id': 'third',
      'pet_name': 'Nube',
      'story': 'Historia amarilla de Nube.',
      'photos': ['adoption/nube.jpg'],
    }),
  ];
  if (support) {
    repo.supportItems = [
      SupportOpportunity({
        'case_id': 'case-one',
        'expense_id': 'expense-one',
        'pet_name': 'Choco',
        'expense_title': 'Tratamiento azul de Choco.',
        'photo': 'rescue/choco.jpg',
        'reimbursable_cents': 10000,
        'funded_cents': 2500,
      }),
    ];
  }
  final rescue = CardPhotoRescue();
  final encoded = <String, Uint8List>{
    for (final entry in cardColors.entries)
      entry.key: Uint8List.fromList(
        img.encodeJpg(
          img.Image(width: 24, height: 32)..clear(
            img.ColorRgb8(entry.value[0], entry.value[1], entry.value[2]),
          ),
        ),
      ),
  };
  final runtime = (await tester.runAsync(
    () async => PhotoRuntime(
      store: MemoryPhotoStore(),
      download: (url, _) async => encoded[url.path.substring(1)]!,
    ),
  ))!;
  addTearDown(runtime.dispose);
  final frames = <String, PhotoFrame>{};
  final width = ((size.width / 128).ceil() * 128).clamp(128, 1600);
  // Real decoding runs outside Flutter's fake clock. The fixed JPEGs then let
  // individual animation frames be inspected without network or codec timing.
  await tester.runAsync(() async {
    for (final path in cardColors.keys) {
      frames[path] = await runtime.load(
        path.startsWith('rescue/')
            ? rescuePhotoSource(rescue, path)
            : adoptionPhotoSource(repo, path),
        width: width,
      );
    }
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        rescueRepositoryProvider.overrideWithValue(rescue),
        photoRuntimeProvider.overrideWithValue(runtime),
        if (measurement != null)
          measurementControllerProvider.overrideWith((ref) => measurement),
        routerInitialLocationProvider.overrideWithValue('/adoptions'),
      ],
      child: const DopmiApp(),
    ),
  );
  await tester.pumpAndSettle();
  return CardFixture(repo, rescue, runtime, frames);
}

void main() {
  testWidgets(
    'complete mixed cards keep photo text and provider identity on promotion',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final fixture = await openCards(tester);
      final downloads = fixture.runtime.metrics.downloads;
      final signatures = fixture.runtime.metrics.signatures;
      final sequence = [
        ('post', 'Luna', 'adoption/luna.jpg', 'Una historia por conocer.'),
        ('second', 'Milo', 'adoption/milo.jpg', 'Historia verde de Milo.'),
        (
          'support-expense-one',
          'Choco',
          'rescue/choco.jpg',
          'Tratamiento azul de Choco.',
        ),
        ('third', 'Nube', 'adoption/nube.jpg', 'Historia amarilla de Nube.'),
      ];
      for (var i = 0; i < sequence.length - 1; i++) {
        final current = sequence[i];
        final next = sequence[i + 1];
        final outgoing = card(current.$1);
        final incoming = card(next.$1);
        expect(find.byType(DiscoveryCardMotion), findsNWidgets(2));
        expect(within(incoming, find.text(next.$2)), findsOneWidget);
        expect(within(incoming, find.text(next.$4)), findsOneWidget);
        expect(find.text(next.$2).hitTestable(), findsNothing);
        expect(find.bySemanticsLabel(next.$2), findsNothing);
        await assertDecodedColor(tester, incoming, next.$3);
        final nextState = tester.state(photoIn(incoming));
        final provider = renderedProvider(tester, incoming);
        expect(provider, same(fixture.frames[next.$3]!.provider));
        if (current.$1.startsWith('support-')) {
          // Support cards expose swipe and an accessibility action, rather
          // than the adoption card's three footer buttons.
          final gesture = await tester.startGesture(tester.getCenter(outgoing));
          await gesture.moveBy(const Offset(-160, 0));
          await tester.pump();
          await gesture.up();
        } else {
          await tester.tap(frontAction('Pasar'));
        }
        await tester.pump();
        for (final step in [70, 70, 70]) {
          await tester.pump(Duration(milliseconds: step));
          expect(within(outgoing, find.text(current.$2)), findsOneWidget);
          expect(within(outgoing, find.text(current.$4)), findsOneWidget);
          expect(within(incoming, find.text(next.$2)), findsOneWidget);
          expect(within(incoming, find.text(next.$4)), findsOneWidget);
          expect(renderedMotion(tester, incoming).transform.storage[12], 0);
          expect(
            renderedProvider(tester, outgoing),
            same(fixture.frames[current.$3]!.provider),
          );
          expect(renderedProvider(tester, incoming), same(provider));
        }
        await tester.pump(const Duration(milliseconds: 70));
        // AnimationController reports completion on the next timestamp after
        // 280ms; this extra millisecond represents that next vsync.
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(outgoing, findsNothing);
        expect(find.text(next.$2).hitTestable(), findsOneWidget);
        expect(tester.state(photoIn(incoming)), same(nextState));
        expect(renderedProvider(tester, incoming), same(provider));
        expect(renderedMotion(tester, incoming).transform.storage[12], 0);
        await assertDecodedColor(tester, incoming, next.$3);
        expect(fixture.runtime.metrics.downloads, downloads);
        expect(fixture.runtime.metrics.signatures, signatures);
      }
      semantics.dispose();
      expect(find.byType(DiscoveryCardMotion), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in [-1, 1]) {
    testWidgets('long drag exits monotonically fully outside: $direction', (
      tester,
    ) async {
      await openCards(tester, size: const Size(1000, 1000), support: false);
      final outgoing = card('post');
      final pointer = await tester.startGesture(tester.getCenter(outgoing));
      await pointer.moveBy(Offset(direction * 600, 0));
      await tester.pump();
      var previous =
          direction * renderedMotion(tester, outgoing).transform.storage[12];
      expect(previous, closeTo(600, .001));
      await pointer.up();
      await tester.pump();
      expect(
        direction * tester.widget<DiscoveryCardMotion>(outgoing).translation,
        greaterThan(600),
      );
      for (final step in [70, 70, 70, 69]) {
        await tester.pump(Duration(milliseconds: step));
        final current =
            direction * renderedMotion(tester, outgoing).transform.storage[12];
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
      final body = tester.widget<DiscoveryCardMotion>(outgoing).child;
      final box = tester.renderObject<RenderBox>(find.byWidget(body));
      final points = [
        Offset.zero,
        Offset(box.size.width, 0),
        Offset(0, box.size.height),
        Offset(box.size.width, box.size.height),
      ].map(box.localToGlobal).toList();
      if (direction < 0) {
        expect(points.map((p) => p.dx).reduce(math.max), lessThan(0));
      } else {
        expect(points.map((p) => p.dx).reduce(math.min), greaterThan(1000));
      }
      await tester.pumpAndSettle();
      expect(card('post'), findsNothing);
      expect(find.text('Milo').hitTestable(), findsOneWidget);
      expect(renderedMotion(tester, card('second')).transform.storage[12], 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('slow pagination does not disable the promoted card', (
    tester,
  ) async {
    final repo = PendingPageCommunity();
    await openCards(tester, repository: repo, support: false);
    await tester.tap(frontAction('Pasar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repo.requestedPages, [1, 2]);
    expect(find.text('Milo').hitTestable(), findsOneWidget);
    await tester.tap(frontAction('Pasar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Nube').hitTestable(), findsOneWidget);
    repo.nextPage.complete(
      DataPage([
        Adoption({
          ...repo.post.data,
          'id': 'fourth',
          'pet_name': 'Sol',
          'photos': <String>[],
        }),
      ], 4),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nube').hitTestable(), findsOneWidget);
    expect(renderedMotion(tester, card('third')).transform.storage[12], 0);
    expect(repo.requestedPages, [1, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('complete preview reflows at large text and reduced motion', (
    tester,
  ) async {
    await openCards(
      tester,
      reduced: true,
      size: const Size(320, 640),
      textScale: 2,
    );
    await tester.ensureVisible(within(card('post'), find.byTooltip('Pasar')));
    await tester.pump();
    await tester.tap(frontAction('Pasar'));
    await tester.pump();
    await tester.pump();
    expect(card('post'), findsNothing);
    expect(card('second'), findsOneWidget);
    expect(renderedMotion(tester, card('second')).transform.storage[12], 0);
    expect(
      within(card('support-expense-one'), find.text('Choco')),
      findsOneWidget,
    );
    expect(
      within(
        card('support-expense-one'),
        find.text('Apoya con sus necesidades'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(within(card('second'), find.byTooltip('Pasar')));
    await tester.pump();
    await tester.tap(frontAction('Pasar'));
    await tester.pump();
    await tester.pump();
    expect(card('second'), findsNothing);
    expect(card('support-expense-one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
