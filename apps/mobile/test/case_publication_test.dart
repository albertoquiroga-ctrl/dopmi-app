import 'dart:async';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:dopmi_mobile/features/rescue/case_detail_layout.dart';
import 'package:dopmi_mobile/features/rescue/case_needs.dart';
import 'package:dopmi_mobile/features/rescue/case_publication_need_editor.dart';
import 'package:dopmi_mobile/features/rescue/case_review.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:dopmi_mobile/features/rescue/urgency_complement.dart';
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
  final caseSaves = <RescueRecord>[];
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
      caseSaves.add(result);
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

class WizardVideos extends VideoRepository {
  WizardVideos(this.rescue)
    : super(
        identity: () => 'one:session',
        invoke: (_) async => throw const VideoFailure('unexpected_upload'),
      );
  final DraftCaseRescue rescue;
  bool enabled = false,
      requiredThanks = true,
      matches = true,
      failPolicy = false;
  String? state, urgencyState;
  String moderation = 'pending';
  final policySnapshots = <Json>[];
  final statusReads = <String>[];
  final cancellations = <String>[];
  bool cancellationFails = false;
  Completer<void>? policyBarrier, cancellationBarrier;
  @override
  Future<VideoPolicy> policy(String parentId) async {
    if (policyBarrier != null) await policyBarrier!.future;
    if (failPolicy) throw const VideoFailure('policy_unavailable');
    policySnapshots.add(Map.of(rescue.publicSaved ?? {}));
    return VideoPolicy(
      enabled: enabled,
      thanksRequired: requiredThanks,
      urgencyAllowed: true,
      assets: [
        for (final item in [('thanks', state), ('urgency', urgencyState)])
          if (item.$2 != null)
            {
              'id': '${item.$1}-video',
              'parent_id': parentId,
              'parent_version': rescue.caseSaves.last.version,
              'purpose': item.$1,
              'technical_state': item.$2,
              'moderation_state': moderation,
              'matches_current_content': matches,
              'request_key': 'wizard-${item.$1}-video',
              'bytes': 3,
            },
      ],
    );
  }

  @override
  Future<VideoAsset> status(String assetId) async {
    statusReads.add(assetId);
    if (assetId == 'urgency-video') {
      urgencyState = 'ready';
    } else {
      state = 'ready';
    }
    return VideoAsset(id: assetId, state: 'ready', moderation: moderation);
  }

  @override
  Future<void> cancel(VideoUploadTask task) async {
    cancellations.add(task.assetId!);
    if (cancellationBarrier != null) await cancellationBarrier!.future;
    if (cancellationFails) {
      throw VideoCancellationPending(
        asset: VideoAsset(
          id: task.assetId!,
          state:
              (task.purpose == 'urgency' ? urgencyState : state) ??
              'processing',
          moderation: moderation,
        ),
      );
    }
    if (task.purpose == 'urgency') {
      urgencyState = null;
    } else {
      state = null;
    }
    task.cancel();
  }

