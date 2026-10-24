import 'dart:ui' show PointerDeviceKind;
import 'dart:async';

import 'package:dopmi_mobile/core/media/moderated_video.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rescue_test.dart' show FakeCaseUpdates;
import 'support_stories_test.dart'
    show StoryRepository, PendingStoryUpdates, story;

class PublishedStoryUpdates extends FakeCaseUpdates {
  @override
  Future<List<CaseUpdate>> publicFor(String caseId) async => [
    CaseUpdate({
      'id': 'published',
      'case_id': caseId,
      'body': 'Avance publicado',
      'photos': ['update/public-photo'],
      'published_at': '2026-10-24T00:00:00Z',
    }),
  ];
}

Future<void> mountVideoStories(
  WidgetTester tester,
  VideoRepository repository, {
  CaseUpdateRepository? updates,
  List<String> photos = const ['public/hero'],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueVideosRepositoryProvider.overrideWithValue(repository),
        rescueRepositoryProvider.overrideWithValue(StoryRepository()),
        caseUpdateRepositoryProvider.overrideWithValue(
          updates ?? FakeCaseUpdates(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SupportStories(records: [story('case', photos)]),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void stepStory(WidgetTester tester, {bool forward = true}) {
  final surface = tester.widget<GestureDetector>(
    find
        .byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onTapUp != null,
        )
        .first,
  );
  surface.onTapUp!(
    TapUpDetails(
      kind: PointerDeviceKind.touch,
      localPosition: Offset(forward ? 700 : 0, 100),
    ),
  );
}

String currentPhoto(WidgetTester tester) =>
    tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path;
ModeratedVideo currentPlayer(WidgetTester tester) =>
    tester.widget<ModeratedVideo>(find.byType(ModeratedVideo));

void main() {
  test('story segments preserve purpose order and only public case media', () {
    final record = RescueRecord({
      ...story('case', [
        'public/hero',
        'public/urgency',
        'public/gallery',
      ]).data,
      'public_data': {
        'pet_name': 'case',
        'photos': ['public/hero', 'public/urgency', 'public/gallery'],
        'urgency_photo_path': 'public/urgency',
      },
    });
    final rows = <Map<String, dynamic>>[
      {'id': 'farewell', 'parent_id': 'case', 'purpose': 'farewell'},
      {'id': 'private', 'parent_id': 'case', 'purpose': 'expense_evidence'},
      {'id': 'advance', 'parent_id': 'case', 'purpose': 'public_update'},
      {
        'id': 'thanks',
        'parent_id': 'case',
        'purpose': 'thanks',
        'duration': 20,
        'created_at': '2026-10-24T00:00:00Z',
      },
      {'id': 'urgent', 'parent_id': 'case', 'purpose': 'urgency'},
      {'id': 'foreign', 'parent_id': 'different-case', 'purpose': 'urgency'},
      {'id': ' ', 'parent_id': 'case', 'purpose': 'thanks'},
      {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
      {'id': 'ambiguous', 'parent_id': 'case', 'purpose': 'thanks'},
      {'id': 'ambiguous', 'parent_id': 'case', 'purpose': 'expense_evidence'},
    ];
    final videos = publicRescueVideoMetadata(rows, 'case');
    expect(publicRescueVideoIds(rows, 'case'), [
      'farewell',
      'advance',
      'thanks',
      'urgent',
    ]);
    expect(videos.firstWhere((v) => v.id == 'thanks').duration, 20);
    expect(
      videos.firstWhere((v) => v.id == 'thanks').createdAt,
      DateTime.utc(2026, 10, 24),
    );
    final segments = supportStorySegments(
      record,
      videos: [
        ...videos,
        const PublicRescueVideo(
          id: 'direct-private',
          parentId: 'case',
          purpose: 'expense_evidence',
        ),
        const PublicRescueVideo(
          id: 'direct-foreign',
          parentId: 'other',
          purpose: 'thanks',
        ),
        const PublicRescueVideo(
          id: 'direct-private',
          parentId: 'case',
          purpose: 'thanks',
        ),
      ],
      updates: [
        CaseUpdate({
          'id': 'published',
          'case_id': 'case',
          'published_at': '2026-10-24T00:00:00Z',
          'body': 'Avance público',
          'photos': ['public/hero', 'update/public-photo'],
        }),
        CaseUpdate({
          'id': 'private-update',
          'case_id': 'case',
          'photos': ['private/receipt.jpg'],
        }),
        CaseUpdate({
          'id': 'foreign-update',
          'case_id': 'other',
          'published_at': '2026-10-24T00:00:00Z',
          'photos': ['other/private-photo'],
        }),
      ],
    );
    expect(segments.map((s) => s.id), [
      'photo:public/hero',
      'photo:public/urgency',
      'video:urgent',
      'video:thanks',
      'photo:public/gallery',
      'photo:update/public-photo',
      'video:advance',
      'video:farewell',
    ]);
    expect(segments.map((s) => s.label), [
      'Historia del caso',
      'Urgencia',
      'Urgencia',
      'Agradecimiento',
      'Foto del caso',
      'Avance público',
      'Avance público',
      'Despedida',
    ]);
    expect(
      segments.where(
        (s) => s.id.contains('private') || s.id.contains('foreign'),
      ),
      isEmpty,
    );
    expect(
      supportStorySegments(
        story('draft', ['private/photo'], status: 'draft'),
        videos: videos,
      ),
      isEmpty,
    );
    final unapprovedUrgency = RescueRecord({
      ...story('case', ['public/hero']).data,
      'public_data': {
        'pet_name': 'case',
        'photos': ['public/hero'],
        'urgency_photo_path': 'private/receipt.jpg',
      },
    });
    expect(supportStorySegments(unapprovedUrgency).map((s) => s.id), [
      'photo:public/hero',
    ]);
  });

  testWidgets(
    'late video metadata cannot let public advances skip urgency or thanks',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final repository = VideoRepository(
        identity: () => null,
        invoke: (body) async {
          if (body['action'] == 'public_list') return pending.future;
          throw const VideoFailure('fixture_does_not_grant_playback');
        },
      );
      addTearDown(repository.dispose);
      await mountVideoStories(
        tester,
        repository,
        updates: PublishedStoryUpdates(),
        photos: ['public/hero', 'public/gallery'],
      );
      stepStory(tester);
      await tester.pump();
      expect(currentPhoto(tester), 'public/hero');
      pending.complete({
        'items': [
          {'id': 'bye', 'parent_id': 'case', 'purpose': 'farewell'},
          {
            'id': 'public-advance',
            'parent_id': 'case',
            'purpose': 'public_update',
          },
          {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
          {'id': 'urgent', 'parent_id': 'case', 'purpose': 'urgency'},
          {'id': 'receipt', 'parent_id': 'case', 'purpose': 'expense_evidence'},
        ],
      });
      await tester.pump();
      await tester.pump();
      final oldUrgent = currentPlayer(tester);
      expect(oldUrgent.assetId, 'urgent');
      expect(oldUrgent.semanticLabel, 'Video de urgencia');
      expect(find.text('Apoyo urgente'), findsOneWidget);
      expect(find.text('Conoce su historia'), findsWidgets);
      // These callbacks check cursor behavior, not real playback acceptance.
      oldUrgent.onComplete!();
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'thanks');
      oldUrgent.onComplete!();
      oldUrgent.onProgress?.call(.8);
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'thanks');
      expect(currentPlayer(tester).semanticLabel, 'Video de agradecimiento');
      expect(find.text('Da un pequeño gesto,'), findsOneWidget);
      expect(
        find.text('haz una GRAN diferencia.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Apoyo urgente'), findsNothing);
      expect(find.text('Conoce su historia'), findsWidgets);
      currentPlayer(tester).onComplete!();
      await tester.pump();
      expect(currentPhoto(tester), 'public/gallery');
      stepStory(tester);
      await tester.pump();
      expect(currentPhoto(tester), 'update/public-photo');
      expect(find.text('Avance publicado'), findsOneWidget);
      stepStory(tester);
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'public-advance');
      expect(find.text('Avance público'), findsOneWidget);
      currentPlayer(tester).onComplete!();
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'bye');
      expect(find.text('Despedida'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('late public updates do not restart the current thanks video', (
    tester,
  ) async {
    final updates = PendingStoryUpdates();
    final repository = VideoRepository(
      identity: () => null,
      invoke: (body) async {
        if (body['action'] == 'public_list') {
          return {
            'items': [
              {
                'id': 'advance',
                'parent_id': 'case',
                'purpose': 'public_update',
              },
              {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
            ],
          };
        }
        throw const VideoFailure('fixture_does_not_grant_playback');
      },
    );
    addTearDown(repository.dispose);
    await mountVideoStories(tester, repository, updates: updates);
    stepStory(tester);
    await tester.pump();
    final before = currentPlayer(tester);
    expect(before.assetId, 'thanks');
    before.onProgress?.call(.4);
    updates.pending.complete([
      CaseUpdate({
        'id': 'late',
        'case_id': 'case',
        'published_at': '2026-10-24T00:00:00Z',
        'body': 'Avance tardío aprobado',
        'photos': ['update/late-photo'],
      }),
    ]);
    await tester.pump();
    await tester.pump();
    expect(currentPlayer(tester).key, before.key);
    expect(currentPlayer(tester).assetId, 'thanks');
    expect(
      tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .any((p) => p.value == .4),
      isTrue,
    );
    currentPlayer(tester).onComplete!();
    await tester.pump();
    expect(currentPhoto(tester), 'update/late-photo');
    stepStory(tester);
    await tester.pump();
    expect(currentPlayer(tester).assetId, 'advance');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'successful retry preserves the visible photo and defers recovered clips without skipping',
    (tester) async {
      final retry = Completer<Map<String, dynamic>>();
      var calls = 0;
      final repository = VideoRepository(
        identity: () => null,
        invoke: (body) async {
          if (body['action'] == 'public_list') {
            calls++;
            if (calls == 1) throw const VideoFailure('fixture_lookup_failed');
            return retry.future;
          }
          throw const VideoFailure('fixture_does_not_grant_playback');
        },
      );
      addTearDown(repository.dispose);
      await mountVideoStories(
        tester,
        repository,
        photos: ['public/hero', 'public/gallery'],
      );
      stepStory(tester);
      await tester.pump();
      expect(currentPhoto(tester), 'public/gallery');
      await tester.tap(find.text('Reintentar videos'));
      await tester.pump();
      retry.complete({
        'items': [
          {'id': 'bye', 'parent_id': 'case', 'purpose': 'farewell'},
          {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
          {'id': 'urgent', 'parent_id': 'case', 'purpose': 'urgency'},
        ],
      });
      await tester.pump();
      await tester.pump();
      expect(currentPhoto(tester), 'public/gallery');
      stepStory(tester);
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'urgent');
      currentPlayer(tester).onComplete!();
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'thanks');
      currentPlayer(tester).onComplete!();
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'bye');
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a queued advance waits while backgrounded and previous cancels its intent',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final repository = VideoRepository(
        identity: () => null,
        invoke: (body) async {
          if (body['action'] == 'public_list') return pending.future;
          throw const VideoFailure('fixture_does_not_grant_playback');
        },
      );
      addTearDown(repository.dispose);
      await mountVideoStories(tester, repository);
      stepStory(tester);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pending.complete({
        'items': [
          {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
        ],
      });
      await tester.pump();
      await tester.pump();
      expect(currentPhoto(tester), 'public/hero');
      // Go back while the pending intent exists. Foreground must not auto-skip.
      stepStory(tester, forward: false);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(currentPhoto(tester), 'public/hero');
      stepStory(tester);
      await tester.pump();
      expect(currentPlayer(tester).assetId, 'thanks');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('public detail labels retain the server-approved video purpose', (
    tester,
  ) async {
    final repository = VideoRepository(
      identity: () => null,
      invoke: (body) async {
        if (body['action'] == 'public_list') {
          return {
            'items': [
              {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
              {
                'id': 'private',
                'parent_id': 'case',
                'purpose': 'expense_evidence',
              },
            ],
          };
        }
        throw const VideoFailure('fixture_does_not_grant_playback');
      },
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueVideosRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PublicRescueVideos('case')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Agradecimiento'), findsOneWidget);
    expect(currentPlayer(tester).assetId, 'thanks');
    expect(currentPlayer(tester).semanticLabel, 'Video de agradecimiento');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a failed video lookup releases photo navigation to the next case',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final repository = VideoRepository(
        identity: () => null,
        invoke: (body) async {
          if (body['action'] == 'public_list' && body['parent_id'] == 'first') {
            return pending.future;
          }
          return {'items': []};
        },
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueVideosRepositoryProvider.overrideWithValue(repository),
            rescueRepositoryProvider.overrideWithValue(StoryRepository()),
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
          ],
          child: MaterialApp(
            home: SupportStories(
              records: [
                story('first', ['first/photo']),
                story('second', ['second/photo']),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final firstSurface = tester.widget<GestureDetector>(
        find
            .byWidgetPredicate(
              (widget) => widget is GestureDetector && widget.onTapUp != null,
            )
            .first,
      );
      firstSurface.onTapUp!(
        TapUpDetails(
          kind: PointerDeviceKind.touch,
          localPosition: const Offset(700, 100),
        ),
      );
      await tester.pump();
      expect(find.text('first'), findsOneWidget);
      pending.completeError(const VideoFailure('backend_unavailable'));
      await tester.pump();
      await tester.pump();
      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  test('public video queue excludes private evidence, unrelated parents and malformed IDs', () {
    expect(
      publicRescueVideoIds([
        {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
        {'id': 'receipt', 'parent_id': 'case', 'purpose': 'expense_evidence'},
        {'id': 'other', 'parent_id': 'other', 'purpose': 'thanks'},
        {'id': '', 'parent_id': 'case', 'purpose': 'farewell'},
        {'id': 'thanks', 'parent_id': 'case', 'purpose': 'thanks'},
      ], 'case'),
      ['thanks'],
    );
  });
  testWidgets(
    'a real video segment uses playback completion rather than the photo timer',
    (tester) async {
      final repository = VideoRepository(
        identity: () => null,
        invoke: (body) async {
          if (body['action'] == 'public_list') {
            return {
              'items': [
                {'id': 'clip', 'parent_id': 'case', 'purpose': 'thanks'},
              ],
            };
          }
          throw const VideoFailure('fixture_no_playback_lease');
        },
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueVideosRepositoryProvider.overrideWithValue(repository),
            rescueRepositoryProvider.overrideWithValue(StoryRepository()),
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
          ],
          child: MaterialApp(
            home: SupportStories(
              records: [
                story('case', ['public/photo']),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Advance the photo manually. No fictitious poster counts as playing video.
      final photoSurface = find
          .byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onTapUp != null,
          )
          .first;
      final gesture = tester.widget<GestureDetector>(photoSurface);
      gesture.onTapUp?.call(
        TapUpDetails(
          kind: PointerDeviceKind.touch,
          localPosition: const Offset(700, 100),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(ModeratedVideo), findsOneWidget);
      final player = tester.widget<ModeratedVideo>(find.byType(ModeratedVideo));
      expect(player.autoplay, isTrue);
      expect(player.onComplete, isNotNull);
      player.onProgress?.call(.4);
      await tester.pump(const Duration(seconds: 9));
      expect(find.byType(ModeratedVideo), findsOneWidget);
      final bars = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bars.any((bar) => bar.value == .4), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
