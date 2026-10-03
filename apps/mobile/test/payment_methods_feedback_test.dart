import 'package:dopmi_mobile/features/payments/payment_methods_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'feedback is immediate, overlays without overflow and expires at 2600ms: large=$large',
      (tester) async {
        tester.view.physicalSize = large
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var shown = true, finished = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: large ? const Size(320, 640) : const Size(377, 852),
                textScaler: TextScaler.linear(large ? 2 : 1),
              ),
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: Stack(
                    children: [
                      if (shown)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: PaymentMethodsFeedback(
                            message: 'Método predeterminado actualizado',
                            onDone: () => setState(() {
                              shown = false;
                              finished++;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byType(PaymentMethodsFeedback));
        expect(rect.left, 16);
        expect(rect.right, (large ? 320 : 377) - 16);
        expect(rect.bottom, (large ? 640 : 852) - 24);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(find.text('Método predeterminado actualizado'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2599));
        expect(finished, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(finished, 1);
        expect(find.byType(PaymentMethodsFeedback), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('unmount cancels pending private result announcement', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentMethodsFeedback(
          message: 'Tarjeta eliminada.',
          visible: false,
          onDone: () => finished++,
        ),
      ),
    );
    expect(find.text('Tarjeta eliminada.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(finished, 0);
  });
}
