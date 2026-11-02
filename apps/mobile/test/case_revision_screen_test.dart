import 'dart:async';

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/rescue/case_revision.dart';
import 'package:dopmi_mobile/features/rescue/case_revision_screen.dart';
import 'package:dopmi_mobile/features/rescue/case_review.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart'
    show RescueEditorScreen;
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

Json revisionData({
  String status = 'draft',
  String reason = '',
  int version = 1,
}) {
  final base = <String, dynamic>{
    'id': 'case-one',
    'kind': 'case',
    'owner_id': 'one',
    'status': 'approved',
    'version': 3,
    'approximate_latitude': 25.7,
    'approximate_longitude': -100.3,
    'public_data': {
      'pet_name': 'Mora',
      'species': 'dog',
      'sex': 'female',
      'age': 'Senior',
      'size': 'medium',
      'story': 'Una historia aprobada que debe seguir disponible.',
      'city': 'Monterrey',
      'state': 'Nuevo León',
      'need': 'Cuidados',
    },
    'private_data': <String, dynamic>{},
    'files': <Json>[],
  };
  return {
    'revision': {
      'id': 'revision-one',
      'case_id': 'case-one',
      'owner_id': 'one',
      'base_case_version': 3,
      'version': version,
      'status': status,
      'reason': reason,
    },
    'record': base,
    'base_record': base,
    'case_unit': <String, dynamic>{},
    'need_comments': <Json>[],
    'expenses': {
      'total': 2,
      'page': 1,
      'items': [
        for (final locked in [true, false])
          {
            'id': locked ? 'expense-locked' : 'expense-editable',
            'parent_id': 'case-one',
            'kind': 'expense',
            'owner_id': 'one',
            'status': 'approved',
            'version': 2,
            'financial_locked': locked,
            'locked_fields': locked
                ? [
                    'amount_cents',
                    'paid_on',
                    'vendor',
                    'receipt_reference',
                    'files',
                  ]
                : <String>[],
            'funded_cents': locked ? 2500 : 0,
            'public_data': {
              'title': locked ? 'Consulta financiada' : 'Medicina prescrita',
              'category': 'medicine',
              'description': 'Tratamiento documentado',
              'round_label': '',
            },
            'private_data': {
              'amount_cents': '10000',
              'paid_on': '2026-11-01',
              'vendor': 'Clínica',
              'receipt_reference': 'A-1',
              'urgency_reason': '',
            },
            'files': <Json>[],
          },
      ],
    },
  };
}

class RevisionRescue extends FakeRescue {
  Json data = revisionData();
  bool exists = true, failSubmitOnce = false, failSaveOnce = false;
  final starts = <String>[];
  final saves = <Json>[];
  final transitions = <Json>[];
  Completer<void>? saveBarrier;
  @override
  Future<Json> detail(String id) async => {
    'record': data['base_record'],
    'history': <Json>[],
  };
  @override
  Future<CaseRevisionPacket?> caseRevision(String id) async =>
      exists ? CaseRevisionPacket(data) : null;
  @override
  Future<CaseRevisionPacket> startCaseRevision(
    RescueRecord record,
    String requestId,
  ) async {
    starts.add(requestId);
    exists = true;
    expect(record.version, 3);
    if (['approved', 'invalidated'].contains(data['revision']['status'])) {
      data = {
        ...data,
        'revision': {
          ...Json.from(data['revision']),
          'id': 'revision-next',
          'status': 'draft',
          'version': 1,
          'reason': '',
        },
      };
    }
    return CaseRevisionPacket(data);
  }

  @override
  Future<CaseRevisionPacket> saveCaseRevision({
    required String id,
    required int version,
    required String reason,
    required Json caseFields,
    required List<Json> expenseFields,
    required String requestId,
  }) async {
    saves.add({
      'id': id,
      'version': version,
      'reason': reason,
      'case_fields': caseFields,
      'expense_fields': expenseFields,
      'request_id': requestId,
    });
    if (saveBarrier != null) await saveBarrier!.future;
    if (failSaveOnce) {
      failSaveOnce = false;
      throw Exception('Respuesta perdida');
    }
    final oldExpenses = (data['expenses'] as Map)['items'] as List;
    data = {
      ...data,
      'revision': {
        ...Json.from(data['revision']),
        'version': version + 1,
        'reason': reason,
        'status': 'draft',
      },
      'record': {...Json.from(data['record']), ...caseFields},
      'expenses': {
        'total': expenseFields.length,
        'page': 1,
        'items': [
          for (final fields in expenseFields)
            {
              ...Json.from(
                oldExpenses.firstWhere((old) => old['id'] == fields['id']),
              ),
              ...fields,
            },
        ],
      },
    };
    return CaseRevisionPacket(data);
  }

