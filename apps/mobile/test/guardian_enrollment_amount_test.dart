import 'package:dopmi_mobile/features/payments/guardian_enrollment_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Decorative preset replay preserves amount and respects reduced motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(377, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final amount = TextEditingController(text: '50.00');
      addTearDown(amount.dispose);
      var changes = 0;
      Widget screen(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(377, 1000),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: GuardianEnrollmentAmount(
                amount: amount,
                locked: false,
                decorate: true,
                onChanged: () => changes++,
              ),
            ),
          ),
        ),
      );
      double opacity() => tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('guardian-bubble-0')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      await tester.pumpWidget(screen(false));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      final fifty = tester.getRect(find.text(r'$50'));
      final twoHundred = tester.getRect(find.text(r'$200'));
      expect(twoHundred.top, greaterThan(fifty.bottom));
      await tester.tap(find.text(r'$200'));
      await tester.pump();
      expect(opacity(), 0);
      expect(amount.text, '200.00');
      expect(changes, 1);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await tester.pumpWidget(screen(true));
      await tester.tap(find.text(r'$200'));
      await tester.pump();
      expect(opacity(), 1);
      expect(tester.binding.hasScheduledFrame, false);
      expect(amount.text, '200.00');
      expect(changes, 2);
      expect(tester.takeException(), isNull);
    },
  );
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
        final preset = tester.widget<InkWell>(
          find.ancestor(of: find.text(r'$200'), matching: find.byType(InkWell)),
        );
        expect(preset.splashFactory, NoSplash.splashFactory);
        expect(preset.highlightColor, Colors.transparent);
        expect(amount.text, '200.00');
        expect(find.text(r'$200.00 MXN'), findsNWidgets(2));
        await tester.ensureVisible(find.text('Otra cantidad'));
        await tester.tap(find.text('Otra cantidad'));
        await tester.pump();
        await tester.ensureVisible(find.byType(TextField));
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          true,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Importe mensual en MXN',
          ),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), '75.25');
        await tester.pump();
        expect(find.text(r'$75.25 MXN'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), '19.99');
        await tester.pump();
        expect(find.text('Importe por confirmar'), findsNWidgets(2));
        expect(find.text(r'$0 MXN'), findsNothing);
        await tester.enterText(find.byType(TextField), '20.00');
        await tester.pump();
        expect(find.text(r'$20.00 MXN'), findsNWidgets(2));
        expect(find.text('Importe por confirmar'), findsNothing);
        await tester.ensureVisible(find.text(r'$500'));
        await tester.tap(find.text(r'$500'));
        await tester.pump();
        expect(amount.text, '500.00');
        expect(find.byType(TextField), findsNothing);
        expect(find.text(r'$500.00 MXN'), findsNWidgets(2));
        await tester.ensureVisible(find.text('Otra cantidad'));
        await tester.tap(find.text('Otra cantidad'));
        await tester.pump();
        await tester.ensureVisible(find.text('Volver a cantidades sugeridas'));
        await tester.tap(find.text('Volver a cantidades sugeridas'));
        await tester.pump();
        expect(amount.text, '50.00');
        expect(find.byType(TextField), findsNothing);
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
