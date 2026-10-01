import 'package:dopmi_mobile/features/payments/guardian_enrollment_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Enrollment presets and personalized cents remain accurate at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final amount = TextEditingController(text: '50.00');
        addTearDown(amount.dispose);
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
        await tester.ensureVisible(find.text(r'$200'));
        await tester.tap(find.text(r'$200'));
        await tester.pump();
        expect(amount.text, '200.00');
        expect(find.text(r'$200.00 MXN'), findsNWidgets(2));
        await tester.ensureVisible(find.text('Otra cantidad'));
        await tester.tap(find.text('Otra cantidad'));
        await tester.pump();
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '75.25');
        await tester.pump();
        expect(find.text(r'$75.25 MXN'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), '49.99');
        await tester.pump();
        expect(find.text('Importe por confirmar'), findsNWidgets(2));
        expect(find.text(r'$0 MXN'), findsNothing);
      },
    );
  }
  testWidgets(
    'Restored attempt amount is visible and cannot be changed through a preset',
    (tester) async {
      final amount = TextEditingController(text: '10.00');
      addTearDown(amount.dispose);
      bool changed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardianEnrollmentAmount(
                amount: amount,
                locked: true,
                onChanged: () => changed = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(r'$200'));
      await tester.pump();
      expect(amount.text, '10.00');
      expect(find.text(r'$10.00 MXN'), findsNWidgets(2));
      expect(changed, false);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    },
  );
}
