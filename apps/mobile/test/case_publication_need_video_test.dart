import 'dart:async';

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_publication_need_editor.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue;

class NeedSession extends FakeCommunity {
  String actor = 'one';
  @override
  String? get userId => actor;
}

RescueRecord needRecord({int version = 4}) => RescueRecord({
  'id': 'expense-existing',
  'owner_id': 'one',
  'kind': 'expense',
  'parent_id': 'case-draft',
  'status': 'draft',
  'version': version,
  'public_data': {'category': 'veterinary', 'title': 'Consulta'},
  'files': <Json>[],
});

class NeedRescue extends FakeRescue {
  final writes = <Json>[];
  bool fail = false;
  Completer<void>? pending;
  int transitions = 0;
  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    writes.add({
      'kind': kind,
      'id': record?.id,
      'version': record?.version,
      'parent': parent,
      'public': publicData,
      'private': privateData,
      'files': files.map((item) => Json.from(item)).toList(),
    });
    if (pending != null) await pending!.future;
    if (fail) throw const FormatException('No se pudo guardar.');
    return RescueRecord({
      ...needRecord().data,
      'id': record?.id ?? 'expense-new',
      'version': (record?.version ?? 0) + 1,
      'public_data': publicData,
      'private_data': privateData,
      'files': files,
    });
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    transitions++;
    throw StateError('El editor no debe enviar ni publicar');
  }
}

class NeedVideos extends VideoRepository {
  NeedVideos(this.session)
    : super(
        identity: () => '${session.actor}:session',
        invoke: (_) async => throw StateError('No carga en esta prueba'),
      );
  final NeedSession session;
  bool enabled = true;
  final policies = <String>[];
  @override
  Future<VideoPolicy> policy(String parentId) async {
    policies.add(parentId);
    return VideoPolicy(
      enabled: enabled,
      thanksRequired: true,
      assets: const [],
    );
  }
}

