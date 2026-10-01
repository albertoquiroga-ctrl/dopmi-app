import 'package:dopmi_mobile/features/payments/guardian_enrollment_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Custom amount focus and preset return at scale $scale', (
      tester,
    ) async {
      final amount = TextEditingController(text: '50.00');
      addTearDown(amount.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: GuardianEnrollmentAmount(
                  amount: amount,
                  locked: false,
                  onChanged: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Otra cantidad'));
      await tester.tap(find.text('Otra cantidad'));
      await tester.pumpAndSettle();
      final focus = tester.widget<TextField>(find.byType(TextField)).focusNode!;
      expect(focus.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), '75.25');
      await tester.pump();
      expect(amount.text, '75.25');
      await tester.ensureVisible(find.text('Volver a cantidades sugeridas'));
      await tester.tap(find.text('Volver a cantidades sugeridas'));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(find.byType(TextField), findsNothing);
      expect(amount.text, '50.00');
      expect(tester.takeException(), isNull);
    });
  }
}
