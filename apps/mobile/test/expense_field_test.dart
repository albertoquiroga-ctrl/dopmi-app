import 'dart:async';

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/expense_frame.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

class DraftExpenseRescue extends FakeRescue {
  DraftExpenseRescue({
    this.initialDescription = 'Recibió su consulta veterinaria.',
    this.initialFiles = const [
      {'role': 'receipt', 'path': 'one/expense-one/receipt.pdf'},
    ],
  });
  final List<Json> initialFiles;
  final String initialDescription;
  List<Json>? savedFiles;
  Json? publicSaved;
  @override
  Future<Json> detail(String id) async => {
    'record': {
      ...expenseRecord.data,
      'owner_id': 'one',
      'status': 'draft',
      'private_data': {'amount_cents': 12345, 'vendor': 'Clínica'},
      'public_data': {
        'title': 'Consulta',
        'category': 'medicine',
        'description': initialDescription,
      },
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

class DelayedExpenseRescue extends DraftExpenseRescue {
  final response = Completer<void>();
  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    await response.future;
    return super.save(
      kind,
      publicData,
      privateData,
      files,
      record: record,
      parent: parent,
    );
  }
}

class SubmittedExpenseRescue extends DraftExpenseRescue {
  bool failSubmit = false, failDetail = false;
  int detailReads = 0;
  String remoteStatus = 'draft';
  Completer<RescueRecord>? pending;
  @override
  Future<Json> detail(String id) async {
    detailReads++;
    if (failDetail) {
      throw const FormatException('No pudimos leer el expediente.');
    }
    final data = await super.detail(id);
    (data['record'] as Json)['status'] = remoteStatus;
    return data;
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    if (failSubmit) {
      throw const FormatException('Faltan comprobantes para enviar.');
    }
    final result = pending == null
        ? RescueRecord({...record.data, 'status': 'submitted'})
        : await pending!.future;
    remoteStatus = result.status;
    return result;
  }
}

void resumeExpense(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'expense changes step immediately after save response at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = DelayedExpenseRescue();
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/expense-one',
          rescue: repo,
        );
        final body = find.byKey(const ValueKey('expense-form-body'));
        final scroll = find
            .descendant(of: body, matching: find.byType(Scrollable))
            .first;
        final next = find.text('Siguiente');
        await tester.scrollUntilVisible(
          next,
          300,
          maxScrolls: 100,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<ExpenseFrame>(find.byType(ExpenseFrame)).step, 0);
        expect(repo.savedFiles, isNull);
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(of: next, matching: find.byType(FilledButton)),
              )
              .onPressed,
          isNull,
        );
        repo.response.complete();
        await tester.pump();
        expect(tester.widget<ExpenseFrame>(find.byType(ExpenseFrame)).step, 1);
        expect(repo.savedFiles, repo.initialFiles);
        final firstRect = tester.getRect(body);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(body), firstRect);
        await tester.pumpAndSettle();
        expect(tester.getRect(body), firstRect);
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        final back = find.byTooltip('Paso anterior');
        await tester.ensureVisible(back);
        await tester.pumpAndSettle();
        await tester.tap(back);
        await tester.pump();
        expect(tester.widget<ExpenseFrame>(find.byType(ExpenseFrame)).step, 0);
        await tester.pumpAndSettle();
        expect(repo.savedFiles, repo.initialFiles);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'description requires content and incomplete save remains available at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = DraftExpenseRescue(initialDescription: '   ');
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/expense-one',
          rescue: repo,
        );
        final scroll = find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first;
        Future<void> showAction(String text) async {
          await tester.scrollUntilVisible(
            find.text(text),
            300,
            maxScrolls: 100,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
        }

        for (var i = 0; i < 2; i++) {
          await showAction('Siguiente');
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
        }
        FilledButton nextButton() => tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Siguiente'),
            matching: find.byType(FilledButton),
          ),
        );
        await showAction('Siguiente');
        expect(nextButton().onPressed, isNull);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('Revisa antes de enviar'), findsNothing);
        final field = find.byKey(const ValueKey('expense-field-description'));
        await tester.scrollUntilVisible(
          field,
          -300,
          maxScrolls: 100,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        await tester.enterText(field, 'Recibió su tratamiento.');
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await showAction('Siguiente');
        expect(nextButton().onPressed, isNotNull);
        await tester.scrollUntilVisible(
          field,
          -300,
          maxScrolls: 100,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        await tester.enterText(field, '');
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await showAction('Siguiente');
        expect(nextButton().onPressed, isNull);
        await showAction('Guardar progreso');
        await tester.tap(find.text('Guardar progreso'));
        await tester.pumpAndSettle();
        expect(repo.publicSaved!['description'], '');
        expect(repo.savedFiles, repo.initialFiles);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'receipt step blocks advance but saves incomplete draft at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = DraftExpenseRescue(
          initialFiles: const [
            {'role': 'public', 'path': 'one/expense-one/photo.jpg'},
            {'role': 'receipt', 'path': ''},
          ],
        );
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/expense-one',
          rescue: repo,
        );
        final scroll = find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first;
        final next = find.text('Siguiente');
        await tester.scrollUntilVisible(next, 300, scrollable: scroll);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(of: next, matching: find.byType(FilledButton)),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(repo.savedFiles, isNull);
        expect(find.text('Enviar a revisión'), findsNothing);
        final save = find.text('Guardar progreso');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repo.savedFiles, repo.initialFiles);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'receipt and later evidence stay separate and retain files on back',
    (tester) async {
      final files = <Json>[
        {'role': 'receipt', 'path': 'one/expense-one/receipt.pdf'},
        {'role': 'proof', 'path': 'one/expense-one/proof.pdf'},
        {'role': 'public', 'path': 'one/expense-one/photo.jpg'},
      ];
      final repo = DraftExpenseRescue(initialFiles: files);
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/expense-one',
        rescue: repo,
      );
      expect(find.text('Comprobante del gasto'), findsOneWidget);
      expect(find.text('Foto de evidencia'), findsNothing);
      expect(find.text('Evidencia del gasto realizado'), findsNothing);
      final next = find.text('Siguiente');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(repo.savedFiles, files);
      expect(find.text('Comprobante del gasto'), findsNothing);
      expect(find.text('Foto de evidencia'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Foto de evidencia')).dy,
        lessThan(
          tester.getTopLeft(find.text('Evidencia del gasto realizado')).dy,
        ),
      );
      expect(find.text('Evidencia del gasto realizado'), findsOneWidget);
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
      final back = find.byTooltip('Paso anterior');
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('Comprobante del gasto'), findsOneWidget);
      expect(find.text('Foto de evidencia'), findsNothing);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(repo.savedFiles, files);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expense resume discards stale record data on failure and reads corrections from the server',
    (tester) async {
      final repo = SubmittedExpenseRescue()..remoteStatus = 'submitted';
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/expense-one',
        rescue: repo,
      );
      expect(find.text('Evidencia del gasto'), findsOneWidget);
      expect(repo.detailReads, 1);
      repo.failDetail = true;
      resumeExpense(tester);
      await tester.pumpAndSettle();
      expect(repo.detailReads, 2);
      expect(
        find.byKey(const ValueKey('expense-review-amount_cents')),
        findsNothing,
      );
      repo.failDetail = false;
      repo.remoteStatus = 'changes_requested';
      final retry = find.text('Volver a intentar');
      await tester.scrollUntilVisible(
        retry,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repo.detailReads, 3);
      final edit = find.byTooltip('Editar Información para publicación');
      await tester.scrollUntilVisible(
        edit,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(edit, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a submitted expense shows its private record without edit actions or a fresh success notice',
    (tester) async {
      final repo = SubmittedExpenseRescue()..remoteStatus = 'submitted';
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/expense-one',
        rescue: repo,
      );
      final review = find.byKey(const ValueKey('expense-review-amount_cents'));
      await tester.scrollUntilVisible(
        review,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(review).data, '123.45');
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Has subido tu evidencia para revisión.'), findsNothing);
      expect(find.text('Guardar progreso'), findsNothing);
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'evidence confirmation waits for the actual submitted result and never follows a failed request',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = SubmittedExpenseRescue()..failSubmit = true;
      await startPublication(tester, FakeCommunity(), '/publish', rescue: repo);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push('/rescue/expense-one')
          .ignore();
      await tester.pumpAndSettle();
      final outer = find
          .descendant(
            of: find.byKey(const ValueKey('expense-form-body')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 3; i++) {
        final next = find.text('Siguiente');
        await tester.scrollUntilVisible(next, 300, scrollable: outer);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      final submit = find.text('Enviar a revisión');
      await tester.scrollUntilVisible(submit, 300, scrollable: outer);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Has subido tu evidencia para revisión.'), findsNothing);
      expect(find.text('Faltan comprobantes para enviar.'), findsOneWidget);
      repo.failSubmit = false;
      repo.pending = Completer<RescueRecord>();
      await tester.scrollUntilVisible(submit, 300, scrollable: outer);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Has subido tu evidencia para revisión.'), findsNothing);
      repo.pending!.complete(
        RescueRecord({
          ...repo.expenseRecord.data,
          'status': 'submitted',
          'owner_id': 'one',
        }),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Has subido tu evidencia para revisión.'),
        findsOneWidget,
      );
      expect(find.text('Enviar a revisión'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Entendido'),
        300,
        scrollable: outer,
      );
      await tester.pumpAndSettle();
      expect(find.text('Entendido'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Has subido tu evidencia para revisión.'), findsNothing);
      expect(repo.remoteStatus, 'submitted');
      expect(tester.takeException(), isNull);
    },
  );
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
      final next = find.text('Guardar progreso');
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
      expect(find.byKey(const ValueKey('expense-field-title')), findsNothing);
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
      resumeExpense(tester);
      await tester.pump();
      expect(tester.widget<TextField>(amount).controller!.text, '87.09');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapNext();
      expect(
        find.byKey(const ValueKey('expense-field-amount_cents')),
        findsNothing,
      );
      final description = find.byKey(
        const ValueKey('expense-field-description'),
      );
      await tester.scrollUntilVisible(
        description,
        -300,
        maxScrolls: 100,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(description, 'Recibió su consulta y tratamiento.');
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tapNext();
      expect(
        repo.publicSaved!['description'],
        'Recibió su consulta y tratamiento.',
      );
      expect(repo.saved!['amount_cents'], '8709');
      expect(repo.saved!['vendor'], 'Clínica');
      expect(repo.publicSaved!.containsKey('amount_cents'), isFalse);
      expect(repo.publicSaved!.containsKey('vendor'), isFalse);
      expect(repo.publicSaved!['category'], 'medicine');
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('expense-review-amount_cents')),
            )
            .data,
        '87.09',
      );
      final edit = find.byTooltip('Editar Solo para revisión privada');
      await tester.scrollUntilVisible(
        edit,
        -300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('expense-field-amount_cents')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('expense-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('expense-field-amount_cents')),
            )
            .controller!
            .text,
        '87.09',
      );
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
