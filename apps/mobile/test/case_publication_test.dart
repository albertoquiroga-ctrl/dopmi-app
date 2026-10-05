import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:dopmi_mobile/features/rescue/case_detail_layout.dart';
import 'package:dopmi_mobile/features/rescue/case_publication_need_editor.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication, tapPublication;
import 'rescue_test.dart' show FakeRescue;

class DraftCaseRescue extends FakeRescue {
  Json? publicSaved;
  List<RescueRecord> expenses = [];
  List<Json> privateSaves = [];
  final removed = <String>[];
  bool reject = false, rejectRemove = false;
  int submits = 0;
  RescueRecord? submitted;
  @override
  Future<Json> detail(String id) async => {
    'record': {
      ...caseRecord.data,
      'owner_id': 'one',
      'status': 'draft',
      'public_data':
          publicSaved ??
          {
            'pet_name': 'Mora',
            'species': 'dog',
            'sex': 'unknown',
            'size': 'medium',
            'age': 'Adulto',
            'story': 'Rescatada bajo la lluvia, ahora necesita recuperarse.',
            'city': 'Monterrey',
            'state': 'Nuevo León',
            'need': 'Cuidados y seguimiento',
          },
      'files': <Json>[
        {'role': 'public', 'path': 'one/case-one/photo.jpg'},
      ],
    },
    'history': <Json>[],
  };
  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async {
    if (kind == 'expense') return DataPage(expenses, expenses.length);
    return DataPage(
      submitted == null ? [] : [submitted!],
      submitted == null ? 0 : 1,
    );
  }

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
    final result = RescueRecord({
      ...?record?.data,
      'id': record?.id ?? '$kind-new',
      'kind': kind,
      'owner_id': 'one',
      'status': 'draft',
      'parent_id': parent ?? record?.parent,
      'public_data': publicData,
      'private_data': privateData,
      'files': files,
      'version': (record?.version ?? 0) + 1,
    });
    if (kind == 'case') {
      publicSaved = publicData;
    } else {
      privateSaves.add(privateData);
      expenses = [...expenses.where((item) => item.id != result.id), result];
    }
    return result;
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    expect(record.kind, 'case');
    submits++;
    if (reject) {
      throw const FormatException('No se pudo enviar. Reintenta.');
    }
    submitted = RescueRecord({
      ...record.data,
      'status': 'submitted',
      'version': record.version + 1,
    });
    return submitted!;
  }

  @override
  Future<void> removeDraftExpense(String id, int version) async {
    if (rejectRemove) {
      throw const FormatException(
        'El gasto cambió. Recarga antes de eliminar.',
      );
    }
    expect(version, expenses.singleWhere((item) => item.id == id).version);
    removed.add(id);
    expenses.removeWhere((item) => item.id == id);
  }
}

RescueRecord expenseFixture({String status = 'draft'}) => RescueRecord({
  'id': 'expense-draft',
  'kind': 'expense',
  'owner_id': 'one',
  'parent_id': 'case-one',
  'status': status,
  'version': 2,
  'approved_at': status == 'approved' ? '2026-09-01' : null,
  'public_data': {
    'title': 'Medicina prescrita',
    'category': 'medicine',
    'description': 'Tratamiento indicado por la veterinaria',
    'round_label': '',
  },
  'private_data': {
    'amount_cents': '12345',
    'paid_on': '2026-09-01',
    'vendor': 'Veterinaria Luna',
    'receipt_reference': 'A-42',
    'urgency_reason': '',
  },
  'files': <Json>[
    {'role': 'receipt', 'path': 'one/expense-draft/receipt.pdf'},
    {'role': 'proof', 'path': 'one/expense-draft/proof.pdf'},
  ],
});

