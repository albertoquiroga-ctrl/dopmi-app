import 'package:dopmi_mobile/core/reference_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('switch rendered motion and cancelled gesture: $reduced', (
      tester,
    ) async {
      var value = false;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => ReferenceSwitch(
                  value: value,
                  label: 'Recibidas',
                  onChanged: (next) {
                    calls++;
                    update(() => value = next);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final control = find.byType(ReferenceSwitch);
      final thumb = find
          .descendant(
            of: find.byType(AnimatedContainer),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final start = tester.getTopLeft(thumb).dx;
      expect(tester.getSize(control), const Size(48, 48));
      final gesture = await tester.startGesture(tester.getCenter(control));
      await tester.pump(const Duration(milliseconds: 90));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(tester.getTopLeft(thumb).dx, start);
      await tester.tap(control);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(calls, 1);
      expect(
        tester.getTopLeft(thumb).dx - start,
        closeTo(reduced ? 13 : 13 * Curves.ease.transform(.5), .02),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(thumb).dx - start, closeTo(13, .001));
      expect(tester.takeException(), isNull);
    });
  }
}
