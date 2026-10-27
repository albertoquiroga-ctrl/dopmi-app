import 'package:dopmi_mobile/features/payments/guardian_membership_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (scale, billing) in [
    (1.0, false),
    (2.0, false),
    (1.0, true),
    (2.0, true),
  ]) {
    testWidgets(
      'Membership evidence stays legible at scale $scale (billing $billing) without a fictitious card or date',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: GuardianMembershipCard(
                    status: 'active',
                    cents: 7525,
                    billing: billing,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Suscripción activa'), findsOneWidget);
        expect(find.text(r'$75.25'), findsOneWidget);
        expect(find.text('Por confirmar'), findsOneWidget);
        expect(find.text('Guardián'), billing ? findsNothing : findsOneWidget);
        expect(find.text('En Stripe'), billing ? findsNothing : findsOneWidget);
        expect(find.textContaining('4242'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Cancellation never advertises another charge even with a stale billing date',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuardianMembershipCard(
              status: 'cancel_requested',
              cents: 5000,
              nextBilling: '2026-10-24T12:00:00Z',
            ),
          ),
        ),
      );
      expect(find.text('Cancelación solicitada'), findsOneWidget);
      expect(find.text('Suscripción activa'), findsNothing);
      expect(find.text('Próximo cobro'), findsNothing);
    },
  );
}
