import 'dart:io';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:dopmi_mobile/features/rescue/urgency_complement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/rescue_video_urgency_test.dart'
    show UrgencyVideoRepository, urgencyRecord;
import 'capture_design_test.dart' show saveCapture;

// Production widgets with an isolated eligible policy, no selected media or API.
// These images demonstrate composition/reflow, not camera or Stream playback.
void main() {
  for (final variant in [
    ('urgency-heading', const Size(377, 852), 1.0),
    ('urgency-heading-samsung', const Size(377, 852), 1.15),
    ('urgency-heading-large', const Size(320, 640), 2.0),
  ]) {
    testWidgets('capture ${variant.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = variant.$2;
      tester.platformDispatcher.textScaleFactorTestValue = variant.$3;
      final previousDisableShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      try {
        for (final family in ['Inter', 'Fraunces']) {
          final loader = FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
          await tester.runAsync(loader.load);
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await tester.runAsync(icons.load);
        final output = Directory('../../.tools/design-review');
        await tester.runAsync(() => output.create(recursive: true));
        final repository = UrgencyVideoRepository();
        addTearDown(repository.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rescueVideosRepositoryProvider.overrideWithValue(repository),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dopmiTheme(rescuer: true),
                home: PublicationFrame(
                  title: 'Cuéntanos',
                  step: 1,
                  onBack: () {},
                  footer: PublicationFooter(
                    label: 'Continuar',
                    onContinue: () {},
                    onSave: () {},
                  ),
                  children: [
                    UrgencyComplement(
                      record: urgencyRecord(),
                      eligible: true,
                      photoPath: null,
                      onSave: () async {},
                      onPhoto: () async {},
                      onRemovePhoto: () async {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: find.byType(PublicationFrame),
          matching: find.byType(Scrollable),
        );
        Future<void> reveal(Finder finder) async {
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              100,
              scrollable: scrollable,
              maxScrolls: 15,
            );
          }
          await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget);
        }

        await reveal(find.text('Añadir video de urgencia'));
        await tester.tap(find.text('Añadir video de urgencia'));
        await tester.pumpAndSettle();
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => saveCapture(key, '${output.path}/${variant.$1}.png'),
        );
        await reveal(find.text('Elegir video'));
        expect(tester.takeException(), isNull);
        if (variant.$3 == 2) {
          await tester.runAsync(
            () => saveCapture(key, '${output.path}/${variant.$1}-actions.png'),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        debugDisableShadows = previousDisableShadows;
      }
    });
  }
}
