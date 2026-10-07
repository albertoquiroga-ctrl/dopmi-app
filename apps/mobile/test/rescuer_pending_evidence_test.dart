import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'expense_field_test.dart' show DraftExpenseRescue;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeCaseUpdates;

class PendingEvidenceRescue extends DraftExpenseRescue {
  final transitions = <String>[];

  @override
  Future<Json> detail(String id) async {
    if (id == 'case-one') {
      return {
        'record': {...caseRecord.data, 'owner_id': 'one'},
        'history': <Json>[],
      };
    }
    return super.detail(id);
  }

  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async {
    if (page != 1) return const DataPage([], 0);
    if (kind == 'case') {
      return DataPage([
        RescueRecord({...caseRecord.data, 'owner_id': 'one'}),
      ], 1);
    }
    if (kind == 'expense' && parent == 'case-one') {
      return DataPage([
        RescueRecord(Json.from((await super.detail('expense-one'))['record'])),
      ], 1);
    }
    return const DataPage([], 0);
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    transitions.add(action);
    return record;
  }

  @override
  Future<Json> dashboardV2() async => {
    ...await super.dashboardV2(),
    'pending_evidence': [
      {
        'expense_id': 'expense-one',
        'case_id': 'case-one',
        'pet_name': 'Choco',
        'expense_title': 'Consulta',
        'status': 'draft',
        'urgent': false,
        'progress_percent': 0,
        'editable': true,
      },
    ],
  };
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
      'pending evidence is informational and its draft route returns without saving: $large',
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
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
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
        final selector = find.text('Recibiendo apoyo').first;
        final homeScroll = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(selector, 160, scrollable: homeScroll);
        await Scrollable.ensureVisible(tester.element(selector), alignment: .5);
        await tester.pumpAndSettle();
        expect(selector.hitTestable(), findsOneWidget);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        expect(find.text('Continuar evidencia'), findsNothing);
        expect(container.read(routerProvider).state.uri.path, '/rescuer');
        expect(rescue.savedFiles, isNull);
        expect(rescue.publicSaved, isNull);
        expect(rescue.transitions, isEmpty);
        // The summary remains informational; the record opens through Mis Casos.
        final support = find.byKey(const ValueKey('home-quick-support'));
        await tester.scrollUntilVisible(support, 240, scrollable: homeScroll);
        await Scrollable.ensureVisible(tester.element(support), alignment: .5);
        await tester.pumpAndSettle();
        expect(support.hitTestable(), findsOneWidget);
        await tester.tap(support);
        await tester.pumpAndSettle();
        expect(find.text('Resumen de apoyo'), findsOneWidget);
        expect(container.read(routerProvider).state.uri.path, '/rescuer');
        expect(rescue.savedFiles, isNull);
        expect(rescue.publicSaved, isNull);
        expect(rescue.transitions, isEmpty);
        final active = find.byKey(
          const ValueKey('home-summary-support-active'),
        );
        await tester.scrollUntilVisible(active, 240, scrollable: homeScroll);
        await tester.ensureVisible(active);
        await tester.pumpAndSettle();
        await tester.tap(active);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/my-cases');
        expect(container.read(routerProvider).state.uri.queryParameters, {
          'program': 'support',
          'status': 'active',
        });
        final caseScroll = find.descendant(
          of: find.byKey(const ValueKey('owned-cases-scroll')),
          matching: find.byType(Scrollable),
        );
        final openCase = find.byKey(const ValueKey('owned-case-open-case-one'));
        await tester.scrollUntilVisible(openCase, 240, scrollable: caseScroll);
        await tester.ensureVisible(openCase);
        await tester.pumpAndSettle();
        await tester.tap(openCase);
        await tester.pumpAndSettle();
        expect(
          container.read(routerProvider).state.uri.path,
          '/rescue/case-one',
        );
        final detailScroll = find
            .descendant(
              of: find.byType(SingleChildScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        final continueExpense = find.text('Continuar gasto');
        await tester.scrollUntilVisible(
          continueExpense,
          240,
          scrollable: detailScroll,
        );
        await tester.ensureVisible(continueExpense);
        await tester.pumpAndSettle();
        await tester.tap(continueExpense);
        await tester.pumpAndSettle();
        expect(
          container.read(routerProvider).state.uri.path,
          '/rescue/expense-one',
        );
        expect(find.text('Sube tu evidencia'), findsOneWidget);
        expect(rescue.transitions, isEmpty);
        await tester.tap(find.byTooltip('Cerrar formulario'));
        await tester.pumpAndSettle();
        expect(
          container.read(routerProvider).state.uri.path,
          '/rescue/case-one',
        );
        expect(rescue.savedFiles, isNull);
        expect(rescue.publicSaved, isNull);
        expect(rescue.transitions, isEmpty);
        final back = find.byKey(const ValueKey('owned-case-back'));
        await tester.scrollUntilVisible(back, -240, scrollable: detailScroll);
        await tester.ensureVisible(back);
        await tester.pumpAndSettle();
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/my-cases');
        container.read(routerProvider).pop();
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/rescuer');
        expect(rescue.savedFiles, isNull);
        expect(rescue.publicSaved, isNull);
        expect(rescue.transitions, isEmpty);
        final notifications = find.byTooltip('Notificaciones');
        await tester.scrollUntilVisible(
          notifications,
          -240,
          scrollable: homeScroll,
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
