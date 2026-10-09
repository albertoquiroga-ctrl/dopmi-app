import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class ActivityRepository extends PaymentActivityRepository {
  ActivityRepository() : super(FakeRescue().client);
  final cursors = <Json?>[];
  bool fail = false;
  @override
  Future<Json> page({required bool received, Json? cursor}) async {
    cursors.add(cursor);
    if (fail) throw StateError('offline');
    return {
      'items': [
        {
          'id': cursor == null ? 'one' : 'two',
          'kind': cursor == null ? 'guardian' : 'contribution',
          'title': cursor == null ? 'Suscripción Guardián' : 'Consulta',
          'created_at': '2026-10-08T12:00:00Z',
          'amount_cents': 1011,
          'assigned_cents': 811,
          'status': 'assigned',
          'allocation_count': cursor == null ? 2 : 1,
        },
      ],
      'next_cursor': cursor == null
          ? {
              'created_at': '2026-10-08T12:00:00Z',
              'kind': 'guardian',
              'id': 'one',
            }
          : null,
    };
  }

  @override
  Future<Json> allocations(
    String cycle, {
    required bool received,
    String? afterExpense,
  }) async => {
    'items': [
      {
        'expense_id': 'one',
        'title': 'Consulta',
        'allocated_cents': 811,
        'reversed_cents': 0,
        'status': 'assigned',
      },
    ],
    'next_cursor': null,
  };
}

void main() {
  Future<ActivityRepository> mount(WidgetTester tester) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'synthetic@example.test', verified: true);
    final repo = ActivityRepository();
    addTearDown(identity.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          paymentActivityRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: PaymentActivityScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('unified pages retain centavos and real multiple assignments', (
    tester,
  ) async {
    final repo = await mount(tester);
    expect(find.text('Suscripción Guardián · 2 asignaciones'), findsOneWidget);
    expect(
      tester.widget<ActivityMoney>(find.byType(ActivityMoney)).cents,
      1011,
    );
    expect(find.text('.11'), findsOneWidget);
    expect(find.textContaining('4242'), findsNothing);
    await tester.tap(find.text('Ver movimientos anteriores'));
    await tester.pumpAndSettle();
    expect(repo.cursors.last?['kind'], 'guardian');
    expect(find.text('Consulta'), findsOneWidget);
    expect(find.text('.11'), findsNWidgets(2));
    await tester.tap(find.text('Suscripción Guardián · 2 asignaciones'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Consulta ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed refresh retry repeats refresh with retained rows', (
    tester,
  ) async {
    final repo = await mount(tester);
    repo.fail = true;
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(
      find.textContaining('No pudimos consultar tu historial'),
      findsOneWidget,
    );
    expect(find.text('Suscripción Guardián · 2 asignaciones'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Reintentar historial'));
    await tester.pumpAndSettle();
    expect(repo.cursors.last, isNull);
    expect(
      find.textContaining('No pudimos consultar tu historial'),
      findsNothing,
    );
  });
}
