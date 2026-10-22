import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/core/media/moderated_video.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PolicyVideoRepository extends VideoRepository {
  PolicyVideoRepository()
    : super(
        identity: () => 'one:session',
        invoke: (_) async => throw const VideoFailure('not_a_fixture_upload'),
      );
  bool enabled = true, requiredThanks = true, fail = false;
  final parents = <String>[];
  @override
  Future<VideoPolicy> policy(String parentId) async {
    parents.add(parentId);
    if (fail) throw const VideoFailure('policy_unavailable');
    return VideoPolicy.fromJson({
      'enabled': enabled,
      'thanks_required': requiredThanks,
      'assets': <Map<String, dynamic>>[],
    });
  }
}

class VideoEditorSession {
  String actor = 'one:session';
  final events = StreamController<void>.broadcast();
}

class PendingCancellationRepository extends PolicyVideoRepository {
  final cancellation = Completer<void>();
  Future<VideoPolicy>? nextPolicy;
  @override
  Future<VideoPolicy> policy(String parentId) async =>
      await nextPolicy ??
      VideoPolicy(
        enabled: true,
        thanksRequired: true,
        assets: [
          for (final purpose in ['thanks', 'farewell'])
            {
              'id': 'own-$purpose',
              'parent_id': parentId,
              'parent_version': 7,
              'purpose': purpose,
              'technical_state': 'ready',
              'moderation_state': 'pending',
              'request_key': 'request-$purpose',
              'bytes': 3,
            },
        ],
      );
  @override
  Future<void> cancel(VideoUploadTask task) => cancellation.future;
}

class AccountVideoRepository extends VideoRepository {
  AccountVideoRepository(this.session)
    : super(
        identity: () => session.actor,
        identityChanges: session.events.stream,
        invoke: (_) async => throw const VideoFailure('not_uploading'),
      );
  final VideoEditorSession session;
  @override
  Future<VideoPolicy> policy(String parentId) async {
    if (session.actor != 'one:session') throw const VideoFailure('not_owner');
    return VideoPolicy(
      enabled: true,
      thanksRequired: true,
      assets: [
        {
          'id': 'private-own',
          'parent_id': parentId,
          'purpose': 'thanks',
          'technical_state': 'processing',
          'moderation_state': 'pending',
        },
      ],
    );
  }
}

RescueRecord videoRecord({String status = 'draft'}) => RescueRecord({
  'id': 'persisted-case',
  'kind': 'case',
  'version': 7,
  'status': status,
});

