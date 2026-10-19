import 'dart:async';

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:flutter/material.dart';
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
