import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/rescue/case_needs.dart';
import 'package:dopmi_mobile/features/rescue/case_review.dart';
import 'package:dopmi_mobile/features/rescue/expense_review.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'case_publication_test.dart' show DraftCaseRescue, expenseFixture;
import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication, tapPublication;

class CaseUnitRescue extends DraftCaseRescue {
  CaseUnitRescue(this.status, {this.everApproved = false});
  String status;
  final bool everApproved;
  final actions = <String>[];
  List<String>? includedIds;
  Map<String, int>? includedVersions;

  @override
  Future<Json> detail(String id) async {
    final data = await super.detail(id);
    final child = id.startsWith('expense');
    return {
      ...data,
      'record': child
          ? expenseFixture().data
          : {...Json.from(data['record']), 'status': status},
      'case_unit': {
        'ever_approved': everApproved,
        'needs_frozen':
            status == 'submitted' || status == 'pending_stripe' || everApproved,
        'needs_editable':
            !everApproved && ['draft', 'changes_requested'].contains(status),
        'can_add_needs':
            !everApproved && ['draft', 'changes_requested'].contains(status),
        'expense_ids': includedIds,
        'expense_versions': includedVersions,
      },
      'history': [
        {
          'action': 'need_comments',
          'version': 4,
          'created_at': '2026-11-02T12:00:00Z',
          'feedback': 'Medicina prescrita:\nAdjunta la receta completa.',
        },
      ],
    };
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    actions.add('${record.kind}:$action');
    status = action == 'withdraw' ? 'draft' : 'submitted';
    return RescueRecord({
      ...record.data,
      'status': status,
      'version': record.version + 1,
    });
  }
}

void main() {
  for (final status in ['submitted', 'pending_stripe']) {
    testWidgets(
      'complete $status packet is read only with comments and one withdrawal',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final rescue = CaseUnitRescue(status);
        final first = expenseFixture();
        rescue.expenses = [
          first,
          RescueRecord({
            ...first.data,
            'id': 'expense-two',
            'public_data': {
              ...first.publicData,
              'title': 'Alimento para recuperación',
            },
          }),
        ];
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/case-one',
          rescue: rescue,
        );
        await tester.scrollUntilVisible(
          find.textContaining('Comentarios por necesidad · Versión'),
          250,
        );
        expect(
          find.textContaining('Adjunta la receta completa.'),
          findsWidgets,
        );
        await tester.scrollUntilVisible(find.byType(CaseReview), 250);
        expect(find.byType(CaseReview), findsOneWidget);
        expect(find.text('Medicina prescrita'), findsOneWidget);
        expect(find.text('Alimento para recuperación'), findsOneWidget);
        expect(
          find.textContaining('Comprobante del gasto · Medicina'),
          findsOneWidget,
        );
        expect(find.text('Registrar gasto realizado'), findsNothing);
        expect(find.text('Enviar a revisión'), findsNothing);
        expect(find.text('Editar'), findsNothing);
        expect(find.text('Retirar a borrador'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Retirar caso completo'),
          400,
        );
        await tapPublication(tester, find.text('Retirar caso completo'));
        expect(rescue.actions, ['case:withdraw']);
        expect(rescue.saveCalls, 0);
        expect(find.byType(PublicationFrame), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'expense deep link cannot independently edit, submit or withdraw a draft',
    (tester) async {
      final rescue = CaseUnitRescue('changes_requested')
        ..expenses = [expenseFixture()];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/expense-draft',
        rescue: rescue,
      );
      expect(find.byType(ExpenseReview), findsOneWidget);
      expect(find.text('Consultar caso completo'), findsOneWidget);
      expect(find.text('Guardar borrador'), findsNothing);
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(find.text('Retirar a borrador'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(rescue.saveCalls, 0);
      expect(rescue.actions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sealed packet excludes a child outside its manifest', (
    tester,
  ) async {
    final first = expenseFixture();
    final rescue = CaseUnitRescue('submitted')
      ..includedIds = [first.id]
      ..includedVersions = {first.id: first.version}
      ..expenses = [
        first,
        RescueRecord({
          ...first.data,
          'id': 'outside-packet',
          'public_data': {
            ...first.publicData,
            'title': 'Borrador fuera del envío',
          },
        }),
      ];
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/case-one',
      rescue: rescue,
    );
    await tester.scrollUntilVisible(find.byType(CaseReview), 250);
    expect(find.text('Medicina prescrita'), findsOneWidget);
    expect(find.text('Borrador fuera del envío'), findsNothing);
    expect(rescue.actions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mismatched sealed version hides the packet until a fresh reload',
    (tester) async {
      final first = expenseFixture();
      final rescue = CaseUnitRescue('submitted')
        ..includedIds = [first.id]
        ..includedVersions = {first.id: first.version + 1}
        ..expenses = [first];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: rescue,
      );
      expect(find.byType(CaseReview), findsNothing);
      expect(find.text('Medicina prescrita'), findsNothing);
      rescue.includedVersions = {first.id: first.version};
      await tapPublication(tester, find.text('Volver a intentar'));
      await tester.scrollUntilVisible(find.byType(CaseReview), 250);
      expect(find.text('Medicina prescrita'), findsOneWidget);
      expect(rescue.actions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new expense deep link returns to case without creating another need',
    (tester) async {
      final rescue = CaseUnitRescue('approved');
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/new?kind=expense&case=case-one',
        rescue: rescue,
      );
      expect(find.text('Las necesidades van con el caso.'), findsOneWidget);
      expect(find.text('Consultar caso completo'), findsOneWidget);
      expect(find.text('Guardar borrador'), findsNothing);
      expect(rescue.saveCalls, 0);
      expect(rescue.actions, isEmpty);
    },
  );

  testWidgets(
    'returned initial case retains whole draft capture and visible need feedback',
    (tester) async {
      final rescue = CaseUnitRescue('changes_requested')
        ..expenses = [expenseFixture()];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: rescue,
      );
      expect(find.byType(PublicationFrame), findsOneWidget);
      expect(
        find.textContaining('Adjunta la receta completa.'),
        findsNWidgets(2),
      );
      await tapPublication(tester, find.text('Continuar'));
      expect(find.byType(CaseDraftNeeds), findsOneWidget);
      expect(find.text('Veterinario'), findsOneWidget);
      expect(find.text('Medicina'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('case-expense-expense-draft')),
        findsOneWidget,
      );
      expect(rescue.actions, isEmpty);
    },
  );

  testWidgets(
    'server marks previously approved returned case outside initial wizard',
    (tester) async {
      final rescue = CaseUnitRescue('changes_requested', everApproved: true)
        ..expenses = [expenseFixture()];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: rescue,
      );
      await tester.scrollUntilVisible(find.byType(CaseReview), 250);
      expect(find.byType(PublicationFrame), findsNothing);
      expect(find.byType(CaseDraftNeeds), findsNothing);
      expect(find.byType(CaseReview), findsOneWidget);
      expect(find.text('Registrar gasto realizado'), findsNothing);
      expect(rescue.saveCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a legacy submitted case that was published cannot withdraw the public case through initial controls',
    (tester) async {
      final rescue = CaseUnitRescue('submitted', everApproved: true)
        ..expenses = [expenseFixture()];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: rescue,
      );
      await tester.scrollUntilVisible(find.byType(CaseReview), 250);
      expect(find.text('Retirar caso completo'), findsNothing);
      expect(find.text('Retirar a borrador'), findsNothing);
      expect(rescue.actions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
