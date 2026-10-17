import 'package:dopmi_mobile/features/payments/case_allocation_list.dart';
import 'package:dopmi_mobile/features/payments/payment_success_details.dart';
import 'package:dopmi_mobile/features/payments/guardian_payment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  for (final reserved in [0, 900]) {
    testWidgets(
      'zero allocation with reserve $reserved never claims a confirmed distribution',
      (tester) async {
        await show(
          tester,
          CaseAllocationList(
            allocations: [
              {
                'title': 'Privado',
                'allocated_cents': 0,
                'reserved_cents': reserved,
                'reversed_cents': 0,
              },
            ],
          ),
        );
        expect(find.text('Distribución confirmada en el caso'), findsNothing);
        expect(
          find.text('Este pago aún no tiene asignaciones confirmadas.'),
          findsOneWidget,
        );
        expect(find.text('Privado'), findsNothing);
      },
    );
  }
  testWidgets('fully reversed confirmed allocation preserves its history', (
    tester,
  ) async {
    await show(
      tester,
      const CaseAllocationList(
        allocations: [
          {
            'title': 'Gasto aprobado',
            'allocated_cents': 900,
            'reversed_cents': 900,
            'remaining_cents': 0,
          },
        ],
      ),
    );
    expect(find.text('Distribución confirmada en el caso'), findsOneWidget);
    expect(find.textContaining('Revertido:'), findsOneWidget);
    expect(find.textContaining('Neto vigente:'), findsOneWidget);
  });
  testWidgets('success uses authoritative confirmation date before creation', (
    tester,
  ) async {
    await show(
      tester,
      const PaymentSuccessDetails(
        value: {
          'processed_at': '2026-10-16T12:00:00Z',
          'created_at': '2026-10-15T12:00:00Z',
          'gross_cents': 10000,
        },
        caseName: 'Luna',
      ),
    );
    expect(find.text('Fecha de confirmación'), findsOneWidget);
    expect(find.text('16/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsNothing);
    expect(find.text('Foto pública no disponible.'), findsOneWidget);
  });
  testWidgets(
    'creation fallback is explicitly labeled and missing date stays honest',
    (tester) async {
      await show(
        tester,
        const PaymentSuccessDetails(
          value: {'created_at': '2026-10-15T12:00:00Z'},
        ),
      );
      expect(find.text('Fecha de creación'), findsOneWidget);
      expect(find.text('15/10/2026'), findsOneWidget);
      await show(tester, const PaymentSuccessDetails(value: {}));
      expect(find.text('Fecha no disponible'), findsOneWidget);
      expect(find.text('Monto no disponible'), findsOneWidget);
    },
  );
  test('native current method and Stripe default remain distinct', () {
    final card = GuardianPaymentCard.fromJson({
      'id': 'pm_test',
      'brand': 'visa',
      'last4': '4242',
      'default': false,
      'guardian_current': true,
      'exp_month': 3,
      'exp_year': 2030,
    });
    expect(card.guardianCurrent, isTrue);
    expect(card.isDefault, isFalse);
    expect(card.expiryLabel, '03/2030');
  });
  testWidgets(
    'current Guardian card is labeled and removal disabled independently of default',
    (tester) async {
      var removed = false;
      await show(
        tester,
        GuardianPaymentCardRow(
          card: const GuardianPaymentCard(
            id: 'pm_test',
            brand: 'visa',
            last4: '4242',
            isDefault: false,
            guardianCurrent: true,
          ),
          showRemove: true,
          onRemove: () => removed = true,
        ),
      );
      expect(find.text('En uso por Guardián'), findsOneWidget);
      expect(find.text('Predeterminada'), findsNothing);
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
      expect(removed, isFalse);
    },
  );
  for (final scale in [1.15, 2.0]) {
    testWidgets(
      'card actions fit below metadata at narrow width and scale $scale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 288,
                    child: GuardianPaymentCardRow(
                      card: const GuardianPaymentCard(
                        id: 'pm_test',
                        brand: 'visa',
                        last4: '1111',
                        isDefault: false,
                        guardianCurrent: true,
                      ),
                      showMakeDefault: true,
                      showRemove: true,
                      onMakeDefault: () {},
                      onRemove: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final action = tester.getRect(find.text('Hacer predeterminada'));
        final metadata = tester.getRect(find.text('En uso por Guardián'));
        expect(action.top, greaterThan(metadata.bottom));
        expect(
          tester.widget<Text>(find.text('Hacer predeterminada')).softWrap,
          isFalse,
        );
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