  @override
  Future<CaseRevisionPacket> transitionCaseRevision(
    CaseRevisionPacket packet,
    String action,
    String requestId,
  ) async {
    transitions.add({
      'action': action,
      'request_id': requestId,
      'version': packet.version,
    });
    if (failSubmitOnce) {
      failSubmitOnce = false;
      throw Exception('Respuesta perdida');
    }
    data = {
      ...data,
      'revision': {
        ...Json.from(data['revision']),
        'version': packet.version + 1,
        'status': action == 'submit' ? 'submitted' : 'draft',
      },
    };
    return CaseRevisionPacket(data);
  }
}

Future<void> revealRevision(
  WidgetTester tester,
  Finder finder, {
  Finder? scope,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final scrollable = find
      .descendant(
        of: scope ?? find.byType(CaseRevisionScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var step = 0; step < 40 && finder.evaluate().isEmpty; step++) {
      final position = tester.state<ScrollableState>(scrollable).position;
      final next = (position.pixels + position.viewportDimension * .8)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (next == position.pixels) break;
      position.jumpTo(next);
      await tester.pumpAndSettle();
    }
  }
  expect(
    finder,
    findsOneWidget,
    reason: 'The bounded outer scroll must build the destination.',
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapRevision(
  WidgetTester tester,
  Finder finder, {
  Finder? scope,
}) async {
  await revealRevision(tester, finder, scope: scope);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class RevisionSession extends FakeCommunity {
  String currentActor = 'one';
  @override
  String? get userId => currentActor;
}

class RecoveryRevisionRescue extends RevisionRescue {
  RecoveryRevisionRescue() {
    data = revisionData(
      status: 'invalidated',
      reason: 'La publicación requiere correcciones.',
    );
    final withdrawn = {
      ...Json.from(data['base_record']),
      'status': 'changes_requested',
      'feedback': 'Corrige la historia y conserva los comprobantes.',
    };
    data = {
      ...data,
      'record': withdrawn,
      'base_record': withdrawn,
      'case_unit': {
        'case_status': 'changes_requested',
        'case_archived': false,
        'ever_approved': true,
        'revision_recovery': true,
        'can_start_revision': true,
        'public_version_visible': false,
      },
    };
  }
  @override
  Future<Json> detail(String id) async => {
    'record': data['base_record'],
    'case_unit': data['case_unit'],
    'history': <Json>[],
  };
  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async => kind == 'expense'
      ? DataPage(CaseRevisionPacket(data).expenses, 2)
      : super.mine(kind, page, parent: parent);
}

class BlockedThanksVideos extends VideoRepository {
  BlockedThanksVideos()
    : super(
        identity: () => 'one:session',
        invoke: (_) async =>
            throw StateError('No uploads or camera actions in this test'),
      );
  final policyParents = <String>[];
  @override
  Future<VideoPolicy> policy(String parentId) async {
    policyParents.add(parentId);
    return VideoPolicy(
      enabled: true,
      thanksRequired: true,
      assets: [
        {
          'id': 'existing-thanks',
          'parent_id': 'case-one',
          'parent_version': 3,
          'purpose': 'thanks',
          'technical_state': 'failed',
          'moderation_state': 'pending',
          'matches_current_content': true,
          'request_key': 'existing-thanks-key',
          'bytes': 3,
        },
      ],
    );
  }
}

void main() {
  testWidgets(
    'blocked recovery withdraws before managing thanks on the real hidden case',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final rescue = RecoveryRevisionRescue();
      rescue.data = {
        ...rescue.data,
        'revision': {
          ...Json.from(rescue.data['revision']),
          'status': 'submitted',
        },
        'record': {
          ...Json.from(rescue.data['record']),
          'public_data': {
            ...Json.from(rescue.data['record']['public_data']),
            'pet_name': 'Propuesta privada de Mora',
          },
        },
        'case_unit': {
          ...Json.from(rescue.data['case_unit']),
          'case_version': 3,
        },
        'publication_blockers': ['approved_thanks_required'],
      };
      final videos = BlockedThanksVideos();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue-cases/case-one/edit',
        rescue: rescue,
        videos: videos,
      );
      expect(find.byType(RescueVideoSection), findsNothing);
      expect(videos.policyParents, isEmpty);
      await tapRevision(
        tester,
        find.text('Retirar edición para gestionar video'),
      );
      expect(rescue.transitions.single['action'], 'withdraw');
      expect(rescue.data['base_record']['status'], 'changes_requested');
      expect(rescue.data['case_unit']['public_version_visible'], isFalse);
      await tapRevision(tester, find.text('Gestionar video de agradecimiento'));
      final section = tester.widget<RescueVideoSection>(
        find.byType(RescueVideoSection),
      );
      expect(section.record!.id, 'case-one');
      expect(section.record!.version, 3);
      expect(section.record!.title, 'Mora');
      expect(section.record!.status, 'changes_requested');
      expect(section.purposes, ['thanks']);
      expect(section.enabled, isTrue);
      final upload = tester.widget<VideoUpload>(find.byType(VideoUpload));
      expect(upload.parentId, 'case-one');
      expect(upload.parentVersion, 3);
      expect(upload.initialAssets.single['id'], 'existing-thanks');
      expect(videos.policyParents, ['case-one']);
      expect(find.text('Cancelar video'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Cancelar video'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.textContaining('La publicación permanece retirada.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('vuelve a enviar la edición completa'),
        findsWidgets,
      );
      final close = find.text('Volver a la edición');
      await tester.ensureVisible(close);
      await tester.pumpAndSettle();
      expect(close.hitTestable(), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(rescue.saves, isEmpty);
      expect(rescue.transitions, hasLength(1));
      expect(rescue.data['base_record']['status'], 'changes_requested');
      expect(rescue.data['case_unit']['public_version_visible'], isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'withdrawn published case recovers through a complete private revision and stays hidden until approval',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final rescue = RecoveryRevisionRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: rescue,
      );
      expect(find.byType(PublicationFrame), findsNothing);
      await tapRevision(
        tester,
        find.text('Corregir caso completo'),
        scope: find.byType(RescueEditorScreen),
      );
      expect(find.byType(CaseRevisionScreen), findsOneWidget);
      expect(rescue.starts, isEmpty);
      expect(
        find.textContaining('La publicación está retirada.'),
        findsOneWidget,
      );
      expect(find.textContaining('permanece publicada'), findsNothing);
      await tapRevision(tester, find.text('Iniciar otra edición'));
      expect(rescue.starts, hasLength(1));
      final reason = find.byKey(const ValueKey('case-revision-reason'));
      await revealRevision(tester, reason);
      await tester.enterText(
        reason,
        'Corregí la historia de acuerdo con la respuesta del equipo.',
      );
      await tapRevision(tester, find.text('Revisar edición completa'));
      await tapRevision(tester, find.text('Enviar edición completa'));
      await revealRevision(
        tester,
        find.text(
          'Edición completa enviada a revisión. La publicación permanece retirada.',
        ),
      );
      expect(rescue.transitions.single['action'], 'submit');
      expect(rescue.data['base_record']['status'], 'changes_requested');
      expect(rescue.data['case_unit']['public_version_visible'], isFalse);
      expect(
        (rescue.saves.single['expense_fields'] as List).map(
          (need) => need['id'],
        ),
        ['expense-locked', 'expense-editable'],
      );
      await tapRevision(tester, find.text('Retirar edición a borrador'));
      await revealRevision(
        tester,
        find.text(
          'Edición retirada a borrador privado. La publicación permanece retirada.',
        ),
      );
      expect(rescue.transitions.map((transition) => transition['action']), [
        'submit',
        'withdraw',
      ]);
      expect(rescue.data['case_unit']['public_version_visible'], isFalse);
      expect(
        find.textContaining('La versión aprobada sigue publicada.'),
        findsNothing,
      );
      rescue.data = {
        ...rescue.data,
        'revision': {
          ...Json.from(rescue.data['revision']),
          'status': 'invalidated',
        },
        'case_unit': {
          ...Json.from(rescue.data['case_unit']),
          'case_status': 'closed',
          'can_start_revision': false,
          'revision_recovery': false,
        },
      };
      await tapRevision(tester, find.text('Recargar edición'));
      await revealRevision(tester, find.text('Recargar edición'));
      expect(find.text('Iniciar otra edición'), findsNothing);
      expect(rescue.starts, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editing requires reason, preserves all need IDs and honors funded amount lock',
    (tester) async {
      final rescue = RevisionRescue()..exists = false;
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue-cases/case-one/edit',
        rescue: rescue,
      );
      expect(find.byType(CaseRevisionScreen), findsOneWidget);
      expect(find.byType(PublicationFrame), findsNothing);
      expect(rescue.starts, hasLength(1));
      final reason = find.byKey(const ValueKey('case-revision-reason'));
      await tester.enterText(reason, 'abc');
      await revealRevision(tester, find.text('Revisar edición completa'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Revisar edición completa'),
            )
            .onPressed,
        isNull,
      );
      expect(rescue.saves, isEmpty);
      await revealRevision(tester, reason);
      await tester.enterText(
        reason,
        'Corregí la historia y el importe documentado.',
      );
      await revealRevision(
        tester,
        find.byKey(const ValueKey('case-field-pet_name')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('case-field-pet_name')),
        'Mora corregida',
      );
      final locked = find.byKey(const ValueKey('revision-need-expense-locked'));
      await revealRevision(tester, find.text('Consulta financiada'));
      await tapRevision(tester, find.text('Consulta financiada'));
      await tester.pumpAndSettle();
      final lockedAmount = find.descendant(
        of: locked,
        matching: find.byKey(const ValueKey('expense-field-amount_cents')),
      );
      expect(tester.widget<TextField>(lockedAmount).enabled, isFalse);
      final editable = find.byKey(
        const ValueKey('revision-need-expense-editable'),
      );
      await revealRevision(tester, find.text('Medicina prescrita'));
      await tapRevision(tester, find.text('Medicina prescrita'));
      await tester.pumpAndSettle();
      final amount = find.descendant(
        of: editable,
        matching: find.byKey(const ValueKey('expense-field-amount_cents')),
      );
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '150.25');
      await revealRevision(tester, find.text('Guardar borrador privado'));
      await tapRevision(tester, find.text('Guardar borrador privado'));
      final saved = rescue.saves.single;
      expect(saved['reason'], 'Corregí la historia y el importe documentado.');
      expect(
        (saved['case_fields']['public_data'] as Map)['pet_name'],
        'Mora corregida',
      );
      expect(saved['case_fields']['public_data']['approximate_latitude'], 25.7);
      expect(
        saved['case_fields']['public_data']['approximate_longitude'],
        -100.3,
      );
      expect(
        saved['case_fields']['public_data']['location_precision_version'],
        1,
      );
      final expenses = saved['expense_fields'] as List;
      expect(expenses.map((expense) => expense['id']), [
        'expense-locked',
        'expense-editable',
      ]);
      expect(expenses.first['private_data']['amount_cents'], '10000');
      expect(expenses.last['private_data']['amount_cents'], '15025');
      expect((expenses.first as Map).keys.toSet(), {
        'id',
        'public_data',
        'private_data',
        'files',
      });
      expect(rescue.data['base_record']['public_data']['pet_name'], 'Mora');
      expect(find.text('Registrar gasto realizado'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'whole revision submits and withdraws while the public version stays approved at 320px 200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final rescue = RevisionRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue-cases/case-one/edit',
        rescue: rescue,
      );
      await revealRevision(
        tester,
        find.byKey(const ValueKey('case-revision-reason')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('case-revision-reason')),
        'Corregí el texto por indicación del equipo.',
      );
      await revealRevision(tester, find.text('Revisar edición completa'));
      await tapRevision(tester, find.text('Revisar edición completa'));
      await revealRevision(tester, find.byType(CaseReview));
      expect(find.byType(CaseReview), findsOneWidget);
      await revealRevision(tester, find.text('Enviar edición completa'));
      await tapRevision(tester, find.text('Enviar edición completa'));
      expect(rescue.transitions.single['action'], 'submit');
      expect(rescue.data['base_record']['status'], 'approved');
      expect(rescue.data['base_record']['public_data']['pet_name'], 'Mora');
      await revealRevision(tester, find.text('Retirar edición a borrador'));
      await tapRevision(tester, find.text('Retirar edición a borrador'));
      expect(rescue.transitions.map((transition) => transition['action']), [
        'submit',
        'withdraw',
      ]);
      expect(rescue.data['base_record']['status'], 'approved');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ambiguous save freezes editing and retries the same payload and request',
    (tester) async {
      final rescue = RevisionRescue()..failSaveOnce = true;
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue-cases/case-one/edit',
        rescue: rescue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('case-revision-reason')),
        'Corrección documentada de la historia.',
      );
      await revealRevision(tester, find.text('Guardar borrador privado'));
      await tapRevision(tester, find.text('Guardar borrador privado'));
      await tapRevision(tester, find.text('Reintentar el mismo guardado'));
      expect(rescue.saves, hasLength(2));
      expect(rescue.saves.first, rescue.saves.last);
      expect(rescue.transitions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ambiguous submission retries the same revision and request', (
    tester,
  ) async {
    final rescue = RevisionRescue()..failSubmitOnce = true;
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue-cases/case-one/edit',
      rescue: rescue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('case-revision-reason')),
      'Corrección documentada de la historia.',
    );
    await revealRevision(tester, find.text('Revisar edición completa'));
    await tapRevision(tester, find.text('Revisar edición completa'));
    await revealRevision(tester, find.text('Enviar edición completa'));
    await tapRevision(tester, find.text('Enviar edición completa'));
    await tapRevision(tester, find.text('Reintentar el mismo envío'));
    expect(rescue.transitions, hasLength(2));
    expect(rescue.transitions.first, rescue.transitions.last);
    expect(rescue.saves, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  test('incomplete revision packet cannot drop a need during saving', () {
    final data = revisionData();
    data['expenses'] = {...Json.from(data['expenses']), 'total': 3};
    expect(() => CaseRevisionPacket(data), throwsFormatException);
  });

  testWidgets(
    'consulting an approved revision does not create a new draft until explicitly requested',
    (tester) async {
      final rescue = RevisionRescue()
        ..data = revisionData(
          status: 'approved',
          reason: 'Edición ya aprobada.',
        );
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue-cases/case-one/edit',
        rescue: rescue,
      );
      expect(rescue.starts, isEmpty);
      await revealRevision(tester, find.text('Recargar edición'));
      await tapRevision(tester, find.text('Recargar edición'));
      expect(rescue.starts, isEmpty);
      await revealRevision(tester, find.text('Iniciar otra edición'));
      await tapRevision(tester, find.text('Iniciar otra edición'));
      expect(rescue.starts, hasLength(1));
      expect(rescue.data['revision']['status'], 'draft');
      expect(rescue.saves, isEmpty);
      expect(rescue.transitions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a late save result cannot expose the old account revision after a session change',
    (tester) async {
      final session = RevisionSession();
      final barrier = Completer<void>();
      final rescue = RevisionRescue()..saveBarrier = barrier;
      await startPublication(
        tester,
        session,
        '/rescue-cases/case-one/edit',
        rescue: rescue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('case-revision-reason')),
        'Corrección privada del caso de esta cuenta.',
      );
      await revealRevision(tester, find.text('Guardar borrador privado'));
      expect(
        find.text('Guardar borrador privado').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Guardar borrador privado'));
      await tester.pump();
      expect(rescue.saves, hasLength(1));
      session.currentActor = 'other-account';
      barrier.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('La sesión cambió. Retoma la edición con su cuenta.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('case-revision-reason')), findsNothing);
      expect(find.text('Consulta financiada'), findsNothing);
      expect(rescue.transitions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
