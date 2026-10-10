import 'package:dopmi_mobile/features/payments/payment_history_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Case action and financial detail have separate tap targets', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentHistoryRow(
            payment: const {
              'expense_title': 'Medicamentos',
              'gross_cents': 7525,
            },
            onOpenCase: () => opens++,
            details: const Text('Referencia real'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Medicamentos'));
    await tester.pump();
    expect(opens, 1);
    expect(find.text('Referencia real'), findsNothing);
    await tester.tap(find.text(r'$75.25'));
    await tester.pump();
    expect(opens, 1);
    expect(find.text('Referencia real'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Public case name and actual concept remain readable at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(377, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: PaymentHistoryRow(
                  caseName: 'Choco',
                  payment: {
                    'expense_title': 'Medicamentos',
                    'gross_cents': 7525,
                  },
                  details: SizedBox(),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Choco - Medicamentos'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('Actual amount and status remain readable at scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(377, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: PaymentHistoryRow(
                payment: const {
                  'id': 'actual-payment',
                  'created_at': '2026-10-01T12:00:00Z',
                  'expense_title': 'Medicamentos para Luna',
                  'gross_cents': 7525,
                  'processor': 'stripe',
                  'payment_status': 'refunded',
                },
                details: const Text('Referencia: actual-payment'),
              ),
            ),
          ),
        ),
      );
      expect(find.text(r'$75.25'), findsOneWidget);
      expect(find.text('Devuelto'), findsOneWidget);
      expect(find.text('Pagado'), findsNothing);
      expect(find.text('Referencia: actual-payment'), findsNothing);
      await tester.tap(find.text('Medicamentos para Luna'));
      await tester.pump();
      expect(find.text('Referencia: actual-payment'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Medicamentos para Luna'));
      await tester.pump();
      expect(find.text('Referencia: actual-payment'), findsNothing);
    });
  }
  testWidgets('Missing evidence does not invent an amount or payment method', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaymentHistoryRow(payment: {}, details: SizedBox()),
        ),
      ),
    );
    expect(find.text('Importe no disponible'), findsOneWidget);
    expect(find.text('Método no disponible'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Pagado'), findsNothing);
  });
}
