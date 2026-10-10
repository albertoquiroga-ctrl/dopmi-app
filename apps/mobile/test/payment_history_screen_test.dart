import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_screen.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_screens.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'payments_test.dart' show FakePayments;
import 'rescue_test.dart' show FakeRescue, FakeCaseUpdates;

Json donation({bool pending = false, bool public = true}) => {
  'id': 'donation-one',
  'kind': 'contribution',
  'title': 'Medicamentos',
  'created_at': '2026-10-08T12:00:00Z',
  'amount_cents': 7525,
  'gross_cents': 7525,
  'payment_status': pending ? 'pending' : 'confirmed',
  'status': pending ? 'processing' : 'assigned',
  'assigned_cents': pending ? 0 : 7000,
  'net_cents': 7000,
  'processed_at': pending ? null : '2026-10-08T12:01:00Z',
  'platform_fee_cents': 150,
  'stripe_fee_cents': 375,
  'expense_id': 'expense-one',
  'idempotency_key': pending ? 'stable-checkout-key' : null,
  'case_id': public ? 'case-one' : null,
  'case_name': public ? 'Choco' : null,
};
Json cycle({bool skipped = false}) => {
  'id': 'cycle-one',
  'kind': 'guardian',
  'title': 'Suscripción Guardián',
  'allocation_count': skipped ? 0 : 1,
  'created_at': '2026-10-08T12:02:00Z',
  'amount_cents': skipped ? 0 : 2000,
  'authorized_cents': 2000,
  'status': skipped ? 'skipped' : 'assigned',
  'processed_at': skipped ? null : '2026-10-08T12:02:00Z',
  'assigned_cents': skipped ? 0 : 1860,
};

class RouteActivity extends PaymentActivityRepository {
  RouteActivity(this.rows) : super(FakeRescue().client);
  List<Json> rows;
  final receivedReads = <bool>[];
  int allocationsReads = 0;
  Completer<Json>? pending, pendingAllocations;
  @override
  Future<Json> page({required bool received, Json? cursor}) async {
    receivedReads.add(received);
    final wait = pending;
    pending = null;
    return wait == null
        ? {
            'items': received
                ? rows
                      .map(
                        (r) => <String, dynamic>{
                          ...r,
                          'amount_cents': r['assigned_cents'] ?? 0,
                          'gross_cents': null,
                          'idempotency_key': null,
                          'platform_fee_cents': null,
                          'stripe_fee_cents': null,
                        },
                      )
                      .toList()
                : rows,
            'next_cursor': null,
          }
        : wait.future;
  }

  @override
  Future<Json> allocations(
    String cycle, {
    required bool received,
    String? afterExpense,
  }) async {
    allocationsReads++;
    if (pendingAllocations != null) return pendingAllocations!.future;
    if (rows.any((r) => r['id'] == cycle && r['status'] == 'skipped')) {
      return {'items': <Json>[], 'next_cursor': null};
    }
    return {
      'items': [
        {
          'expense_id': 'expense-one',
          'title': 'Cirugía',
          'allocated_cents': 1860,
          'status': 'partial_reversal',
          'reversed_cents': 200,
          'remaining_cents': 1660,
          'transferred_cents': 1660,
        },
      ],
      'next_cursor': null,
    };
  }
}

class UnavailableRouteCase extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    if (caseId != null) throw StateError('Public case temporarily unavailable');
    return super.catalog(page, caseId: caseId);
  }
}

