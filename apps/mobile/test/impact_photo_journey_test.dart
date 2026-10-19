import 'dart:typed_data';

import 'package:dopmi_mobile/features/profile/impact_photo_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final pixels = img.Image(width: 12, height: 12);
  for (var y = 0; y < 12; y++) {
    for (var x = 0; x < 12; x++) {
      pixels.setPixelRgba(x, y, x * 20, y * 20, 100, 255);
    }
  }
  final bytes = Uint8List.fromList(img.encodePng(pixels));
  const primary = ImpactPhoto('case-one', 'Luna', 'public-one.jpg');
  const secondary = ImpactPhoto('case-two', 'Milo', 'public-two.jpg');

  Future<void> start(
    WidgetTester tester,
    ScrollController controller, {
    bool reduced = false,
    bool destination = true,
    bool noPhotos = false,
    double scale = 1,
    double width = 377,
    bool longNames = false,
    ValueChanged<ImpactPhoto>? onOpenStory,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 160),
                  ImpactPhotoJourney(
                    onOpenStory: onOpenStory,
                    photos: noPhotos
                        ? []
                        : [
                            if (destination)
                              (longNames
                                  ? const ImpactPhoto(
                                      'case-one',
                                      'Luna y sus compañeritos esperan una nueva oportunidad juntos',
                                      'public-one.jpg',
                                    )
                                  : primary),
                            secondary,
                          ],
                    hero: noPhotos
                        ? null
                        : (longNames
                              ? const ImpactPhoto(
                                  'case-one',
                                  'Luna y sus compañeritos esperan una nueva oportunidad juntos',
                                  'public-one.jpg',
                                )
                              : primary),
                    photoBuilder: (photo, height) => Image.memory(
                      bytes,
                      height: height,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                  const SizedBox(height: 1000),
                  const Text(
                    'Fin real del contenido',
                    key: ValueKey('journey-end'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'impact ring opens its own public story rather than navigating to detail',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      ImpactPhoto? opened;
      await start(tester, controller, onOpenStory: (photo) => opened = photo);
      await tester.ensureVisible(
        find.byKey(const ValueKey('impact-ring-case-one')),
      );
      await tester.tap(find.byKey(const ValueKey('impact-ring-case-one')));
      await tester.pump();
      expect(opened?.caseId, 'case-one');
      expect(opened?.path, 'public-one.jpg');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scroll interpolates the same confirmed photo into its own ring and reverses',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await start(tester, controller);
      final hero = find.byKey(const ValueKey('impact-hero-case-one'));
      final heroStart = tester.getRect(hero).deflate(6);
      final ring = find.byKey(const ValueKey('impact-ring-case-one'));
      final ringImage = find.descendant(
        of: ring,
        matching: find.byType(ClipOval),
      );
      final ringStart = tester.getRect(ringImage);
      final gap = heroStart.center.dy - ringStart.center.dy;
      double ringOpacity() => tester
          .widget<Opacity>(
            find.byKey(const ValueKey('impact-ring-opacity-case-one')),
          )
          .opacity;
      expect(find.byKey(const ValueKey('impact-photo-flight')), findsNothing);
      expect(ringOpacity(), 1);
      controller.jumpTo(160 + gap / 2);
      await tester.pump();
      final flight = find.byKey(const ValueKey('impact-photo-flight'));
      expect(flight, findsOneWidget);
      expect(ringOpacity(), 0);
      final expected = Rect.lerp(
        heroStart.shift(Offset(0, -160 - gap / 2)),
        ringStart.shift(const Offset(0, -160)),
        .5,
      )!;
      final current = tester.getRect(flight);
      expect(current.left, closeTo(expected.left, .01));
      expect(current.top, closeTo(expected.top, .01));
      expect(current.width, closeTo(expected.width, .01));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('impact-hero-opacity')))
            .opacity,
        closeTo(.5, .001),
      );
      final flyingImage = tester.widget<Image>(
        find.descendant(of: flight, matching: find.byType(Image)),
      );
      expect((flyingImage.image as MemoryImage).bytes, same(bytes));
      controller.jumpTo(160 + gap * .91);
      await tester.pump();
      expect(ringOpacity(), closeTo(.5, .001));
      controller.jumpTo(160 + gap);
      await tester.pump();
      expect(flight, findsNothing);
      expect(ringOpacity(), 1);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('impact-hero-opacity')))
            .opacity,
        0,
      );
      controller.jumpTo(160 + gap / 4);
      await tester.pump();
      expect(flight, findsOneWidget);
      expect(ringOpacity(), 0);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('impact-hero-opacity')))
            .opacity,
        closeTo(.75, .001),
      );
      controller.jumpTo(0);
      await tester.pump();
      expect(flight, findsNothing);
      expect(ringOpacity(), 1);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('impact-hero-opacity')))
            .opacity,
        1,
      );
      final scroll = await tester.startGesture(tester.getCenter(hero));
      await scroll.moveBy(const Offset(0, -240));
      await tester.pump();
      await scroll.cancel();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('impact-ring-case-one')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('impact-ring-case-two')),
        findsOneWidget,
      );
      controller.jumpTo(0);
      await tester.pump();
      expect(flight, findsNothing);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('impact-hero-opacity')))
            .opacity,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'missing destination or reduced motion keeps photos static: reduced=$reduced',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await start(tester, controller, destination: reduced, reduced: reduced);
        controller.jumpTo(260);
        await tester.pump();
        expect(find.byKey(const ValueKey('impact-photo-flight')), findsNothing);
        expect(
          tester
              .widget<Opacity>(
                find.byKey(const ValueKey('impact-hero-opacity')),
              )
              .opacity,
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('no assigned public photo produces neither ring nor flight', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await start(tester, controller, noPhotos: true);
    controller.jumpTo(260);
    await tester.pump();
    expect(find.byKey(const ValueKey('impact-ring-case-one')), findsNothing);
    expect(find.byKey(const ValueKey('impact-photo-flight')), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px at 200% reserves long labels and reaches actual content end without overflow',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await start(tester, controller, width: 320, scale: 2, longNames: true);
      expect(tester.takeException(), isNull);
      final hero = find.byKey(const ValueKey('impact-hero-case-one'));
      final ring = find.byKey(const ValueKey('impact-ring-case-one'));
      final heroName = find.byKey(const ValueKey('impact-collage-name'));
      final journey = find.byType(ImpactPhotoJourney);
      expect(
        tester.getRect(journey).bottom,
        greaterThanOrEqualTo(tester.getRect(heroName).bottom),
      );
      expect(
        tester.getRect(hero).top,
        greaterThan(tester.getRect(ring).bottom),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('journey-end')).hitTestable(),
        findsOneWidget,
      );
      final end = tester.getRect(find.byKey(const ValueKey('journey-end')));
      expect(end.bottom, lessThanOrEqualTo(700));
      expect(tester.takeException(), isNull);
    },
  );
}
