import 'dart:async';

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_publication_need_editor.dart';
import 'package:dopmi_mobile/features/rescue/expense_evidence_card.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

const completeExpenseFiles = <Json>[
  {'role': 'receipt', 'path': 'one/expense-one/receipt.pdf'},
  {'role': 'proof', 'path': 'one/expense-one/proof.pdf'},
];

class DraftExpenseRescue extends FakeRescue {
  DraftExpenseRescue({
    this.initialDescription = 'Recibió su consulta veterinaria.',
    this.initialFiles = completeExpenseFiles,
  });
  final List<Json> initialFiles;
  final String initialDescription;
  List<Json>? savedFiles;
  Json? publicSaved;
  String? savedParent;
  RescueRecord? editorResult;
  bool failSave = false;
  final transitions = <String>[];

  RescueRecord get draftRecord => RescueRecord({
    ...expenseRecord.data,
    'owner_id': 'one',
    'status': 'draft',
    'target_cents': 0,
    'funded_cents': 0,
    'reimbursable_cents': 0,
    'private_data': {
      'amount_cents': 12345,
      'vendor': 'Clínica',
      'paid_on': '2026-10-01',
      'receipt_reference': 'PRIVADO-123',
    },
    'public_data': {
      'title': 'Consulta',
      'category': 'medicine',
      'description': initialDescription,
    },
    'files': initialFiles,
  });

  @override
  Future<Json> detail(String id) async => {
    'record': draftRecord.data,
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
    saveCalls++;
    if (failSave) {
      throw const FormatException('No pudimos guardar el gasto privado.');
    }
    savedFiles = files.map((file) => Json.from(file)).toList();
    saved = privateData;
    publicSaved = publicData;
    savedParent = parent;
    return RescueRecord({
      ...record!.data,
      'public_data': publicData,
      'private_data': privateData,
      'files': files,
      'version': record.version + 1,
    });
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    transitions.add(action);
    throw StateError('Las necesidades se envían junto con su caso.');
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
  bool failDetail = false;
  int detailReads = 0;
  String remoteStatus = 'draft';
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
}

class ExpenseDraftVideos extends VideoRepository {
  ExpenseDraftVideos()
    : super(
        identity: () => 'one:fixture',
        invoke: (_) async =>
            throw StateError('No se cargan videos en esta prueba'),
      );