void main() {
  for (final scale in [1.0, 1.15, 2.0]) {
    testWidgets(
      'uncertain cancellation removes only its own ready preview at $scale',
      (tester) async {
        final repo = PendingCancellationRepository();
        addTearDown(repo.dispose);
        final captureFolder = Platform.environment['DOPMI_VIDEO_CAPTURE_DIR'];
        final captureKey = GlobalKey();
        if (captureFolder != null) {
          await tester.runAsync(() async {
            for (final font in ['Inter', 'Fraunces']) {
              await (FontLoader(
                font,
              )..addFont(rootBundle.load('assets/fonts/$font.ttf'))).load();
            }
          });
        }
        tester.view.physicalSize = Size(scale == 2 ? 320 : 400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [rescueVideosRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              theme: dopmiTheme(rescuer: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: captureKey, child: child!),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RescueVideoSection(
                    record: videoRecord(),
                    purposes: const ['thanks', 'farewell'],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ModeratedVideo), findsNWidgets(2));
        await tester.ensureVisible(find.text('Cancelar video').first);
        await tester.tap(find.text('Cancelar video').first);
        await tester.pump();
        expect(find.byKey(const ValueKey('own:own-thanks')), findsNothing);
        expect(find.byKey(const ValueKey('own:own-farewell')), findsOneWidget);
        expect(
          find.text('Video Agradecimiento: Procesado · Pendiente de revisión'),
          findsNothing,
        );
        repo.cancellation.completeError(const VideoFailure('request_denied'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Comprobar cancelación'));
        expect(
          tester.getRect(find.text('Comprobar cancelación')).bottom,
          lessThanOrEqualTo(800),
        );
        if (captureFolder != null) {
          await tester.ensureVisible(
            find.text(
              'No pudimos confirmar la cancelación. Comprueba su estado antes de elegir otro video.',
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$captureFolder/cancel-pending-$scale.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(find.byKey(const ValueKey('own:own-thanks')), findsNothing);
        expect(find.byKey(const ValueKey('own:own-farewell')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets('replacement cannot remount canceled preview from stale policy', (
    tester,
  ) async {
    final repo = PendingCancellationRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rescueVideosRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RescueVideoSection(
                record: videoRecord(),
                purposes: const ['thanks'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancelar video'));
    await tester.tap(find.text('Cancelar video'));
    await tester.pump();
    repo.cancellation.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('own:own-thanks')), findsNothing);
    final policy = Completer<VideoPolicy>();
    repo.nextPolicy = policy.future;
    // Exercise the parent's upload-result boundary while its policy RPC waits.
    tester
        .widget<VideoUpload>(find.byType(VideoUpload))
        .onChanged
        ?.call(
          const VideoAsset(
            id: 'replacement',
            state: 'ready',
            moderation: 'pending',
          ),
        );
    await tester.pump();
    expect(find.byKey(const ValueKey('own:own-thanks')), findsNothing);
    expect(find.byKey(const ValueKey('own:replacement')), findsNothing);
    policy.complete(
      VideoPolicy(
        enabled: true,
        thanksRequired: true,
        assets: [
          {
            'id': 'replacement',
            'parent_id': 'persisted-case',
            'parent_version': 7,
            'purpose': 'thanks',
            'technical_state': 'ready',
            'moderation_state': 'pending',
            'request_key': 'new-request',
            'bytes': 3,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('own:own-thanks')), findsNothing);
    expect(find.byKey(const ValueKey('own:replacement')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  Future<void> mount(
    WidgetTester tester,
    PolicyVideoRepository repository,
    Widget child,
  ) async {
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueVideosRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saving a real draft precedes policy and video upload binding', (
    tester,
  ) async {
    final repo = PolicyVideoRepository();
    RescueRecord? record;
    await mount(
      tester,
      repo,
      StatefulBuilder(
        builder: (context, update) => RescueVideoSection(
          record: record,
          purposes: const ['thanks'],
          onSave: () async {
            update(() => record = videoRecord());
          },
        ),
      ),
    );
    expect(repo.parents, isEmpty);
    expect(find.byType(VideoUpload), findsNothing);
    await tester.tap(find.text('Guardar borrador para añadir videos'));
    await tester.pumpAndSettle();
    expect(repo.parents, ['persisted-case']);
    final uploader = tester.widget<VideoUpload>(find.byType(VideoUpload));
    expect(uploader.parentId, 'persisted-case');
    expect(uploader.parentVersion, 7);
    expect(uploader.purpose, 'thanks');
    expect(find.textContaining('Para enviar este nuevo caso'), findsOneWidget);
  });
  testWidgets(
    'server gate hides upload, and grandfathered cases do not acquire a new requirement',
    (tester) async {
      final repo = PolicyVideoRepository()..enabled = false;
      await mount(
        tester,
        repo,
        RescueVideoSection(record: videoRecord(), purposes: const ['thanks']),
      );
      expect(find.byType(VideoUpload), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final previous = PolicyVideoRepository()..requiredThanks = false;
      await mount(
        tester,
        previous,
        RescueVideoSection(record: videoRecord(), purposes: const ['thanks']),
      );
      expect(find.byType(VideoUpload), findsOneWidget);
      expect(find.textContaining('Para enviar este nuevo caso'), findsNothing);
    },
  );
  testWidgets(
    'failed policy can retry without starting an unauthorized upload',
    (tester) async {
      final repo = PolicyVideoRepository()..fail = true;
      await mount(
        tester,
        repo,
        RescueVideoSection(record: videoRecord(), purposes: const ['thanks']),
      );
      expect(find.byType(VideoUpload), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Reintentar disponibilidad de videos'));
      await tester.pumpAndSettle();
      expect(find.byType(VideoUpload), findsOneWidget);
      expect(repo.parents.length, 2);
    },
  );
  testWidgets(
    'farewell on a closed case keeps the parent closed and separate from private evidence',
    (tester) async {
      final repo = PolicyVideoRepository();
      final record = videoRecord(status: 'closed');
      await mount(
        tester,
        repo,
        RescueVideoSection(record: record, purposes: const ['farewell']),
      );
      final uploader = tester.widget<VideoUpload>(find.byType(VideoUpload));
      expect(uploader.purpose, 'farewell');
      expect(record.status, 'closed');
      expect(find.textContaining('no reabre el caso'), findsOneWidget);
      expect(find.textContaining('Evidencia privada'), findsNothing);
    },
  );
  test('submission rejection explains current gratitude requirement without silently grandfathering', () {
    expect(
      rescueError(
        const PostgrestException(
          message: 'Agradecimiento requerido',
          code: '23514',
        ),
      ),
      contains('esta versión'),
    );
  });
  testWidgets(
    'switching sessions clears previous owner metadata before retrying policy',
    (tester) async {
      final session = VideoEditorSession();
      final repo = AccountVideoRepository(session);
      addTearDown(repo.dispose);
      addTearDown(session.events.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rescueVideosRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: RescueVideoSection(
                record: videoRecord(),
                purposes: const ['thanks'],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Video Agradecimiento: Procesando'),
        findsOneWidget,
      );
      session.actor = 'two:session';
      session.events.add(null);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Video Agradecimiento: Procesando'),
        findsNothing,
      );
      expect(find.byType(VideoUpload), findsNothing);
    },
  );
}
