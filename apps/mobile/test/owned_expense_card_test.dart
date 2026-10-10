import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/rescue/owned_expense_card.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'payments_test.dart' show FakePayments;

class ExpenseFundingFixture extends FakePayments {
  bool fundingFails = false;
  int fundingCalls = 0, funded = 7500;
  @override
  Future<Json> funding(String expense) async {
    fundingCalls++;
    if (fundingFails) {
      throw const FormatException('No se pudo consultar la asignación.');
    }
    return {
      'reimbursable_cents': 10000,
      'funded_cents': funded,
      'transferred_cents': 2500,
    };
  }
}

RescueRecord expense(String status) => RescueRecord({
  'id': 'expense-one', 'kind': 'expense', 'status': status,
  'public_data': {
    'title': 'Medicamentos para recuperación',
    'category': 'medicine',
  },
  // Deliberately wrong legacy client fields must never become funding truth.
  'funded_cents': 99999, 'target_cents': 99999,
});

void main() {
  testWidgets('funding error retries and a reversal replaces server amounts', (
    tester,
  ) async {
    final payments = ExpenseFundingFixture()..fundingFails = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(payments),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OwnedExpenseCard(expense('approved'), refresh: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo consultar la asignación.'), findsOneWidget);
    expect(find.textContaining('restantes'), findsNothing);
    payments.fundingFails = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Neto asignado: \$75.00'), findsOneWidget);
    expect(
      find.textContaining('Transferido a Stripe: \$25.00'),
      findsOneWidget,
    );
    payments.funded = 2500;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Neto asignado: \$25.00'), findsOneWidget);
    expect(find.textContaining('Neto asignado: \$75.00'), findsNothing);
    expect(payments.fundingCalls, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'draft has real status and action without fabricated funding at 200%',
    (tester) async {
      final payments = ExpenseFundingFixture();
      tester.view.physicalSize = const Size(640, 1704);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [paymentRepositoryProvider.overrideWithValue(payments)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: OwnedExpenseCard(expense('draft'), refresh: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Borrador'), findsOneWidget);
      expect(find.text('Continuar gasto'), findsOneWidget);
      expect(find.textContaining('restantes'), findsNothing);
      expect(payments.fundingCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('approved expense action remains usable at 320px and 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1704);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: OwnedExpenseSummary(
              expense('approved'),
              funding: const {
                'reimbursable_cents': 10000,
                'funded_cents': 7500,
                'transferred_cents': 2500,
              },
              onOpen: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Consultar gasto y comprobantes'));
    await tester.tap(find.text('Consultar gasto y comprobantes'));
    expect(opened, isTrue);
    expect(find.textContaining('Neto asignado: \$75.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
