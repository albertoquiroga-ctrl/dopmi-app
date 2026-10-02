import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final settings in [false, true]) {
    testWidgets(
      'mode control focuses its track and keeps the full touch target: $settings',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RescuerDonorModeCard(
                enabled: true,
                settings: settings,
                onPressed: () => calls++,
              ),
            ),
          ),
        );
        final track = find.byKey(const ValueKey('rescuer-donor-switch'));
        final target = find.ancestor(of: track, matching: find.byType(InkWell));
        expect(tester.getSize(target), const Size(48, 48));
        await tester.tap(
          find.text(settings ? 'Cambiar a usuario donante' : 'Modo donante'),
        );
        expect(calls, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final outline = find.byKey(
          const ValueKey('reference-keyboard-outline'),
        );
        expect(outline, findsOneWidget);
        expect(tester.getSize(outline), const Size(42, 29));
        expect(
          (tester.getCenter(outline) - tester.getCenter(track)).distance,
          lessThan(.01),
        );
        expect(calls, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(calls, 1);
        await tester.tapAt(tester.getTopLeft(target) + const Offset(2, 2));
        await tester.pump();
        expect(calls, 2);
        expect(outline, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final reduced in [false, true]) {
    testWidgets('mode thumb follows 180ms ease and reduced motion: $reduced', (
      tester,
    ) async {
      Widget card(bool settings) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: RescuerDonorModeCard(
              enabled: true,
              settings: settings,
              onPressed: () {},
            ),
          ),
        ),
      );
      double x() => tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(AnimatedContainer),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .entry(0, 3);
      await tester.pumpWidget(card(false));
      expect(x(), 0);
      await tester.pumpWidget(card(true));
      if (reduced) {
        expect(x(), 13);
      } else {
        expect(x(), 0);
        await tester.pump(const Duration(milliseconds: 90));
        expect(x(), closeTo(13 * Curves.ease.transform(.5), .01));
        await tester.pump(const Duration(milliseconds: 90));
        expect(x(), 13);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