void main() {
  for (final reject in [false, true]) {
    testWidgets('only actual case submission confirms success reject=$reject', (
      tester,
    ) async {
      final repo = DraftCaseRescue()..reject = reject;
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      expect(
        tester.widget<CaseDetailLayout>(find.byType(CaseDetailLayout)).preview,
        isTrue,
      );
      expect(find.text('Guardar caso'), findsNothing);
      expect(find.byTooltip('Volver').first, findsOneWidget);
      await tapPublication(tester, find.text('Enviar a revisión'));
      expect(repo.submits, 1);
      if (reject) {
        expect(find.text('Enviado a revisión'), findsNothing);
        expect(find.textContaining('No se pudo enviar'), findsOneWidget);
      } else {
        expect(find.text('Enviado a revisión'), findsOneWidget);
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Scaffold).first);
        expect(
          GoRouter.of(context).routeInformationProvider.value.uri.path,
          '/my-cases',
        );
        expect(repo.submitted!.status, 'submitted');
      }
      expect(repo.publicSaved!['pet_name'], 'Mora');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'paid expense edit persists only private child evidence and metadata',
    (tester) async {
      final repo = DraftCaseRescue()..expenses = [expenseFixture()];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Medicina prescrita'));
      expect(find.byType(CasePublicationNeedEditor), findsOneWidget);
      final amount = find.byKey(const ValueKey('publication-need-amount'));
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '250.50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tapPublication(tester, find.text('Guardar medicina'));
      expect(repo.expenses.single.privateData['amount_cents'], '25050');
      expect(repo.expenses.single.parent, 'case-one');
      expect(repo.expenses.single.files.length, 2);
      expect(repo.publicSaved!.containsKey('receipt_reference'), isFalse);
      expect(repo.publicSaved!.toString(), isNot(contains('receipt.pdf')));
      expect(repo.submits, 0);
      await tapPublication(tester, find.text('Continuar'));
      expect(repo.expenses.single.status, 'draft');
      expect(repo.submits, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a new expense cannot save without both actual evidence roles', (
    tester,
  ) async {
    final repo = DraftCaseRescue();
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/case-one',
      rescue: repo,
    );
    await tapPublication(tester, find.text('Continuar'));
    await tapPublication(tester, find.text('Medicina'));
    final save = find.widgetWithText(FilledButton, 'Guardar medicina');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tapPublication(tester, find.byTooltip('Cerrar'));
    expect(repo.expenses, isEmpty);
    expect(repo.privateSaves, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final reject in [false, true]) {
    testWidgets(
      'expense removal requires confirmation and server response reject=$reject',
      (tester) async {
        final repo = DraftCaseRescue()
          ..expenses = [expenseFixture()]
          ..rejectRemove = reject;
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/case-one',
          rescue: repo,
        );
        await tapPublication(tester, find.text('Continuar'));
        final remove = find.byKey(
          const ValueKey('case-remove-expense-expense-draft'),
        );
        await tapPublication(tester, remove);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(repo.removed, isEmpty);
        expect(repo.expenses.length, 1);
        await tapPublication(tester, remove);
        await tester.tap(find.widgetWithText(TextButton, 'Eliminar').last);
        await tester.pumpAndSettle();
        expect(repo.expenses.length, reject ? 1 : 0);
        expect(repo.removed.length, reject ? 0 : 1);
        if (reject) {
          expect(find.textContaining('El gasto cambió'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reviewed expense remains visible without destructive draft control',
    (tester) async {
      final repo = DraftCaseRescue()
        ..expenses = [expenseFixture(status: 'approved')];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      await tapPublication(tester, find.text('Continuar'));
      expect(find.text('Medicina prescrita'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('case-remove-expense-expense-draft')),
        findsNothing,
      );
      expect(repo.removed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('case Back traverses steps and keeps already saved form values', (
    tester,
  ) async {
    final repo = DraftCaseRescue();
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/case-one',
      rescue: repo,
    );
    final name = find.byKey(const ValueKey('case-field-pet_name'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Mora corregida');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapPublication(tester, find.text('Continuar'));
    await tapPublication(tester, find.text('Continuar'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿En qué necesitaron apoyo?').first, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, 'Mora corregida');
    expect(repo.publicSaved!['pet_name'], 'Mora corregida');
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'case native picker cancellation keeps private draft at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = DraftCaseRescue();
        final sources = <int>[];
        const channel = MethodChannel('plugins.flutter.io/image_picker');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'pickImage') return null;
          final args = Map<String, dynamic>.from(call.arguments as Map);
          sources.add(args['source'] as int);
          expect(args['requestFullMetadata'], isFalse);
          expect(repo.publicSaved, isNotNull);
          expect(
            (await SharedPreferences.getInstance()).getString(
              pendingPhotoKey('one'),
            ),
            'rescue:case-one',
          );
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/case-one',
          rescue: repo,
        );
        for (final label in ['Tomar foto', 'Elegir de la galería']) {
          await tapPublication(
            tester,
            find.byTooltip('Editar foto de la mascota'),
          );
          await tapPublication(tester, find.text(label));
        }
        expect(sources, [0, 1]);
        expect(
          (await SharedPreferences.getInstance()).getString(
            pendingPhotoKey('one'),
          ),
          isNull,
        );
        expect(
          tester
              .widget<PublicationFooter>(find.byType(PublicationFooter))
              .onContinue,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a new case cannot continue without a principal photo and required profile',
    (tester) async {
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/new?kind=case',
        rescue: DraftCaseRescue(),
      );
      final footer = tester.widget<PublicationFooter>(
        find.byType(PublicationFooter),
      );
      expect(footer.onContinue, isNull);
      expect(footer.onSave, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
