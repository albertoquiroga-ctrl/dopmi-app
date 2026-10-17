import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_result_page.dart';
import 'package:dopmi_mobile/features/payments/oneoff_payment_sheet.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'payments_test.dart' show FakePayments, FakeOneoffSheet, tapButton;
import 'rescue_test.dart' show FakeRescue;

class CasePayments extends FakePayments {
  String status = 'pending', refund = 'not_started';
  int legacyCheckouts = 0;
  final caseLookups = <(String, String)>[];
  @override
  Future<Json> checkout(String expense, int cents, String key) async {
    legacyCheckouts++;
    throw StateError('A case must not use a historical expense checkout');
  }

  @override
  Future<Json> caseCheckout(String caseId, int cents, String key) async {
    calls.add(key);
    return {
      'donation_id': 'donation-one',
      'status': 'pending',
      'payment_client_secret': 'pi_synthetic_secret_synthetic',
    };
  }

  @override
  Future<Json?> caseOutcome(String caseId, String key) async {
    caseLookups.add((caseId, key));
    return {
      'id': 'donation-one',
      'case_id': caseId,
      'contribution_scope': 'case',
      'idempotency_key': key,
      'gross_cents': 10000,
      'platform_fee_cents': 200,
      'stripe_fee_cents': 600,
      'payment_status': status,
      'refund_status': refund,
      'refund_cents': refund == 'not_started' ? 0 : 10000,
      'payment_state': 'requires_action',
      'allocated_cents': status == 'confirmed' && refund == 'not_started'
          ? 9200
          : 0,
      'transfer_status': 'pending',
      'case_allocations': status == 'confirmed' && refund == 'not_started'
          ? [
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
            ]
          : [],
    };
  }
}

class UnavailableCaseRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      const DataPage([], 0);
}

void main() {
  Future<void> start(
    WidgetTester tester,
    CasePayments payments, {
    RescueRepository? rescue,
  }) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(rescue ?? FakeRescue()),
        paymentRepositoryProvider.overrideWithValue(payments),
        oneoffPaymentSheetProvider.overrideWithValue(FakeOneoffSheet()),
        routerInitialLocationProvider.overrideWithValue(
          '/contribute-case/case-one?amount_cents=10000',
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'case uses the same native attempt through pending and confirmed multi-expense receipt',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final payments = CasePayments();
      await start(tester, payments);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pumpAndSettle();
      expect(find.text('Pago en procesamiento'), findsOneWidget);
      expect(find.text('Pago exitoso'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('dopmi-payment:one:case:case-one:key');
      expect(key, isNotNull);
      payments.status = 'confirmed';
      await tapButton(tester, 'Continuar la misma aportación');
      await tester.pumpAndSettle();
      expect(payments.calls, [key, key]);
      expect(payments.legacyCheckouts, 0);
      expect(find.text('Pago exitoso'), findsOneWidget);
      expect(find.text('Distribución confirmada en el caso'), findsOneWidget);
      expect(find.text('Consulta'), findsOneWidget);
      expect(find.text('Medicina'), findsOneWidget);
      expect(find.text('Costo real de Stripe'), findsOneWidget);
      expect(prefs.getString('dopmi-payment:one:case:case-one:key'), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed processor charge with no assigned capacity keeps the attempt during a full refund',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final payments = CasePayments()
        ..status = 'confirmed'
        ..refund = 'pending';
      await start(tester, payments);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pumpAndSettle();
      expect(find.text('Devolución total en proceso'), findsWidgets);
      expect(find.text('Pago exitoso'), findsNothing);
      expect(find.text('Continuar la misma aportación'), findsNothing);
      expect(find.text('Intentar de nuevo'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('dopmi-payment:one:case:case-one:key'),
        payments.calls.single,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'withdrawn public case disables new payment without inventing funding zeros',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final payments = CasePayments();
      await start(tester, payments, rescue: UnavailableCaseRescue());
      expect(
        find.textContaining(
          'Este caso no está disponible para una nueva aportación.',
        ),
        findsOneWidget,
      );
      expect(find.text('Confirmar aportación'), findsNothing);
      expect(find.textContaining('Reembolso aprobado:'), findsNothing);
      expect(payments.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'own historical case receipt remains readable after the public snapshot is withdrawn',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dopmi-payment:one:case:case-one:key': 'known-attempt',
        'dopmi-payment:one:case:case-one:cents': 10000,
      });
      final payments = CasePayments()..status = 'confirmed';
      await start(tester, payments, rescue: UnavailableCaseRescue());
      expect(find.text('Distribución confirmada en el caso'), findsOneWidget);
      expect(find.text('Consulta'), findsOneWidget);
      expect(find.text('Medicina'), findsOneWidget);
      expect(find.text('Ver caso actualizado'), findsNothing);
      expect(payments.caseLookups, [('case-one', 'known-attempt')]);
      expect(payments.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in <(Json, String)>[
    (
      {'refund_status': 'pending', 'allocated_cents': 0},
      'Devolución total en proceso',
    ),
    (
      {
        'refund_status': 'pending',
        'allocated_cents': 0,
        'external_refund_pending': true,
      },
      'Devolución y transferencias en conciliación',
    ),
    (
      {'refund_status': 'attention', 'allocated_cents': 0},
      'Devolución en revisión',
    ),
    ({'refund_status': 'refunded', 'allocated_cents': 0}, 'Pago devuelto'),
    (
      {
        'refund_status': 'refunded',
        'allocated_cents': 800,
        'transfer_status': 'transferred',
      },
      'Devolución y transferencias en conciliación',
    ),
    (
      {
        'refund_status': 'refunded',
        'allocated_cents': 800,
        'transfer_status': 'reversed',
      },
      'Pago devuelto',
    ),
  ]) {
    testWidgets(
      'refund or reversal state takes precedence over a confirmed charge: ${entry.$2}/${entry.$1}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentResultPage(
              value: {
                'contribution_scope': 'case',
                'payment_status': 'confirmed',
                'gross_cents': 1000,
                'refund_cents': 1000,
                ...entry.$1,
              },
              refresh: () {},
              back: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsWidgets);
        expect(find.text('Pago exitoso'), findsNothing);
        expect(find.text('Continuar la misma aportación'), findsNothing);
        expect(find.text('Intentar de nuevo'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
