import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'expense_field_test.dart' show DraftExpenseRescue;
import 'fake_identity_repository.dart';

class PendingEvidenceRescue extends DraftExpenseRescue {
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'pending': [
      {
        'id': 'expense-one',
        'kind': 'expense',
        'status': 'draft',
        'title': 'Consulta',
        'feedback': '',
      },
    ],
  };
}

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'pending evidence opens its draft and returns without saving: $large',
      (tester) async {
        tester.view.physicalSize = large
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        await identity.setExperience('rescuer');
        final rescue = PendingEvidenceRescue();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(rescue),
            routerInitialLocationProvider.overrideWithValue('/rescuer'),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.text('Continuar evidencia');
        await tester.scrollUntilVisible(
          action,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(find.text('Termina una evidencia pendiente'), findsOneWidget);
        expect(
          find.text('Necesidad: Consulta · Progreso: incompleto'),
          findsOneWidget,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          container.read(routerProvider).state.uri.path,
          '/rescue/expense-one',
        );
        expect(find.text('Sube tu evidencia'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar formulario'));
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/rescuer');
        expect(rescue.savedFiles, isNull);
        expect(rescue.publicSaved, isNull);
        final notifications = find.byTooltip('Notificaciones');
        await tester.scrollUntilVisible(
          notifications,
          -240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(notifications);
        await tester.pumpAndSettle();
        await tester.tap(notifications);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/notifications');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