Future<void> mountNeed(
  WidgetTester tester,
  NeedSession session,
  NeedRescue rescue,
  NeedVideos videos, {
  RescueRecord? record,
}) async {
  tester.view.physicalSize = const Size(440, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(videos.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityRepositoryProvider.overrideWithValue(session),
        rescueRepositoryProvider.overrideWithValue(rescue),
        rescueVideosRepositoryProvider.overrideWithValue(videos),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CasePublicationNeedEditor(
            caseId: 'case-draft',
            type: 'veterinary',
            record: record,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> saveVideoDraft(WidgetTester tester) async {
  final save = find.text('Guardar borrador para añadir videos');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

RescueRecord privateNeedRecord() => RescueRecord({
  ...needRecord().data,
  'private_data': {
    'vendor': 'Proveedor reservado TEST',
    'amount_cents': '12345',
  },
  'files': <Json>[
    {'role': 'receipt', 'path': 'one/expense-existing/receipt.pdf'},
  ],
});

void expectSessionOnly() {
  expect(
    find.text('La sesión cambió. Retoma el borrador con su cuenta.'),
    findsOneWidget,
  );
  expect(find.text('Cerrar'), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
  expect(find.text('Proveedor reservado TEST'), findsNothing);
  expect(find.text('123.45'), findsNothing);
  expect(find.byTooltip('Quitar archivo 1'), findsNothing);
  expect(find.text('Ver archivo 1'), findsNothing);
  expect(find.text('Foto de Recibo *'), findsNothing);
  expect(find.byType(RescueVideoSection), findsNothing);
  expect(find.byType(VideoUpload), findsNothing);
}

void main() {
  testWidgets(
    'new need persists once before exposing private video ID/version',
    (tester) async {
      final session = NeedSession(), rescue = NeedRescue();
      final videos = NeedVideos(session);
      await mountNeed(tester, session, rescue, videos);
      expect(videos.policies, isEmpty);
      expect(find.byType(VideoUpload), findsNothing);
      await saveVideoDraft(tester);
      final upload = tester.widget<VideoUpload>(find.byType(VideoUpload));
      expect(upload.parentId, 'expense-new');
      expect(upload.parentVersion, 1);
      expect(upload.purpose, 'expense_evidence');
      expect(rescue.writes.single['parent'], 'case-draft');
      expect(rescue.writes.single['kind'], 'expense');
      expect(videos.policies, ['expense-new']);
      expect(rescue.transitions, 0);
      expect(find.byType(PublicRescueVideos), findsNothing);
    },
  );

  testWidgets(
    'dirty fields hide old upload until same expense next version saved',
    (tester) async {
      final session = NeedSession(), rescue = NeedRescue();
      final videos = NeedVideos(session);
      await mountNeed(tester, session, rescue, videos, record: needRecord());
      expect(
        tester.widget<VideoUpload>(find.byType(VideoUpload)).parentVersion,
        4,
      );
      await tester.enterText(
        find.byKey(const ValueKey('publication-need-title')),
        'Consulta corregida',
      );
      await tester.pump();
      expect(find.byType(VideoUpload), findsNothing);
      await saveVideoDraft(tester);
      final upload = tester.widget<VideoUpload>(find.byType(VideoUpload));
      expect(upload.parentId, 'expense-existing');
      expect(upload.parentVersion, 5);
      expect(rescue.writes.single['id'], 'expense-existing');
      expect(
        (rescue.writes.single['public'] as Json)['title'],
        'Consulta corregida',
      );
      expect(rescue.transitions, 0);
    },
  );

  testWidgets(
    'failed dirty save cannot reuse previous policy; retry preserves expense',
    (tester) async {
      final session = NeedSession(), rescue = NeedRescue()..fail = true;
      final videos = NeedVideos(session);
      await mountNeed(tester, session, rescue, videos, record: needRecord());
      await tester.enterText(
        find.byKey(const ValueKey('publication-need-vendor')),
        'Proveedor TEST',
      );
      await tester.pump();
      await saveVideoDraft(tester);
      expect(find.byType(VideoUpload), findsNothing);
      expect(videos.policies, ['expense-existing']);
      expect(
        find.textContaining('No pudimos guardar el borrador.'),
        findsOneWidget,
      );
      rescue.fail = false;
      await saveVideoDraft(tester);
      expect(
        rescue.writes.map((item) => item['id']),
        everyElement('expense-existing'),
      );
      expect(
        tester.widget<VideoUpload>(find.byType(VideoUpload)).parentVersion,
        5,
      );
      expect(rescue.transitions, 0);
    },
  );

  testWidgets(
    'urgency and attachment removal require a fresh expense version',
    (tester) async {
      final session = NeedSession(), rescue = NeedRescue();
      final videos = NeedVideos(session);
      final record = RescueRecord({
        ...needRecord().data,
        'files': <Json>[
          {'role': 'receipt', 'path': 'one/expense-existing/receipt.pdf'},
        ],
      });
      await mountNeed(tester, session, rescue, videos, record: record);
      await tester.ensureVisible(find.text('Marcar como urgente'));
      await tester.tap(find.text('Marcar como urgente'));
      await tester.pump();
      expect(find.byType(VideoUpload), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('publication-need-urgency_reason')),
        'Atención urgente TEST',
      );
      await saveVideoDraft(tester);
      expect(
        tester.widget<VideoUpload>(find.byType(VideoUpload)).parentVersion,
        5,
      );
      expect(
        (rescue.writes.single['private'] as Json)['urgency_reason'],
        'Atención urgente TEST',
      );
      await tester.ensureVisible(find.byTooltip('Quitar archivo 1'));
      await tester.tap(find.byTooltip('Quitar archivo 1'));
      await tester.pump();
      expect(find.byType(VideoUpload), findsNothing);
      await saveVideoDraft(tester);
      expect(
        tester.widget<VideoUpload>(find.byType(VideoUpload)).parentVersion,
        6,
      );
      expect(rescue.writes.last['files'], isEmpty);
      expect(rescue.transitions, 0);
    },
  );

  testWidgets('server OFF exposes no upload even after private draft save', (
    tester,
  ) async {
    final session = NeedSession(), rescue = NeedRescue();
    final videos = NeedVideos(session)..enabled = false;
    await mountNeed(tester, session, rescue, videos);
    await saveVideoDraft(tester);
    expect(videos.policies, ['expense-new']);
    expect(find.byType(VideoUpload), findsNothing);
    expect(rescue.transitions, 0);
  });

  testWidgets(
    'session changed before save hides private data and cannot write',
    (tester) async {
      final session = NeedSession(), rescue = NeedRescue();
      final videos = NeedVideos(session);
      await mountNeed(
        tester,
        session,
        rescue,
        videos,
        record: privateNeedRecord(),
      );
      await tester.enterText(
        find.byKey(const ValueKey('publication-need-title')),
        'Consulta modificada',
      );
      await tester.pump();
      session.actor = 'other';
      await saveVideoDraft(tester);
      expect(rescue.writes, isEmpty);
      expectSessionOnly();
      expect(videos.policies, ['expense-existing']);
    },
  );

  testWidgets(
    'session changed during save hides private data and rejects returned record',
    (tester) async {
      final session = NeedSession(),
          rescue = NeedRescue()..pending = Completer<void>();
      final videos = NeedVideos(session);
      await mountNeed(
        tester,
        session,
        rescue,
        videos,
        record: privateNeedRecord(),
      );
      await tester.enterText(
        find.byKey(const ValueKey('publication-need-title')),
        'Consulta modificada',
      );
      await tester.pump();
      final save = find.text('Guardar borrador para añadir videos');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      session.actor = 'other';
      rescue.pending!.complete();
      await tester.pumpAndSettle();
      expect(rescue.writes, hasLength(1));
      expectSessionOnly();
      expect(videos.policies, ['expense-existing']);
      expect(rescue.transitions, 0);
    },
  );
}
