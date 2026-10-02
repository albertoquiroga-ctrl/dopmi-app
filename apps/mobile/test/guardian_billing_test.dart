import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_history_test.dart' show HistoryRepo, cycle;
import 'guardian_test.dart' show activePlan;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<FakeIdentityRepository> start(
    WidgetTester tester,
    HistoryRepo repo,
  ) async {
    tester.view.physicalSize = const Size(377, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo.value = {'plan': activePlan(), 'activation': null};
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        guardianRepositoryProvider.overrideWithValue(repo),
        guardianEnabledProvider.overrideWithValue(true),
        routerInitialLocationProvider.overrideWithValue('/guardian'),
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
    'Billing places management before actual payments and preserves confirmed financial details',
    (tester) async {
      final repo = HistoryRepo();
      await start(tester, repo);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Cancelar suscripción')).dy,
        lessThan(tester.getTopLeft(find.text('Historial de pagos')).dy),
      );
      expect(find.text('Suscripción'), findsOneWidget);
      expect(find.text('Pagado'), findsOneWidget);
      expect(find.text('Aún no hay pagos registrados.'), findsNothing);
      await tester.tap(find.text('Suscripción'));
      await tester.pumpAndSettle();
      expect(find.text('Neto asignado: \$43.14 MXN'), findsOneWidget);
      expect(repo.calls, isEmpty);
    },
  );
  testWidgets(
    'History errors preserve the active plan and never claim an empty history',
    (tester) async {
      final repo = HistoryRepo()
        ..read = (_) async => throw Exception('offline');
      await start(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Suscripción activa'), findsOneWidget);
      expect(
        find.text('No pudimos consultar tus pagos. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Aún no hay pagos registrados.'), findsNothing);
      expect(repo.calls, isEmpty);
    },
  );
  testWidgets(
    'Late billing history belongs only to the account that requested it',
    (tester) async {
      final reply = Completer<Map<String, dynamic>>();
      final repo = HistoryRepo()..read = (_) => reply.future;
      final identity = await start(tester, repo);
      repo.read = (_) async => {
        'items': <Map<String, dynamic>>[],
        'next_cursor': null,
      };
      identity.emit(
        const IdentityEvent(
          Identity('two', 'two@example.test', verified: true),
        ),
      );
      await tester.pump();
      reply.complete({
        'items': [cycle('old-owner', 'assigned')],
        'next_cursor': null,
      });
      await tester.pumpAndSettle();
      expect(find.text('Suscripción'), findsNothing);
      expect(find.text('Pagado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Switching accounts removes an already-opened financial receipt',
    (tester) async {
      final repo = HistoryRepo();
      final identity = await start(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suscripción'));
      await tester.pumpAndSettle();
      expect(find.text('Neto asignado: \$43.14 MXN'), findsOneWidget);
      repo.read = (_) async => {
        'items': <Map<String, dynamic>>[],
        'next_cursor': null,
      };
      identity.emit(
        const IdentityEvent(
          Identity('two', 'two@example.test', verified: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Neto asignado: \$43.14 MXN'), findsNothing);
      expect(find.text('Suscripción'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
