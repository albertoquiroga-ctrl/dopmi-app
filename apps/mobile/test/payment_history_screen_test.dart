import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_history_test.dart' show HistoryRepo, cycle;
import 'payments_test.dart' show FakePayments;

class HistoryPayments extends FakePayments {
  final receivedReads = <bool>[];
  @override
  Future<DataPage<Json>> history(int page, {bool received = false}) async {
    receivedReads.add(received);
    return const DataPage([
      {
        'id': 'punctual-one',
        'expense_id': 'expense-one',
        'expense_title': 'Medicamentos',
        'gross_cents': 7525,
        'processor': 'stripe',
        'payment_status': 'pending',
        'transfer_status': 'not_started',
      },
    ], 1);
  }
}

void main() {
  Future<FakeIdentityRepository> start(
    WidgetTester tester,
    HistoryRepo guardian,
    HistoryPayments payments, {
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        paymentRepositoryProvider.overrideWithValue(payments),
        guardianRepositoryProvider.overrideWithValue(guardian),
        guardianEnabledProvider.overrideWithValue(enabled),
        routerInitialLocationProvider.overrideWithValue('/payments'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return identity;
  }

  testWidgets(
    'Combined history shows confirmed cycles before actual punctual payments and loads allocations only on demand',
    (tester) async {
      final guardian = HistoryRepo();
      final payments = HistoryPayments();
      await start(tester, guardian, payments);
      expect(find.text('Suscripción'), findsOneWidget);
      expect(find.text('Pagado'), findsOneWidget);
      expect(find.text(r'$75.25'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Suscripción')).dy,
        lessThan(tester.getTopLeft(find.text('Medicamentos')).dy),
      );
      expect(guardian.allocationCursors, isEmpty);
      await tester.tap(find.text('Suscripción'));
      await tester.pumpAndSettle();
      expect(find.text('Neto asignado: \$43.14 MXN'), findsOneWidget);
      await tester.tap(find.text('Ver asignaciones'));
      await tester.pumpAndSettle();
      expect(guardian.allocationCursors, [null]);
      expect(guardian.calls, isEmpty);
      expect(payments.calls, isEmpty);
    },
  );
  testWidgets(
    'Skipped and processing cycles never claim payment; received filter excludes personal cycles and payment resumption',
    (tester) async {
      final guardian = HistoryRepo()
        ..read = (_) async => {
          'items': [
            cycle('skipped', 'skipped'),
            cycle('pending', 'processing'),
          ],
          'next_cursor': null,
        };
      final payments = HistoryPayments();
      await start(tester, guardian, payments);
      expect(find.text('Sin cargo'), findsOneWidget);
      expect(find.text('Pagado'), findsNothing);
      expect(find.text('Importe autorizado'), findsNWidgets(2));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(payments.receivedReads.last, isTrue);
      expect(guardian.cursors.length, 1);
      expect(find.text('Suscripción'), findsNothing);
      await tester.tap(find.text('Medicamentos'));
      await tester.pumpAndSettle();
      expect(find.text('Continuar aportación'), findsNothing);
    },
  );
  testWidgets('Disabled Guardian makes no cycle reads', (tester) async {
    final guardian = HistoryRepo();
    await start(tester, guardian, HistoryPayments(), enabled: false);
    expect(guardian.cursors, isEmpty);
    expect(find.text(r'$75.25'), findsOneWidget);
  });
  testWidgets('Late combined history does not reveal the prior actor cycle', (
    tester,
  ) async {
    final reply = Completer<Map<String, dynamic>>();
    final guardian = HistoryRepo()..read = (_) => reply.future;
    final identity = await start(tester, guardian, HistoryPayments());
    guardian.read = (_) async => {
      'items': <Map<String, dynamic>>[],
      'next_cursor': null,
    };
    identity.emit(
      const IdentityEvent(Identity('two', 'two@example.test', verified: true)),
    );
    await tester.pump();
    reply.complete({
      'items': [cycle('old-owner', 'assigned')],
      'next_cursor': null,
    });
    await tester.pumpAndSettle();
    expect(find.text('Suscripción'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
