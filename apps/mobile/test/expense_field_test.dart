import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

class DraftExpenseRescue extends FakeRescue {
  DraftExpenseRescue({this.initialFiles = const []});
  final List<Json> initialFiles;
  List<Json>? savedFiles;
  Json? publicSaved;
  @override
  Future<Json> detail(String id) async => {
    'record': {
      ...expenseRecord.data,
      'owner_id': 'one',
      'status': 'draft',
      'private_data': {'amount_cents': 12345, 'vendor': 'Clínica'},
      'public_data': {'title': 'Consulta', 'category': 'medicine'},
      'files': initialFiles,
    },
    'history': <Json>[],
  };

  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    savedFiles = files.map((file) => Json.from(file)).toList();
    saved = privateData;
    publicSaved = publicData;
    return RescueRecord({
      ...record!.data,
      'public_data': publicData,
      'private_data': privateData,
      'files': files,
      'version': record.version + 1,
    });
  }
}

void main() {
  testWidgets(
    'expense close keeps an unsaved draft and save progress persists before leaving',
    (tester) async {
      final repo = DraftExpenseRescue();
      await startPublication(tester, FakeCommunity(), '/publish', rescue: repo);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push('/rescue/expense-one')
          .ignore();
      await tester.pumpAndSettle();
      final next = find.text('Siguiente');
      await tester.scrollUntilVisible(
        next,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('expense-form-body')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('expense-field-title'));
      await tester.scrollUntilVisible(
        title,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(title, 'Consulta corregida');
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('expense-form-body')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Cerrar formulario'),
        -300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar formulario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Consulta corregida',
      );
      final save = find.text('Guardar progreso');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.publicSaved!['title'], 'Consulta corregida');
      expect(find.byKey(const ValueKey('expense-form-body')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'removing a private receipt preserves the public photo role when saved',
    (tester) async {
      final repo = DraftExpenseRescue(
        initialFiles: [
          {'role': 'receipt', 'path': 'one/expense-one/receipt.pdf'},
          {'role': 'public', 'path': 'one/expense-one/photo.jpg'},
        ],
      );
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/expense-one',
        rescue: repo,
      );
      final remove = find.byTooltip('Quitar archivo 1');
      await tester.scrollUntilVisible(
        remove,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      final next = find.text('Siguiente');
      await tester.scrollUntilVisible(
        next,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(repo.savedFiles, [
        {'role': 'public', 'path': 'one/expense-one/photo.jpg'},
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'expense inputs retain private exact cents through review at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = DraftExpenseRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/expense-one',
        rescue: repo,
      );
      Future<void> tapNext() async {
        final next = find.text('Siguiente');
        await tester.scrollUntilVisible(
          next,
          300,
          maxScrolls: 100,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('expense-form-body')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
      }

      await tapNext();
      final amount = find.byKey(const ValueKey('expense-field-amount_cents'));
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('expense-form-body')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        amount,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<TextField>(amount).controller!.text, '123.45');
      await Scrollable.ensureVisible(tester.element(amount));
      await tester.pumpAndSettle();
      await tester.enterText(amount, '87.09');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapNext();
      expect(repo.saved!['amount_cents'], '8709');
      expect(repo.saved!['vendor'], 'Clínica');
      expect(repo.publicSaved!.containsKey('amount_cents'), isFalse);
      expect(repo.publicSaved!.containsKey('vendor'), isFalse);
      expect(repo.publicSaved!['category'], 'medicine');
      expect(find.text('Enviar a revisión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
