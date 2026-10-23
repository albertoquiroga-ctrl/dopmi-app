import 'dart:async';

import 'package:dopmi_mobile/core/media/moderated_video.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_video_controller.dart';

VideoRepository playbackRepository() => VideoRepository(
  identity: () => 'owner:session',
  invoke: (_) async => {
    'hls': 'https://videodelivery.net/test/manifest/video.m3u8',
    'poster': 'https://videodelivery.net/test/thumbnails/thumbnail.jpg',
    'expires_at':
        DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 120))
            .millisecondsSinceEpoch ~/
        1000,
  },
);

void main() {
  for (final failure in [
    'play',
    'pause',
    'hold-pause',
    'background-pause',
    'offscreen-pause',
  ]) {
    testWidgets('platform $failure failure offers a fresh playback retry', (
      tester,
    ) async {
      final first = LocalVideoTestController();
      final retried = LocalVideoTestController();
      final controllers = [first, retried];
      var factoryCalls = 0;
      var readyCalls = 0;
      final visible = ValueNotifier(true);
      final repository = playbackRepository();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        visible.dispose();
        repository.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, isVisible, _) => TickerMode(
                enabled: isVisible,
                child: ModeratedVideo(
                  repository: repository,
                  assetId: 'approved-clip',
                  autoplay: failure != 'play',
                  controllerFactory: (_) => controllers[factoryCalls++],
                  onPlaybackReady: () => readyCalls++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(readyCalls, 1);
      if (failure == 'play') {
        first.failPlay = true;
        await tester.tap(find.byTooltip('Reproducir video'));
      } else {
        first.failPause = true;
        if (failure == 'pause') {
          await tester.tap(find.byTooltip('Pausar video'));
        } else if (failure == 'hold-pause') {
          final hold = tester.widget<GestureDetector>(
            find.descendant(
              of: find.byType(ModeratedVideo),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is GestureDetector &&
                    widget.onLongPressStart != null,
              ),
            ),
          );
          // Decoder seam: recognized callback, not physical gesture evidence.
          hold.onLongPressStart!(const LongPressStartDetails());
        } else if (failure == 'background-pause') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          // Enable frames without resuming playback or renewing the lease.
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        } else {
          visible.value = false;
        }
      }
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('No pudimos reproducir este video.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar video'), findsOneWidget);
      expect(find.byTooltip('Pausar video'), findsNothing);
      expect(find.byTooltip('Reproducir video'), findsNothing);
      expect(first.disposed, isTrue);
      expect(readyCalls, 1);

      await tester.tap(find.text('Reintentar video'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reintentar video'), findsNothing);
      expect(find.byTooltip('Activar sonido'), findsOneWidget);
      expect(factoryCalls, 2);
      expect(retried.disposed, isFalse);
      expect(
        retried.value.isPlaying,
        failure == 'play' || failure == 'hold-pause',
      );
      expect(readyCalls, 2);
    });
  }

  testWidgets(
    'late pause failure from a replaced asset preserves new playback',
    (tester) async {
      final previous = LocalVideoTestController();
      final replacement = LocalVideoTestController();
      final pausing = Completer<void>();
      final asset = ValueNotifier('first-clip');
      var factoryCalls = 0;
      final repository = playbackRepository();
      addTearDown(() async {
        if (!pausing.isCompleted) pausing.complete();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        asset.dispose();
        repository.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: asset,
              builder: (_, assetId, _) => ModeratedVideo(
                repository: repository,
                assetId: assetId,
                controllerFactory: (_) =>
                    factoryCalls++ == 0 ? previous : replacement,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      previous.pausing = pausing;
      await tester.tap(find.byTooltip('Pausar video'));
      await tester.pump();
      asset.value = 'replacement-clip';
      await tester.pumpAndSettle();
      expect(replacement.value.isPlaying, isTrue);
      expect(replacement.disposed, isFalse);
      previous.failPause = true;
      pausing.complete();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(replacement.disposed, isFalse);
      expect(replacement.value.isPlaying, isTrue);
      expect(find.text('Reintentar video'), findsNothing);
      expect(find.byTooltip('Pausar video'), findsOneWidget);
      expect(factoryCalls, 2);
    },
  );

  testWidgets('initial autoplay failure never reports playback ready', (
    tester,
  ) async {
    final controller = LocalVideoTestController()..failPlay = true;
    var readyCalls = 0;
    final repository = playbackRepository();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      repository.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeratedVideo(
            repository: repository,
            assetId: 'approved-clip',
            controllerFactory: (_) => controller,
            onPlaybackReady: () => readyCalls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(readyCalls, 0);
    expect(controller.disposed, isTrue);
    expect(find.text('Reintentar video'), findsOneWidget);
  });

  testWidgets(
    'sound failure after initialization shows retry and releases playback',
    (tester) async {
      final controller = LocalVideoTestController();
      final repository = VideoRepository(
        identity: () => 'owner:session',
        invoke: (_) async => {
          'hls': 'https://videodelivery.net/test/manifest/video.m3u8',
          'poster': 'https://videodelivery.net/test/thumbnails/thumbnail.jpg',
          'expires_at':
              DateTime.now()
                  .toUtc()
                  .add(const Duration(seconds: 120))
                  .millisecondsSinceEpoch ~/
              1000,
        },
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        repository.dispose();
      });
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
      expect(controller.value.isPlaying, isTrue);
      expect(controller.value.volume, 0);
      controller.failVolume = true;

      await tester.tap(find.byTooltip('Activar sonido'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('No pudimos reproducir este video.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar video'), findsOneWidget);
      expect(find.byTooltip('Silenciar video'), findsNothing);
      expect(find.byTooltip('Pausar video'), findsNothing);
      expect(controller.disposed, isTrue);
    },
  );

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