void main() {
  Future<(ProviderContainer, FakeIdentityRepository, FakePayments)> mount(
    WidgetTester tester,
    RouteActivity repo, {
    bool received = false,
    bool guardian = true,
    RescueRepository? rescue,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'synthetic@example.test', verified: true);
    final payment = FakePayments();
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        paymentActivityRepositoryProvider.overrideWithValue(repo),
        paymentRepositoryProvider.overrideWithValue(payment),
        rescueRepositoryProvider.overrideWithValue(rescue ?? FakeRescue()),
        caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
        guardianEnabledProvider.overrideWithValue(guardian),
        routerInitialLocationProvider.overrideWithValue(
          received ? '/rescuer/received-payments' : '/payments',
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    final waiting = repo.pending != null;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    if (waiting) {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } else {
      await tester.pumpAndSettle();
    }
    return (container, identity, payment);
  }

  testWidgets(
    'actual payments route retains globally ordered ledger, lazy allocations, private receipt and Back',
    (tester) async {
      final repo = RouteActivity([cycle(), donation()]);
      final result = await mount(tester, repo);
      expect(find.byType(PaymentActivityScreen), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Suscripción Guardián · 1 asignación')).dy,
        lessThan(tester.getTopLeft(find.text('Medicamentos - Choco')).dy),
      );
      expect(repo.allocationsReads, 0);
      await tester.tap(find.text('Suscripción Guardián · 1 asignación'));
      await tester.pumpAndSettle();
      expect(repo.allocationsReads, 1);
      expect(find.textContaining('Cirugía ·'), findsOneWidget);
      expect(find.text('Reversión parcial de transferencia'), findsOneWidget);
      expect(find.text('Neto vigente: \$16.60 MXN'), findsOneWidget);
      expect(find.text('Neto transferido: \$16.60 MXN'), findsOneWidget);
      await tester.tap(find.text('Medicamentos - Choco'));
      await tester.pump();
      expect(find.text('Importe pagado: \$75.25 MXN'), findsOneWidget);
      expect(find.text('Comisión Dopmi: \$1.50 MXN'), findsOneWidget);
      expect(find.text('Costos de Stripe: \$3.75 MXN'), findsOneWidget);
      expect(find.text('Neto para el rescatista: \$70 MXN'), findsOneWidget);
      expect(find.text('Referencia: donation-one'), findsOneWidget);
      await tester.tap(find.text('Ver caso'));
      await tester.pumpAndSettle();
      expect(
        result.$1.read(routerProvider).state.uri.path,
        '/rescue-cases/case-one',
      );
      result.$1.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.text('Importe pagado: \$75.25 MXN'), findsOneWidget);
    },
  );
  testWidgets(
    'pending donor resumes exact intent and amount without claiming paid',
    (tester) async {
      final result = await mount(
        tester,
        RouteActivity([donation(pending: true)]),
      );
      await tester.tap(find.text('Medicamentos - Choco'));
      await tester.pump();
      expect(find.text('Importe solicitado: \$75.25 MXN'), findsOneWidget);
      expect(find.textContaining('Importe pagado'), findsNothing);
      expect(find.textContaining('Comisión Dopmi:'), findsNothing);
      await tester.tap(find.text('Continuar aportación'));
      await tester.pumpAndSettle();
      expect(
        result.$1.read(routerProvider).state.uri.path,
        '/contribute/expense-one',
      );
      final screen = tester.widget<ContributeScreen>(
        find.byType(ContributeScreen),
      );
      expect(screen.attempt?['idempotency_key'], 'stable-checkout-key');
      expect(screen.attempt?['gross_cents'], 7525);
      expect(find.text('Continuar mi aportación'), findsOneWidget);
      expect(result.$3.calls, isEmpty);
    },
  );
  testWidgets(
    'withdrawn public case keeps private financial evidence and never invents a destination',
    (tester) async {
      await mount(tester, RouteActivity([donation(public: false)]));
      expect(find.text('Medicamentos'), findsOneWidget);
      expect(find.textContaining('Choco'), findsNothing);
      await tester.tap(find.text('Medicamentos'));
      await tester.pump();
      expect(find.text('Referencia: donation-one'), findsOneWidget);
      expect(find.text('Importe pagado: \$75.25 MXN'), findsOneWidget);
      expect(find.text('Ver caso'), findsNothing);
    },
  );
  testWidgets(
    'received route requests receiver ledger and never exposes donor fees or resumption',
    (tester) async {
      final repo = RouteActivity([donation()]);
      await mount(tester, repo, received: true);
      expect(repo.receivedReads, [true]);
      await tester.tap(find.text('Medicamentos - Choco'));
      await tester.pump();
      expect(find.text('Neto asignado: \$70 MXN'), findsOneWidget);
      expect(find.text('Continuar aportación'), findsNothing);
      expect(find.textContaining('Comisión Dopmi:'), findsNothing);
    },
  );
  testWidgets('skipped cycle never claims paid even with activation disabled', (
    tester,
  ) async {
    await mount(
      tester,
      RouteActivity([cycle(skipped: true), donation()]),
      guardian: false,
    );
    expect(find.text('Suscripción Guardián · 0 asignaciones'), findsOneWidget);
    await tester.tap(find.text('Suscripción Guardián · 0 asignaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Ciclo omitido sin cargo ni deuda'), findsOneWidget);
    expect(find.textContaining('Importe pagado'), findsNothing);
    expect(find.text('Importe autorizado: \$20 MXN'), findsOneWidget);
    expect(find.text('Medicamentos - Choco'), findsOneWidget);
  });
  testWidgets(
    'disabled Guardian activation keeps confirmed owned ledger readable',
    (tester) async {
      await mount(tester, RouteActivity([cycle()]), guardian: false);
      await tester.tap(find.text('Suscripción Guardián · 1 asignación'));
      await tester.pumpAndSettle();
      expect(find.text('Importe pagado: \$20 MXN'), findsOneWidget);
      expect(find.text('Referencia: cycle-one'), findsOneWidget);
    },
  );
  testWidgets('late previous actor ledger is ignored after identity change', (
    tester,
  ) async {
    final wait = Completer<Json>();
    final repo = RouteActivity([])..pending = wait;
    final result = await mount(tester, repo);
    result.$2.emit(
      const IdentityEvent(
        Identity('two', 'other@example.test', verified: true),
      ),
    );
    await tester.pump();
    wait.complete({
      'items': [donation()],
      'next_cursor': null,
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Medicamentos'), findsNothing);
    expect(find.text('Referencia: donation-one'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'late prior owner allocations cannot expose details or case navigation',
    (tester) async {
      final wait = Completer<Json>();
      final repo = RouteActivity([cycle()])..pendingAllocations = wait;
      final result = await mount(tester, repo);
      await tester.tap(find.text('Suscripción Guardián · 1 asignación'));
      await tester.pump();
      expect(repo.allocationsReads, 1);
      repo.rows = [];
      result.$2.emit(
        const IdentityEvent(
          Identity('two', 'other@example.test', verified: true),
        ),
      );
      await tester.pump();
      wait.complete({
        'items': [
          {
            'expense_id': 'old-private',
            'title': 'Anterior propietario',
            'allocated_cents': 1860,
            'status': 'assigned',
            'case_id': 'case-one',
          },
        ],
        'next_cursor': null,
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Anterior propietario'), findsNothing);
      expect(find.text('Ver caso'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'public case loading failure preserves private receipt and Back',
    (tester) async {
      final result = await mount(
        tester,
        RouteActivity([donation()]),
        rescue: UnavailableRouteCase(),
      );
      await tester.tap(find.text('Medicamentos - Choco'));
      await tester.pump();
      await tester.tap(find.text('Ver caso'));
      await tester.pumpAndSettle();
      expect(
        result.$1.read(routerProvider).state.uri.path,
        '/rescue-cases/case-one',
      );
      result.$1.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.text('Referencia: donation-one'), findsOneWidget);
      expect(find.text('Importe pagado: \$75.25 MXN'), findsOneWidget);
      expect(find.text('Costos de Stripe: \$3.75 MXN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
