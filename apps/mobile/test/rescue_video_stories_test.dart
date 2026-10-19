import 'dart:ui' show PointerDeviceKind;
import 'dart:async';

import 'package:dopmi_mobile/core/media/moderated_video.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rescue_test.dart' show FakeCaseUpdates;
import 'support_stories_test.dart' show StoryRepository, story;

void main() {
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
