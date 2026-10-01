import 'package:dopmi_mobile/features/payments/guardian_promotion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final setting in [
    (1.0, false),
    (2.0, false),
    (1.0, true),
    (2.0, true),
  ]) {
    final (scale, reduced) = setting;
    testWidgets(
      'Guardian carousel swipes and dots remain usable at scale $scale, reduced motion $reduced',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced,
              ),
              child: const GuardianPromotionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(PageView));
        final visible = tester
            .getRect(find.byType(PageView))
            .intersect(const Rect.fromLTWH(0, 0, 320, 640));
        await tester.dragFrom(visible.center, const Offset(-280, 0));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          closeTo(1, .01),
        );
        final third = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Ir a la página 3 de 3',
        );
        await tester.ensureVisible(third);
        final dot = tester.widget<InkWell>(
          find.descendant(of: third, matching: find.byType(InkWell)),
        );
        expect(dot.splashFactory, NoSplash.splashFactory);
        expect(dot.highlightColor, Colors.transparent);
        await tester.tap(third);
        await tester.pump();
        final pages = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        if (reduced) {
          expect(pages.page, 2);
        } else {
          await tester.pump(const Duration(milliseconds: 100));
          expect(pages.page, greaterThan(1));
          expect(pages.page, lessThan(2));
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          closeTo(2, .01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
