import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  testWidgets(
    'edit keeps a 44px visible pill and a 48px target with keyboard focus',
    (tester) async {
      var edits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RescuerIdentityCard(
                name: 'Ana',
                city: 'Monterrey',
                status: 'approved',
                onEdit: () => edits++,
              ),
            ),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('rescuer-profile-edit'));
      expect(tester.getSize(button).height, 48);
      final pill = find.descendant(of: button, matching: find.byType(Material));
      expect(tester.getSize(pill).height, 44);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final outline = find.byKey(const ValueKey('reference-keyboard-outline'));
      expect(outline, findsOneWidget);
      expect(tester.getSize(outline).height, 54);
      expect(edits, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(edits, 1);
      await tester.tapAt(tester.getTopLeft(button) + const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(edits, 2);
      expect(outline, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final status in ['submitted', 'changes_requested', 'approved']) {
    testWidgets(
      'rescuer identity reflows and allows the public editor independently of identity review status: $status',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1280);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var edits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RescuerIdentityCard(
                    name: 'Rescatista con nombre extenso',
                    city: 'Monterrey, Nuevo León',
                    status: status,
                    onEdit: () => edits++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Rescatista con nombre extenso'), findsOneWidget);
        final name = tester.renderObject<RenderParagraph>(
          find.text('Rescatista con nombre extenso'),
        );
        expect(
          name.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 10),
          ),
          hasLength(1),
          reason: 'Rescatista must remain a complete word at 200 percent',
        );
        expect(
          find.text('Verificado'),
          findsNothing,
          reason: 'Approval is shown by the separate verification card; the standalone hero has no duplicate status pill.',
        );
        expect(
          tester
              .widget<RescuerIdentityCard>(find.byType(RescuerIdentityCard))
              .status,
          status,
        );
        expect(find.text('Editar'), findsOneWidget);
        await tester.ensureVisible(find.text('Editar'));
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        expect(edits, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final reduced in [false, true]) {
    testWidgets(
      'rescuer edit press matches source and cancel does not navigate: $reduced',
      (tester) async {
        var edits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: RescuerIdentityCard(
                  name: 'Ana',
                  city: 'Monterrey',
                  status: 'approved',
                  onEdit: () => edits++,
                ),
              ),
            ),
          ),
        );
        final button = find.byKey(const ValueKey('rescuer-profile-edit'));
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final renderedScale = tester.widget<ScaleTransition>(
          find.descendant(
            of: find.byType(AnimatedScale),
            matching: find.byType(ScaleTransition),
          ),
        );
        expect(
          renderedScale.scale.value,
          closeTo(reduced ? .97 : 1 - .03 * Curves.ease.transform(.5), .0001),
        );
        await tester.pump(const Duration(milliseconds: 150));
        final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        expect(scale.scale, .97);
        expect(
          scale.duration,
          reduced ? Duration.zero : const Duration(milliseconds: 120),
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(edits, 0);
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(edits, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