  @override
  Future<VideoAsset> cancellationStatus(VideoUploadTask task) async {
    if (task.purpose == 'urgency') {
      urgencyState = null;
    } else {
      state = null;
    }
    return VideoAsset(
      id: task.assetId!,
      state: 'canceled',
      moderation: 'pending',
    );
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
  testWidgets(
    'gratitude publication selector opens real help without saving or uploading',
    (tester) async {
      final repo = DraftCaseRescue();
      final videos = WizardVideos(repo)..enabled = true;
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: videos,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      expect(find.byType(PublicationVideoPicker), findsOneWidget);
      final title = tester.widget<Text>(
        find.byKey(const ValueKey('publication-thanks-video-title')),
      );
      expect(title.textSpan!.toPlainText(), 'Video de agradecimiento *');
      expect(find.text('Agradecimiento'), findsNothing);
      final help = find.byKey(const ValueKey('publication-thanks-video-help'));
      for (final close in ['Entendido', 'Cerrar']) {
        await tapPublication(tester, help);
        expect(find.text('¿Por qué subir este video?'), findsOneWidget);
        for (final label in ['Confianza:', 'Gratitud:', 'Qué mostrar:']) {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.textSpan?.toPlainText().contains(label) ?? false),
            ),
            findsOneWidget,
          );
        }
        await tapPublication(
          tester,
          close == 'Cerrar' ? find.byTooltip('Cerrar').last : find.text(close),
        );
        expect(find.byType(Dialog), findsNothing);
      }
      expect(repo.caseSaves.length, 2);
      expect(repo.submits, 0);
      expect(videos.cancellations, isEmpty);
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'simultaneous gratitude and urgency processing keep recovery controls usable',
    (tester) async {
      final repo = DraftCaseRescue();
      final expense = expenseFixture();
      repo.expenses = [
        RescueRecord({
          ...expense.data,
          'private_data': {
            ...expense.privateData,
            'urgency_reason': 'Urgente TEST',
          },
        }),
      ];
      final videos = WizardVideos(repo)
        ..enabled = true
        ..state = 'processing'
        ..urgencyState = 'processing';
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: videos,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      expect(find.byType(VideoUpload), findsNWidgets(2));
      expect(
        tester
            .widgetList<RescueVideoSection>(find.byType(RescueVideoSection))
            .every((section) => section.enabled),
        isTrue,
      );
      expect(
        tester
            .widget<UrgencyComplement>(find.byType(UrgencyComplement))
            .enabled,
        isTrue,
      );
      for (final label in ['Comprobar video', 'Cancelar video']) {
        final controls = tester.widgetList<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(controls.length, 2);
        expect(controls.every((button) => button.onPressed != null), isTrue);
      }
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNull,
      );
      for (final purpose in ['thanks', 'urgency']) {
        final uploader = find.byWidgetPredicate(
          (widget) => widget is VideoUpload && widget.purpose == purpose,
        );
        await tapPublication(
          tester,
          find.descendant(of: uploader, matching: find.text('Comprobar video')),
        );
        if (purpose == 'thanks') {
          expect(
            tester
                .widget<PublicationFooter>(find.byType(PublicationFooter))
                .onContinue,
            isNull,
          );
        }
      }
      expect(videos.statusReads, ['thanks-video', 'urgency-video']);
      await tapPublication(tester, find.text('Continuar'));
      expect(find.text('Valida tu caso'), findsOneWidget);
      expect(repo.caseSaves.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final initialUrgencyState in ['ready', 'processing']) {
    for (final failure in [false, true]) {
      testWidgets(
        'urgency $initialUrgencyState replacement waits for authoritative cancel failure=$failure',
        (tester) async {
          final repo = DraftCaseRescue();
          final expense = expenseFixture();
          repo.expenses = [
            RescueRecord({
              ...expense.data,
              'private_data': {
                ...expense.privateData,
                'urgency_reason': 'Urgente TEST',
              },
            }),
          ];
          final videos = WizardVideos(repo)
            ..enabled = true
            ..state = 'ready'
            ..urgencyState = initialUrgencyState
            ..cancellationFails = failure;
          await startPublication(
            tester,
            FakeCommunity(),
            '/rescue/case-one',
            rescue: repo,
            videos: videos,
          );
          await tapPublication(tester, find.text('Continuar'));
          await tapPublication(tester, find.text('Continuar'));
          final cancel = find.text('Quitar video y cambiar a foto');
          await tester.ensureVisible(cancel);
          await tester.pumpAndSettle();
          final pending = Completer<void>();
          videos.cancellationBarrier = pending;
          addTearDown(() {
            if (!pending.isCompleted) pending.complete();
          });
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<PublicationFooter>(find.byType(PublicationFooter))
                .onContinue,
            isNull,
          );
          expect(
            tester
                .widget<PublicationFrame>(find.byType(PublicationFrame))
                .onBack,
            isNull,
          );
          pending.complete();
          await tester.pumpAndSettle();
          if (failure) {
            expect(
              find.text('No pudimos cambiar el complemento. Intenta de nuevo.'),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<PublicationFooter>(find.byType(PublicationFooter))
                  .onContinue,
              isNull,
            );
            expect(
              tester
                  .widget<PublicationFrame>(find.byType(PublicationFrame))
                  .onBack,
              isNull,
            );
            videos.urgencyState = null;
            tester
                .widget<RescueVideoSection>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is RescueVideoSection &&
                        widget.purposes.contains('urgency'),
                  ),
                )
                .onChanged!();
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<PublicationFooter>(find.byType(PublicationFooter))
                  .onContinue,
              isNull,
            );
            expect(cancel, findsOneWidget);
            final semantics = tester.ensureSemantics();
            try {
              final urgencyUpload = find.byWidgetPredicate(
                (widget) =>
                    widget is VideoUpload && widget.purpose == 'urgency',
              );
              final selection = find.descendant(
                of: urgencyUpload,
                matching: find.text('Cancelar video'),
              );
              await tester.ensureVisible(selection);
              await tester.pumpAndSettle();
              expect(
                tester
                    .getSemantics(selection)
                    .getSemanticsData()
                    .hasAction(ui.SemanticsAction.tap),
                isFalse,
                reason: 'Only the external cancellation reconciliation stays active',
              );
              expect(
                tester
                    .widget<TextButton>(
                      find.widgetWithText(
                        TextButton,
                        'Quitar video y cambiar a foto',
                      ),
                    )
                    .onPressed,
                isNotNull,
              );
            } finally {
              semantics.dispose();
            }
            videos.cancellationFails = false;
            await tapPublication(tester, cancel);
          }
          expect(
            videos.cancellations,
            List.filled(failure ? 2 : 1, 'urgency-video'),
          );
          expect(
            find.byWidgetPredicate(
              (widget) => widget is VideoUpload && widget.purpose == 'urgency',
            ),
            findsNothing,
          );
          expect(find.text('Añadir foto de urgencia'), findsOneWidget);
          expect(
            tester
                .widget<PublicationFooter>(find.byType(PublicationFooter))
                .onContinue,
            isNotNull,
          );
          expect(
            tester
                .widget<PublicationFrame>(find.byType(PublicationFrame))
                .onBack,
            isNotNull,
          );
          await tapPublication(tester, find.text('Continuar'));
          expect(find.text('Valida tu caso'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final hasPhoto in [false, true]) {
    testWidgets(
      'gratitude processing blocks urgency photo mutations hasPhoto=$hasPhoto',
      (tester) async {
        final repo = DraftCaseRescue();
        if (hasPhoto) {
          final detail = await repo.detail('case-one');
          repo.publicSaved = {
            ...Json.from(Json.from(detail['record'])['public_data']),
            'urgency_photo_path': 'one/case-one/photo.jpg',
          };
        }
        final expense = expenseFixture();
        repo.expenses = [
          RescueRecord({
            ...expense.data,
            'private_data': {
              ...expense.privateData,
              'urgency_reason': 'Urgente TEST',
            },
          }),
        ];
        final videos = WizardVideos(repo)
          ..enabled = true
          ..state = 'processing';
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/case-one',
          rescue: repo,
          videos: videos,
        );
        await tapPublication(tester, find.text('Continuar'));
        await tapPublication(tester, find.text('Continuar'));
        final urgency = tester.widget<UrgencyComplement>(
          find.byType(UrgencyComplement),
        );
        expect(urgency.enabled, isTrue);
        expect(urgency.photoMutationsEnabled, isFalse);
        final labels = hasPhoto
            ? ['Reemplazar foto de urgencia', 'Quitar complemento de foto']
            : ['Añadir foto de urgencia'];
        for (final label in labels) {
          final action = hasPhoto
              ? tester
                    .widget<TextButton>(find.widgetWithText(TextButton, label))
                    .onPressed
              : tester
                    .widget<OutlinedButton>(
                      find.widgetWithText(OutlinedButton, label),
                    )
                    .onPressed;
          expect(action, isNull);
        }
        final uploader = tester.element(find.byType(VideoUpload));
        final savedVersion = repo.caseSaves.last.version;
        await urgency.onPhoto();
        await urgency.onRemovePhoto();
        await tester.pumpAndSettle();
        expect(repo.caseSaves.length, 2);
        expect(repo.caseSaves.last.version, savedVersion);
        expect(tester.element(find.byType(VideoUpload)), same(uploader));
        expect(videos.cancellations, isEmpty);
        await tapPublication(tester, find.text('Comprobar video'));
        expect(
          tester
              .widget<UrgencyComplement>(find.byType(UrgencyComplement))
              .photoMutationsEnabled,
          isTrue,
        );
        for (final label in labels) {
          final action = hasPhoto
              ? tester
                    .widget<TextButton>(find.widgetWithText(TextButton, label))
                    .onPressed
              : tester
                    .widget<OutlinedButton>(
                      find.widgetWithText(OutlinedButton, label),
                    )
                    .onPressed;
          expect(action, isNotNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in ['media', 'photos', 'header-back', 'system-back']) {
    for (final state in ['stale', 'processing']) {
      testWidgets(
        'reentering media via $entry resets ready before $state policy resolves',
        (tester) async {
          final repo = DraftCaseRescue();
          final videos = WizardVideos(repo)
            ..enabled = true
            ..state = 'ready';
          await startPublication(
            tester,
            FakeCommunity(),
            '/rescue/case-one',
            rescue: repo,
            videos: videos,
          );
          for (var i = 0; i < 3; i++) {
            await tapPublication(tester, find.text('Continuar'));
          }
          expect(find.text('Valida tu caso'), findsOneWidget);
          final pending = Completer<void>();
          videos.policyBarrier = pending;
          videos.state = state == 'stale' ? 'ready' : 'processing';
          videos.matches = state != 'stale';
          videos.moderation = state == 'stale' ? 'stale' : 'pending';
          addTearDown(() {
            if (!pending.isCompleted) pending.complete();
          });
          switch (entry) {
            case 'media':
              tester
                  .widget<TextButton>(
                    find.byKey(const ValueKey('case-review-edit-media')),
                  )
                  .onPressed!();
              break;
            case 'photos':
              tester
                  .widget<CaseReview>(find.byType(CaseReview))
                  .onEditPhotos!();
              break;
            case 'header-back':
              tester
                  .widget<PublicationFrame>(find.byType(PublicationFrame))
                  .onBack!();
              break;
            case 'system-back':
              await tester.binding.handlePopRoute();
              break;
          }
          await tester.pump();
          expect(
            tester.widget<PublicationFrame>(find.byType(PublicationFrame)).step,
            2,
          );
          expect(
            tester
                .widget<PublicationFooter>(find.byType(PublicationFooter))
                .onContinue,
            isNull,
          );
          pending.complete();
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<PublicationFooter>(find.byType(PublicationFooter))
                .onContinue,
            isNull,
          );
          expect(repo.caseSaves.length, 2);
          expect(repo.submits, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scenario in <(String, String?, String, bool, bool)>[
    ('absent', null, 'pending', true, false),
    ('processing', 'processing', 'pending', true, false),
    ('failed', 'failed', 'pending', true, false),
    ('old snapshot', 'ready', 'pending', false, false),
    ('stale', 'ready', 'stale', true, false),
    ('rejected', 'ready', 'rejected', true, false),
    ('withdrawn', 'ready', 'withdrawn', true, false),
    ('ready pending review', 'ready', 'pending', true, true),
    ('ready approved', 'ready', 'approved', true, true),
  ]) {
    testWidgets('required gratitude gates media advance: ${scenario.$1}', (
      tester,
    ) async {
      final repo = DraftCaseRescue();
      final videos = WizardVideos(repo)
        ..enabled = true
        ..state = scenario.$2
        ..moderation = scenario.$3
        ..matches = scenario.$4;
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: videos,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      final footer = tester.widget<PublicationFooter>(
        find.byType(PublicationFooter),
      );
      expect(footer.onContinue != null, scenario.$5);
      expect(repo.caseSaves.length, 2);
      if (scenario.$5) {
        await tapPublication(tester, find.text('Continuar'));
        expect(find.text('Valida tu caso'), findsOneWidget);
        expect(repo.caseSaves.length, 2);
      } else {
        expect(find.text('Un poco más...'), findsOneWidget);
        expect(repo.submits, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final enabled in [false, true]) {
    testWidgets('stable gratitude exemption permits advance enabled=$enabled', (
      tester,
    ) async {
      final repo = DraftCaseRescue();
      final videos = WizardVideos(repo)
        ..enabled = enabled
        ..requiredThanks = !enabled;
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: videos,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      expect(find.text('Valida tu caso'), findsOneWidget);
      expect(repo.caseSaves.length, 2);
      expect(repo.submits, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unavailable policy blocks advance until actual retry resolves', (
    tester,
  ) async {
    final repo = DraftCaseRescue();
    final videos = WizardVideos(repo)..failPolicy = true;
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/case-one',
      rescue: repo,
      videos: videos,
    );
    await tapPublication(tester, find.text('Continuar'));
    await tapPublication(tester, find.text('Continuar'));
    expect(
      tester
          .widget<PublicationFooter>(find.byType(PublicationFooter))
          .onContinue,
      isNull,
    );
    expect(
      find.text('No pudimos consultar la disponibilidad de videos.'),
      findsOneWidget,
    );
    videos.failPolicy = false;
    await tapPublication(
      tester,
      find.text('Reintentar disponibilidad de videos'),
    );
    await tapPublication(tester, find.text('Continuar'));
    expect(find.text('Valida tu caso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing video connection cannot be treated as a known OFF policy',
    (tester) async {
      final repo = DraftCaseRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNull,
      );
      expect(
        tester.widget<PublicationFrame>(find.byType(PublicationFrame)).onBack,
        isNotNull,
      );
      expect(
        find.text('No pudimos consultar la disponibilidad de videos.'),
        findsOneWidget,
      );
      expect(repo.caseSaves.length, 2);
      expect(repo.submits, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'optional processing and uncertain cancellation keep uploader mounted',
    (tester) async {
      final repo = DraftCaseRescue();
      final videos = WizardVideos(repo)
        ..enabled = true
        ..requiredThanks = false
        ..state = 'processing';
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: videos,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      final uploader = tester.element(find.byType(VideoUpload));
      void expectCannotLeave() {
        expect(
          tester
              .widget<PublicationFooter>(find.byType(PublicationFooter))
              .onContinue,
          isNull,
        );
        expect(
          tester.widget<PublicationFrame>(find.byType(PublicationFrame)).onBack,
          isNull,
        );
        expect(tester.element(find.byType(VideoUpload)), same(uploader));
        final save = find.widgetWithText(TextButton, 'Guardar borrador');
        expect(save, findsOneWidget);
        expect(tester.widget<TextButton>(save).onPressed, isNull);
      }

      expectCannotLeave();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectCannotLeave();
      await tapPublication(tester, find.text('Comprobar video'));
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNotNull,
      );

      videos.cancellationFails = true;
      await tapPublication(tester, find.text('Cancelar video'));
      expectCannotLeave();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectCannotLeave();
      await tapPublication(tester, find.text('Comprobar cancelación'));
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNotNull,
      );
      expect(
        tester.widget<PublicationFrame>(find.byType(PublicationFrame)).onBack,
        isNotNull,
      );
      await tapPublication(tester, find.text('Continuar'));
      expect(find.text('Valida tu caso'), findsOneWidget);
      expect(repo.caseSaves.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'last urgent expense removal clears photo snapshot before media policy',
    (tester) async {
      final repo = DraftCaseRescue();
      final detail = await repo.detail('case-one');
      repo.publicSaved = {
        ...Json.from(Json.from(detail['record'])['public_data']),
        'urgency_photo_path': 'one/case-one/photo.jpg',
      };
      final expense = expenseFixture();
      repo.expenses = [
        RescueRecord({
          ...expense.data,
          'private_data': {
            ...expense.privateData,
            'urgency_reason': 'Urgente TEST',
          },
        }),
      ];
      final videos = WizardVideos(repo);
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: videos,
      );
      await tapPublication(tester, find.text('Continuar'));
      expect(repo.caseSaves.last.publicData['urgency_photo_path'], isNotNull);
      await tapPublication(
        tester,
        find.byKey(const ValueKey('case-remove-expense-expense-draft')),
      );
      await tapPublication(
        tester,
        find.widgetWithText(TextButton, 'Eliminar').last,
      );
      expect(repo.expenses, isEmpty);
      expect(repo.caseSaves.length, 1);
      await tapPublication(tester, find.text('Continuar'));
      expect(
        repo.caseSaves.last.publicData.containsKey('urgency_photo_path'),
        isFalse,
      );
      expect(videos.policySnapshots, isNotEmpty);
      expect(
        videos.policySnapshots.every(
          (snapshot) => !snapshot.containsKey('urgency_photo_path'),
        ),
        isTrue,
      );
      await tapPublication(tester, find.text('Continuar'));
      expect(repo.caseSaves.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

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
        videos: WizardVideos(repo),
      );
      await tapPublication(tester, find.text('Continuar'));
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
    'four case steps keep original saves and clean media advance does not create a version',
    (tester) async {
      final repo = DraftCaseRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: WizardVideos(repo),
      );
      void expectStep(int step, int saves) {
        final frame = tester.widget<PublicationFrame>(
          find.byType(PublicationFrame),
        );
        expect(frame.step, step);
        expect(frame.totalSteps, 4);
        expect(
          tester
              .widget<PublicationFooter>(find.byType(PublicationFooter))
              .onSave,
          isNotNull,
        );
        expect(repo.saveCalls, saves);
      }

      expectStep(0, 0);
      expect(find.text('¿A quién estás apoyando?'), findsOneWidget);
      expect(find.byType(RescueVideoSection), findsNothing);
      await tapPublication(tester, find.text('Continuar'));
      expectStep(1, 1);
      expect(find.text('Cuéntanos'), findsOneWidget);
      expect(find.byType(CaseDraftNeeds), findsOneWidget);
      expect(find.byType(RescueVideoSection), findsNothing);
      expect(find.byType(UrgencyComplement), findsNothing);
      expect(find.text('Fotos adicionales (opcional)'), findsNothing);

      await tapPublication(tester, find.text('Continuar'));
      expectStep(2, 2);
      expect(find.text('Un poco más...'), findsOneWidget);
      expect(find.byType(CaseDraftNeeds), findsNothing);
      expect(find.byType(RescueVideoSection), findsOneWidget);
      expect(find.byType(UrgencyComplement), findsOneWidget);
      expect(find.text('Fotos adicionales (opcional)'), findsOneWidget);

      await tapPublication(tester, find.text('Continuar'));
      expectStep(3, 2);
      expect(find.text('Valida tu caso'), findsOneWidget);
      expect(find.byType(CaseDetailLayout), findsOneWidget);
      expect(find.byType(RescueVideoSection), findsNothing);
      expect(find.byType(UrgencyComplement), findsNothing);
      expect(find.text('Fotos adicionales (opcional)'), findsNothing);
      expect(repo.submits, 0);

      await tapPublication(tester, find.text('Editar perfil'));
      expectStep(0, 2);
      for (var i = 0; i < 3; i++) {
        await tapPublication(tester, find.text('Continuar'));
      }
      await tapPublication(tester, find.text('Editar necesidades'));
      expectStep(1, 4);
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Editar medios'));
      expectStep(2, 5);
      expect(repo.caseSaves.last.version, 8);
      expect(repo.submits, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dirty case needs are saved before media and submission keeps the saved values',
    (tester) async {
      final repo = DraftCaseRescue()..reject = true;
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: WizardVideos(repo),
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(
        tester,
        find.text('Cuidados y necesidades previstas'),
      );
      final need = find.byKey(const ValueKey('case-field-need'));
      await tester.ensureVisible(need);
      await tester.enterText(need, 'Cuidados corregidos y seguimiento');
      FocusManager.instance.primaryFocus?.unfocus();
      expect(repo.caseSaves.length, 1);
      await tapPublication(tester, find.text('Continuar'));
      final saved = repo.caseSaves.last;
      final media = tester.widget<RescueVideoSection>(
        find.byType(RescueVideoSection),
      );
      expect(saved.version, 5);
      expect(saved.publicData['need'], 'Cuidados corregidos y seguimiento');
      expect(media.record!.id, saved.id);
      expect(media.record!.version, saved.version);
      expect(media.needsSave, isFalse);

      await tapPublication(tester, find.text('Continuar'));
      expect(repo.caseSaves.length, 2);
      await tapPublication(tester, find.text('Enviar a revisión'));
      expect(repo.submits, 1);
      expect(repo.caseSaves.length, 3);
      expect(repo.caseSaves.last.version, 6);
      expect(
        repo.caseSaves.last.publicData['need'],
        'Cuidados corregidos y seguimiento',
      );
      expect(find.text('Enviado a revisión'), findsNothing);
      expect(find.textContaining('No se pudo enviar'), findsOneWidget);
      expect(find.text('Valida tu caso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paid expense edit persists only private child evidence and metadata',
    (tester) async {
      final repo = DraftCaseRescue()..expenses = [expenseFixture()];
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
        videos: WizardVideos(repo),
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
      videos: WizardVideos(repo),
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
          videos: WizardVideos(repo),
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
        videos: WizardVideos(repo),
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
      videos: WizardVideos(repo),
    );
    final name = find.byKey(const ValueKey('case-field-pet_name'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Mora corregida');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapPublication(tester, find.text('Continuar'));
    await tapPublication(tester, find.text('Continuar'));
    await tapPublication(tester, find.text('Continuar'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Un poco más...'), findsOneWidget);
    expect(find.byType(RescueVideoSection), findsOneWidget);
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
          videos: WizardVideos(repo),
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
