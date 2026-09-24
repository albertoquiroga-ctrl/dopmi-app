import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;
import 'payments_test.dart' show pumpUntil;

Json cycle(String id, String status, {String kind = 'monthly'}) => {
  'id': id,
  'created_at': '2026-09-24T12:00:00Z',
  'kind': kind,
  'authorized_cents': 5000,
  'status': status,
  'paid_cents':
      ['assigned', 'transferred', 'refund_pending', 'refunded'].contains(status)
      ? 5000
      : null,
  'platform_fee_cents': 100,
  'stripe_fee_cents': 586,
  'assigned_cents': ['assigned', 'transferred'].contains(status) ? 4314 : 0,
  'transferred_cents': status == 'transferred' ? 4314 : 0,
  'refund_cents': status.startsWith('refund') ? 5000 : 0,
  'allocation_count': ['assigned', 'transferred'].contains(status) ? 1 : 0,
};

class HistoryRepo extends FakeGuardian {
  final cursors = <Json?>[];
  final allocationCursors = <String?>[];
  Future<Json> Function(Json?)? read;
  bool failPage = false, failAllocation = false;
  @override
  Future<Json> history({Json? cursor}) async {
    cursors.add(cursor);
    if (read != null) return read!(cursor);
    if (failPage && cursor != null) throw Exception('offline');
    return {
      'items': [
        cycle(
          cursor == null ? 'first' : 'second',
          cursor == null ? 'assigned' : 'skipped',
        ),
      ],
      'next_cursor': cursor == null
          ? {'id': 'first', 'created_at': '2026-09-24T12:00:00Z'}
          : null,
    };
  }

  @override
  Future<Json> allocations(String cycleId, {String? cursor}) async {
    allocationCursors.add(cursor);
    if (failAllocation) throw Exception('offline');
    return {
      'items': [
        {
          'id': 'expense',
          'title': 'Medicamentos',
          'amount_cents': 4314,
          'status': 'assigned',
        },
      ],
      'next_cursor': null,
    };
  }
}

void main() {
  Future<FakeIdentityRepository> start(
    WidgetTester tester,
    HistoryRepo repo, {
    bool enabled = true,
    bool verified = true,
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = Identity('one', 'one@example.test', verified: verified);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        guardianRepositoryProvider.overrideWithValue(repo),
        guardianEnabledProvider.overrideWithValue(enabled),
        routerInitialLocationProvider.overrideWithValue('/guardian/history'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await pumpUntil(tester, find.text('Historial de ciclos'));
    return identity;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('history route is disabled by default without financial reads', (
    tester,
  ) async {
    final repo = HistoryRepo();
    await start(tester, repo, enabled: false);
    await tester.pumpAndSettle();
    expect(repo.cursors, isEmpty);
    expect(find.text('Guardián todavía no está disponible.'), findsOneWidget);
  });
  testWidgets(
    'history paginates and retries the same failed cursor without losing confirmed items',
    (tester) async {
      final repo = HistoryRepo()..failPage = true;
      await start(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Pago confirmado · neto asignado'), findsOneWidget);
      await tap(tester, 'Ver ciclos anteriores');
      expect(find.text('Pago confirmado · neto asignado'), findsOneWidget);
      expect(
        find.text('No pudimos consultar el historial. Intenta de nuevo.'),
        findsOneWidget,
      );
      repo.failPage = false;
      await tap(tester, 'Reintentar ciclos anteriores');
      expect(repo.cursors[1], repo.cursors[2]);
      expect(find.text('Ciclo omitido sin cargo ni deuda'), findsOneWidget);
      expect(find.text('Pago confirmado · neto asignado'), findsOneWidget);
      expect(repo.calls, isEmpty);
      expect(repo.opened, 0);
    },
  );
  testWidgets(
    'allocation details load on demand and retry without claiming bank deposit',
    (tester) async {
      final repo = HistoryRepo()..failAllocation = true;
      await start(tester, repo);
      await tester.pumpAndSettle();
      expect(repo.allocationCursors, isEmpty);
      await tap(tester, 'Ver asignaciones');
      expect(
        find.text('No pudimos consultar las asignaciones.'),
        findsOneWidget,
      );
      repo.failAllocation = false;
      await tap(tester, 'Reintentar asignaciones');
      expect(find.text('Medicamentos'), findsOneWidget);
      expect(
        find.textContaining('Asignado; transferencia pendiente'),
        findsOneWidget,
      );
      expect(find.textContaining('no confirma un depósito'), findsOneWidget);
    },
  );
  testWidgets(
    'unconfirmed owner retains history and refunds remain distinct from pending payment',
    (tester) async {
      final repo = HistoryRepo()
        ..read = (_) async => {
          'items': [
            cycle('pending', 'processing'),
            cycle('refund', 'refund_pending'),
            cycle('done', 'refunded'),
          ],
          'next_cursor': null,
        };
      await start(tester, repo, verified: false);
      await tester.pumpAndSettle();
      expect(find.text('En conciliación'), findsOneWidget);
      expect(find.text('Devolución en proceso'), findsOneWidget);
      expect(find.text('Devolución confirmada'), findsOneWidget);
      expect(find.textContaining('Pago confirmado:'), findsNWidgets(2));
      expect(find.textContaining('Por devolver:'), findsOneWidget);
      expect(find.textContaining('Devuelto:'), findsOneWidget);
    },
  );
  testWidgets('late history response is discarded after switching accounts', (
    tester,
  ) async {
    final reply = Completer<Json>();
    final repo = HistoryRepo()..read = (_) => reply.future;
    final identity = await start(tester, repo);
    repo.read = (_) async => {'items': <Json>[], 'next_cursor': null};
    identity.emit(
      IdentityEvent(Identity('two', 'two@example.test', verified: true)),
    );
    await tester.pump();
    reply.complete({
      'items': [cycle('private-old', 'transferred')],
      'next_cursor': null,
    });
    await tester.pumpAndSettle();
    expect(find.text('Neto transferido'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'switching accounts removes already displayed financial details',
    (tester) async {
      final repo = HistoryRepo();
      final identity = await start(tester, repo);
      await tester.pumpAndSettle();
      await tap(tester, 'Ver asignaciones');
      expect(find.text('Medicamentos'), findsOneWidget);
      repo.read = (_) async => {'items': <Json>[], 'next_cursor': null};
      identity.emit(
        IdentityEvent(Identity('two', 'two@example.test', verified: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Medicamentos'), findsNothing);
      expect(find.text('Pago confirmado · neto asignado'), findsNothing);
      expect(
        find.text('Todavía no tienes ciclos registrados.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'refresh clears old cycles and shows the authoritative empty history',
    (tester) async {
      final repo = HistoryRepo();
      await start(tester, repo);
      await tester.pumpAndSettle();
      repo.read = (_) async => {'items': <Json>[], 'next_cursor': null};
      await tap(tester, 'Actualizar historial');
      expect(
        find.text('Todavía no tienes ciclos registrados.'),
        findsOneWidget,
      );
      expect(find.text('Pago confirmado · neto asignado'), findsNothing);
      expect(find.text('Ver ciclos anteriores'), findsNothing);
    },
  );
}
