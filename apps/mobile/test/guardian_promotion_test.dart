import 'package:dopmi_mobile/features/payments/guardian_promotion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Guardian carousel swipes and dots remain usable at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
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
        await tester.tap(third);
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
