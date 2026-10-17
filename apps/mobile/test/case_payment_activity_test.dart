import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'payments_test.dart' show FakePayments;

class CaseHistoryPayments extends FakePayments {
  final donorReads = <String>[], receivedReads = <String>[];
  @override
  Future<List<Json>> caseAllocations(String id) async {
    donorReads.add(id);
    return [
      {
        'expense_id': 'expense-a',
        'title': 'Consulta',
        'allocated_cents': 6000,
        'reversed_cents': 0,
      },
      {
        'expense_id': 'expense-b',
        'title': 'Medicina',
        'allocated_cents': 3200,
        'reversed_cents': 0,
      },
    ];
  }

  @override
  Future<List<Json>> caseReceivedAllocations(String id) async {
    receivedReads.add(id);
    return [
      {
        'expense_id': 'expense-a',
        'title': 'Gasto aprobado',
        'allocated_cents': 6000,
        'reversed_cents': 6000,
        'remaining_cents': 0,
      },
      {
        'expense_id': 'expense-b',
        'title': 'Medicina',
        'allocated_cents': 3200,
        'reversed_cents': 0,
        'remaining_cents': 3200,
      },
    ];
  }
}

void main() {
  for (final received in [false, true]) {
    testWidgets(
      'case history keeps the private snapshot and uses the matching participant API; received=$received',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final payments = CaseHistoryPayments();
        addTearDown(identity.changes.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              paymentRepositoryProvider.overrideWithValue(payments),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PaymentActivityCard(
                    owner: 'one',
                    received: received,
                    item: {
                      'id': 'donation-one',
                      'kind': 'contribution',
                      'contribution_scope': 'case',
                      'title': 'Apoyo al caso',
                      'created_at': '2026-10-17T18:00:00Z',
                      'status': 'assigned',
                      'payment_status': 'confirmed',
                      'amount_cents': received ? 9200 : 10000,
                      'assigned_cents': 9200,
                      'allocation_count': 2,
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apoyo al caso'));
        await tester.pumpAndSettle();
        expect(find.text('Distribución confirmada en el caso'), findsOneWidget);
        expect(find.text('Medicina'), findsOneWidget);
        expect(find.textContaining('Reserva'), findsNothing);
        if (received) {
          expect(payments.receivedReads, ['donation-one']);
          expect(payments.donorReads, isEmpty);
          expect(find.text('Neto vigente: \$0 MXN'), findsOneWidget);
          expect(find.text('Gasto aprobado'), findsOneWidget);
        } else {
          expect(payments.donorReads, ['donation-one']);
          expect(payments.receivedReads, isEmpty);
          expect(find.text('Consulta'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
