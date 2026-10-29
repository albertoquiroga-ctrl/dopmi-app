import 'package:dopmi_mobile/features/payments/guardian_activation_failure.dart';
import 'package:dopmi_mobile/features/payments/guardian_activation_success.dart';
import 'package:dopmi_mobile/features/payments/guardian_enrollment_confirmation.dart';
import 'package:dopmi_mobile/features/payments/payment_environment.dart';
import 'package:dopmi_mobile/features/payments/payment_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final production in [false, true]) {
    testWidgets(
      'payment and Guardian notices describe ${production ? 'real' : 'TEST'} contributions',
      (tester) async {
        final mode = PaymentEnvironment(
          environment: production ? 'production' : 'test',
        );
        final surfaces = <Widget>[
          Scaffold(
            body: SingleChildScrollView(
              child: GuardianEnrollmentConfirmation(
                paymentEnvironment: mode,
                firstPaymentDate: '28/10/2026',
                nextBillingDate: '28/11/2026',
                consent: false,
                onConsentChanged: (_) {},
              ),
            ),
          ),
          GuardianActivationSuccess(
            paymentEnvironment: mode,
            cents: 5000,
            nextBilling: '2026-11-28T12:00:00Z',
            onReturn: () {},
          ),
          GuardianActivationFailure(
            paymentEnvironment: mode,
            cents: 5000,
            onReturn: () {},
            onRetry: () {},
          ),
          PaymentResultPage(
            paymentEnvironment: mode,
            value: const {'payment_status': 'pending', 'gross_cents': 5000},
            refresh: () {},
            back: () {},
          ),
        ];
        for (final surface in surfaces) {
          await tester.pumpWidget(MaterialApp(home: surface));
          await tester.pumpAndSettle();
          final copy = tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
              .join('\n');
          if (production) {
            expect(copy.toLowerCase(), isNot(contains('prueba')));
            expect(copy.toLowerCase(), contains('real'));
            expect(copy, isNot(contains('No uses datos de una tarjeta real')));
            expect(copy, isNot(contains('no se mueve dinero real')));
          } else {
            expect(copy.toLowerCase(), contains('prueba'));
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