  @override
  Future<VideoPolicy> policy(String parentId) async =>
      const VideoPolicy(enabled: true, thanksRequired: false, assets: []);
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

void expenseViewport(WidgetTester tester, double scale) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> mountPrivateNeed(
  WidgetTester tester,
  DraftExpenseRescue repo, {
  bool videos = false,
}) async {
  final videoRepo = videos ? ExpenseDraftVideos() : null;
  if (videoRepo != null) addTearDown(videoRepo.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(repo),
        rescueVideosRepositoryProvider.overrideWithValue(videoRepo),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await showDialog<RescueRecord>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => CasePublicationNeedEditor(
                    caseId: 'case-one',
                    type: 'medicine',
                    record: repo.editorResult ?? repo.draftRecord,
                  ),
                );
                if (result != null) repo.editorResult = result;
              },
              child: const Text('Editar necesidad del caso'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Editar necesidad del caso'));
  await tester.pumpAndSettle();
}

Future<void> revealNeed(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> tapNeed(WidgetTester tester, Finder target) async {
  await revealNeed(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enterNeed(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey('publication-need-$key'));
  await revealNeed(tester, field);
  await tester.enterText(field, text);
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Finder needSave() => find.widgetWithText(FilledButton, 'Guardar medicina');

void expectPrivateNeed(DraftExpenseRescue repo) {
  expect(repo.savedParent, 'case-one');
  expect(repo.editorResult?.id, 'expense-one');
  expect(repo.editorResult?.status, 'draft');
  expect(repo.editorResult?.data['target_cents'], 0);
  expect(repo.editorResult?.data['reimbursable_cents'], 0);
  expect(repo.transitions, isEmpty);
  for (final key in [
    'vendor',
    'amount_cents',
    'paid_on',
    'receipt_reference',
    'urgency_reason',
  ]) {
    expect(repo.publicSaved!.containsKey(key), isFalse);
  }
  expect(repo.publicSaved.toString(), isNot(contains('receipt.pdf')));
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'case need edits description and files without losing private data at $scale',
      (tester) async {
        expenseViewport(tester, scale);
        final files = <Json>[
          ...completeExpenseFiles,
          {'role': 'public', 'path': 'one/expense-one/photo.pdf'},
        ];
        final repo = DraftExpenseRescue(initialFiles: files);
        await mountPrivateNeed(tester, repo);
        await enterNeed(
          tester,
          'description',
          'Consulta y tratamiento completados.',
        );
        await tapNeed(tester, needSave());
        expect(find.byType(CasePublicationNeedEditor), findsNothing);
        expect(
          repo.publicSaved!['description'],
          'Consulta y tratamiento completados.',
        );
        expect(repo.saved!['vendor'], 'Clínica');
        expect(repo.saved!['amount_cents'], '12345');
        expect(repo.saved!['paid_on'], '2026-10-01');
        expect(repo.saved!['receipt_reference'], 'PRIVADO-123');
        expect(repo.savedFiles, files);
        expectPrivateNeed(repo);
        await tester.tap(find.text('Editar necesidad del caso'));
        await tester.pumpAndSettle();
        final description = find.byKey(
          const ValueKey('publication-need-description'),
        );
        await revealNeed(tester, description);
        expect(
          tester.widget<TextField>(description).controller!.text,
          'Consulta y tratamiento completados.',
        );
        await tapNeed(tester, needSave());
        expect(repo.savedFiles, files);
        expect(repo.editorResult!.version, repo.draftRecord.version + 2);
        expectPrivateNeed(repo);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('private need stays busy until its save response at $scale', (
      tester,
    ) async {
      expenseViewport(tester, scale);
      final repo = DelayedExpenseRescue();
      await mountPrivateNeed(tester, repo);
      await revealNeed(tester, needSave());
      await tester.tap(needSave());
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CasePublicationNeedEditor), findsOneWidget);
      expect(repo.editorResult, isNull);
      expect(repo.savedFiles, isNull);
      final busySave = find.widgetWithText(FilledButton, 'Guardando...');
      expect(tester.widget<FilledButton>(busySave).onPressed, isNull);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Cerrar',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(repo.transitions, isEmpty);
      repo.response.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CasePublicationNeedEditor), findsNothing);
      expect(repo.savedFiles, repo.initialFiles);
      expectPrivateNeed(repo);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'description gates complete need while incomplete draft remains private at $scale',
      (tester) async {
        expenseViewport(tester, scale);
        final repo = DraftExpenseRescue(initialDescription: '   ');
        await mountPrivateNeed(tester, repo, videos: true);
        expect(tester.widget<FilledButton>(needSave()).onPressed, isNull);
        await enterNeed(tester, 'description', 'Recibió su tratamiento.');
        expect(tester.widget<FilledButton>(needSave()).onPressed, isNotNull);
        await enterNeed(tester, 'description', '');
        expect(tester.widget<FilledButton>(needSave()).onPressed, isNull);
        await tapNeed(tester, find.text('Guardar borrador para añadir videos'));
        expect(find.byType(CasePublicationNeedEditor), findsOneWidget);
        expect(repo.publicSaved!['description'], '');
        expect(repo.savedFiles, repo.initialFiles);
        expect(repo.saved!['amount_cents'], '12345');
        expect(repo.savedParent, 'case-one');
        expect(repo.editorResult, isNull);
        expect(repo.transitions, isEmpty);
        expect(find.text('Enviar a revisión'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'missing receipt gates complete need but permits private draft save at $scale',
      (tester) async {
        expenseViewport(tester, scale);
        final repo = DraftExpenseRescue(
          initialFiles: const [
            {'role': 'public', 'path': 'one/expense-one/photo.pdf'},
            {'role': 'proof', 'path': 'one/expense-one/proof.pdf'},
          ],
        );
        await mountPrivateNeed(tester, repo, videos: true);
        await enterNeed(tester, 'title', 'Consulta parcial');
        await revealNeed(tester, needSave());
        expect(tester.widget<FilledButton>(needSave()).onPressed, isNull);
        expect(repo.savedFiles, isNull);
        await tapNeed(tester, find.text('Guardar borrador para añadir videos'));
        expect(repo.savedFiles, repo.initialFiles);
        expect(repo.savedParent, 'case-one');
        expect(repo.transitions, isEmpty);
        expect(find.byType(CasePublicationNeedEditor), findsOneWidget);
        expect(tester.widget<FilledButton>(needSave()).onPressed, isNull);
        expect(find.text('Enviar a revisión'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'receipt and proof are separate private controls and retain other file roles',
    (tester) async {
      final files = <Json>[
        ...completeExpenseFiles,
        {'role': 'public', 'path': 'one/expense-one/photo.pdf'},
      ];
      final repo = DraftExpenseRescue(initialFiles: files);
      await mountPrivateNeed(tester, repo);
      final cards = tester
          .widgetList<ExpenseEvidenceCard>(find.byType(ExpenseEvidenceCard))
          .toList();
      expect(cards, hasLength(2));
      expect(cards[0].title, 'Foto de Recibo *');
      expect(cards[0].fileIndexes, [0]);
      expect(cards[1].title, 'Foto de Evidencia *');
      expect(cards[1].fileIndexes, [1]);
      expect(cards.every((card) => !card.public), isTrue);
      expect(cards.every((card) => card.onRemove != null), isTrue);
      expect(cards.every((card) => card.onAttach != null), isTrue);
      await tapNeed(tester, needSave());
      expect(repo.savedFiles, files);
      expectPrivateNeed(repo);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expense resume discards stale data and returned need stays consultation only',
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
      expect(
        find.byTooltip('Editar Información para publicación'),
        findsNothing,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Guardar progreso'), findsNothing);
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(repo.saveCalls, 0);
      expect(repo.transitions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a submitted expense shows its private record without edit actions or success notice',
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
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Has subido tu evidencia para revisión.'), findsNothing);
      expect(find.text('Guardar progreso'), findsNothing);
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(repo.saveCalls, 0);
      expect(repo.transitions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed need save preserves editor and retry only saves the private case draft',
    (tester) async {
      expenseViewport(tester, 2);
      final repo = DraftExpenseRescue()..failSave = true;
      await mountPrivateNeed(tester, repo);
      expect(find.text('Enviar a revisión'), findsNothing);
      await tapNeed(tester, needSave());
      expect(find.byType(CasePublicationNeedEditor), findsOneWidget);
      expect(repo.editorResult, isNull);
      expect(repo.savedFiles, isNull);
      expect(repo.saveCalls, 1);
      await revealNeed(
        tester,
        find.text('No pudimos guardar el gasto privado.'),
      );
      expect(find.text('Has subido tu evidencia para revisión.'), findsNothing);
      expect(repo.transitions, isEmpty);
      repo.failSave = false;
      await tapNeed(tester, needSave());
      expect(repo.saveCalls, 2);
      expect(find.byType(CasePublicationNeedEditor), findsNothing);
      expectPrivateNeed(repo);
      expect(find.text('Has subido tu evidencia para revisión.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing need leaves persisted draft intact until a successful private save',
    (tester) async {
      final repo = DraftExpenseRescue();
      await mountPrivateNeed(tester, repo);
      await enterNeed(tester, 'title', 'Consulta sin guardar');
      await tapNeed(tester, find.byTooltip('Cerrar'));
      expect(find.byType(CasePublicationNeedEditor), findsNothing);
      expect(repo.saveCalls, 0);
      expect(repo.editorResult, isNull);
      await tester.tap(find.text('Editar necesidad del caso'));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('publication-need-title'));
      expect(tester.widget<TextField>(title).controller!.text, 'Consulta');
      await enterNeed(tester, 'title', 'Consulta corregida');
      await tapNeed(tester, needSave());
      expect(repo.publicSaved!['title'], 'Consulta corregida');
      expect(repo.savedFiles, repo.initialFiles);
      expect(repo.saveCalls, 1);
      expectPrivateNeed(repo);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing private receipt preserves proof and public role in the saved draft',
    (tester) async {
      final repo = DraftExpenseRescue(
        initialFiles: [
          ...completeExpenseFiles,
          {'role': 'public', 'path': 'one/expense-one/photo.pdf'},
        ],
      );
      await mountPrivateNeed(tester, repo, videos: true);
      await tapNeed(tester, find.byTooltip('Quitar archivo 1'));
      expect(tester.widget<FilledButton>(needSave()).onPressed, isNull);
      await tapNeed(tester, find.text('Guardar borrador para añadir videos'));
      expect(repo.savedFiles, [
        {'role': 'proof', 'path': 'one/expense-one/proof.pdf'},
        {'role': 'public', 'path': 'one/expense-one/photo.pdf'},
      ]);
      expect(repo.publicSaved.toString(), isNot(contains('photo.pdf')));
      expect(repo.savedParent, 'case-one');
      expect(repo.transitions, isEmpty);
      expect(find.byType(CasePublicationNeedEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'case need retains private exact cents through resume and reopening at large text',
    (tester) async {
      expenseViewport(tester, 2);
      final repo = DraftExpenseRescue();
      await mountPrivateNeed(tester, repo);
      final amount = find.byKey(const ValueKey('publication-need-amount'));
      await revealNeed(tester, amount);
      expect(tester.widget<TextField>(amount).controller!.text, '123.45');
      await enterNeed(tester, 'amount', '87.09');
      resumeExpense(tester);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(amount).controller!.text, '87.09');
      await enterNeed(
        tester,
        'description',
        'Recibió su consulta y tratamiento.',
      );
      await tapNeed(tester, needSave());
      expect(repo.saved!['amount_cents'], '8709');
      expect(repo.saved!['vendor'], 'Clínica');
      expect(
        repo.publicSaved!['description'],
        'Recibió su consulta y tratamiento.',
      );
      expect(repo.publicSaved!['category'], 'medicine');
      expectPrivateNeed(repo);
      await tester.tap(find.text('Editar necesidad del caso'));
      await tester.pumpAndSettle();
      await revealNeed(tester, amount);
      expect(tester.widget<TextField>(amount).controller!.text, '87.09');
      await enterNeed(tester, 'amount', '87.099');
      expect(tester.widget<FilledButton>(needSave()).onPressed, isNull);
      expect(repo.saveCalls, 1);
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(repo.transitions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
