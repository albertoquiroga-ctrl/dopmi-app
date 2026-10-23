import 'package:dopmi_mobile/core/media/moderated_video.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_video_controller.dart';

void main() {
  testWidgets('a sixty second clip completes only at its real end and once', (
    tester,
  ) async {
    final controller = LocalVideoTestController(
      duration: const Duration(seconds: 60),
    );
    final progress = <double>[];
    var completed = 0;
    final repository = VideoRepository(
      identity: () => 'owner:session',
      invoke: (request) async {
        expect(request, {'action': 'playback', 'id': 'approved-clip'});
        return {
          'hls': 'https://videodelivery.net/test/manifest/video.m3u8',
          'poster': 'https://videodelivery.net/test/thumbnails/thumbnail.jpg',
          'expires_at':
              DateTime.now()
                  .toUtc()
                  .add(const Duration(seconds: 120))
                  .millisecondsSinceEpoch ~/
              1000,
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeratedVideo(
            repository: repository,
            assetId: 'approved-clip',
            autoplay: false,
            controllerFactory: (_) => controller,
            onComplete: () => completed++,
            onProgress: progress.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.value = controller.value.copyWith(
      position: const Duration(milliseconds: 59700),
    );
    await tester.pump();
    expect(progress.last, closeTo(.995, .000001));
    expect(completed, 0);
    controller.value = controller.value.copyWith(
      position: const Duration(seconds: 60),
    );
    await tester.pump();
    expect(completed, 0);
    controller.value = controller.value.copyWith(
      position: const Duration(seconds: 60),
      isCompleted: true,
    );
    await tester.pump();
    expect(completed, 1);
    controller.value = controller.value.copyWith(isPlaying: false);
    await tester.pump();
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(controller.disposed, isTrue);
    repository.dispose();
  });

  testWidgets(
    'authorized playback starts muted, honors recognized hold callbacks and pauses on background and exit',
    (tester) async {
      final controller = LocalVideoTestController(
        duration: const Duration(seconds: 60),
      );
      final repository = VideoRepository(
        identity: () => 'owner:session',
        invoke: (request) async {
          expect(request, {'action': 'playback', 'id': 'approved-clip'});
          return {
            'hls': 'https://videodelivery.net/test/manifest/video.m3u8',
            'poster': 'https://videodelivery.net/test/thumbnails/thumbnail.jpg',
            'expires_at':
                DateTime.now()
                    .toUtc()
                    .add(const Duration(seconds: 120))
                    .millisecondsSinceEpoch ~/
                1000,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeratedVideo(
              repository: repository,
              assetId: 'approved-clip',
              controllerFactory: (_) => controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.value.volume, 0);
      expect(controller.value.isPlaying, isTrue);
      await tester.tap(find.byTooltip('Activar sonido'));
      await tester.pump();
      expect(controller.value.volume, 1);
      await tester.tap(find.byTooltip('Pausar video'));
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      await tester.tap(find.byTooltip('Reproducir video'));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      // The decoder adapter keeps playerId=-1, so VideoPlayer renders an empty
      // Container rather than a hittable native Texture. Exercise the public
      // recognized-hold callback contract; this is not physical hit-test evidence.
      final hold = tester.widget<GestureDetector>(
        find.descendant(
          of: find.byType(ModeratedVideo),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is GestureDetector &&
                widget.onLongPressStart != null &&
                widget.onLongPressEnd != null,
          ),
        ),
      );
      hold.onLongPressStart!(const LongPressStartDetails());
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      hold.onLongPressEnd!(const LongPressEndDetails());
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      // SchedulerBinding enables frames in inactive without resuming playback.
      // Unmount there, then restore resumed only after the observer is gone;
      // this test does not claim native lease renewal or reuse a disposed fake.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.disposed, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repository.dispose();
    },
  );
}
