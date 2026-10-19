import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/core/media/moderated_video.dart';

void main() {
  testWidgets(
    'failed authorization offers retry without constructing a decoder or calling readiness',
    (tester) async {
      var ready = 0;
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (_) async => throw const VideoFailure('denied'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeratedVideo(
              repository: repo,
              assetId: 'private',
              onPlaybackReady: () => ready++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('No pudimos reproducir'), findsOneWidget);
      expect(ready, 0);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets(
    'upload controls require session and never send server requests merely by mounting',
    (tester) async {
      var calls = 0;
      final repo = VideoRepository(
        identity: () => null,
        invoke: (_) async {
          calls++;
          throw const VideoFailure('denied');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 1,
              purpose: 'thanks',
              onReady: (_) {},
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Grabar video'),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
}
