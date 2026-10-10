import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rescuer_home_screen_test.dart' show pumpHome;
import 'rescuer_home_9ced_test.dart' show PeriodHomeRescue;

void main() {
  testWidgets('period retains radio keyboard selection', (tester) async {
    final rescue = PeriodHomeRescue();
    await pumpHome(tester, rescue);
    await tester.tap(find.byKey(const ValueKey('home-period-filter')));
    await tester.pumpAndSettle();
    final selectedRadio = find.byWidgetPredicate(
      (widget) => widget is Radio<String> && widget.value == 'month',
    );
    final input = find
        .descendant(
          of: selectedRadio,
          matching: find.byType(RawGestureDetector),
        )
        .first;
    Focus.of(tester.element(input)).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(rescue.periods, ['month', 'week']);
  });
}
