import 'dart:async';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/media/moderated_video.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'rescue_test.dart' show EmptySupportRescue, FakeCaseUpdates;
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

double contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

void main() {
  for (final story in [false, true]) {
    testWidgets(
      'pending video indicator contrasts with ${story ? 'dark stories' : 'default light surface'}',
      (tester) async {
        tester.view.physicalSize = const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<Map<String, dynamic>>();
        final repository = VideoRepository(
          identity: () => 'owner:session',
          invoke: (request) async {
            if (request['action'] == 'public_list') {
              return {
                'items': [
                  {
                    'id': 'approved-clip',
                    'parent_id': 'public-case',
                    'purpose': 'thanks',
                  },
                ],
              };
            }
            expect(request, {'action': 'playback', 'id': 'approved-clip'});
            return pending.future;
          },
        );
        final boundaryKey = GlobalKey();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          repository.dispose();
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rescueVideosRepositoryProvider.overrideWithValue(repository),
              rescueRepositoryProvider.overrideWithValue(EmptySupportRescue()),
              caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
            ],
            child: MaterialApp(
              theme: dopmiTheme(),
              home: RepaintBoundary(
                key: boundaryKey,
                child: story
                    ? SupportStories(
                        records: [
                          RescueRecord({
                            'id': 'public-case',
                            'kind': 'case',
                            'status': 'approved',
                            'public_data': {'pet_name': 'Luna'},
                          }),
                        ],
                      )
                    : Scaffold(
                        body: ModeratedVideo(
                          repository: repository,
                          assetId: 'approved-clip',
                        ),
                      ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final indicator = find.descendant(
          of: find.byType(ModeratedVideo),
          matching: find.byType(CircularProgressIndicator),
        );
        expect(indicator, findsOneWidget);
        expect(find.byType(VideoPlayer), findsNothing);
        expect(pending.isCompleted, isFalse);
        final colors = (await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            Color pixelAt(Offset point) {
              final offset =
                  (point.dy.floor() * image.width + point.dx.floor()) * 4;
              return Color.fromARGB(
                bytes!.getUint8(offset + 3),
                bytes.getUint8(offset),
                bytes.getUint8(offset + 1),
                bytes.getUint8(offset + 2),
              );
            }

            final origin = tester.getTopLeft(find.byKey(boundaryKey));
            final bounds = tester.getRect(indicator).shift(-origin);
            final background = pixelAt(
              Offset(bounds.left - 8, bounds.center.dy),
            );
            var painted = background;
            // Find a fully painted arc pixel instead of assuming its angle or
            // reading a constructor/theme color that might not reach the paint.
            for (var y = bounds.top.ceil(); y < bounds.bottom.floor(); y++) {
              for (var x = bounds.left.ceil(); x < bounds.right.floor(); x++) {
                final pixel = pixelAt(Offset(x.toDouble(), y.toDouble()));
                if (contrastRatio(pixel, background) >
                    contrastRatio(painted, background)) {
                  painted = pixel;
                }
              }
            }
            return [background, painted];
          } finally {
            image.dispose();
          }
        }))!;
        if (story) {
          const storySurface = Color(0xff0d0d0d);
          final scaffold = tester.widget<Scaffold>(
            find.descendant(
              of: find.byType(SupportStories),
              matching: find.byType(Scaffold),
            ),
          );
          expect(scaffold.backgroundColor, storySurface);
          // The real story gradient can darken the scaffold behind the arc.
          expect(colors.first.a, 1);
          expect(
            colors.first.computeLuminance(),
            lessThanOrEqualTo(storySurface.computeLuminance()),
          );
        } else {
          expect(colors.first, dopmiTheme().colorScheme.surface);
        }
        expect(
          contrastRatio(colors.first, colors.last),
          greaterThanOrEqualTo(3),
          reason: 'The painted loading arc must remain visible on its surface',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(640, 360), const Size(360, 640)]) {
    for (final fit in [null, BoxFit.cover]) {
      testWidgets(
        'media fitting preserves frame and controls; size=$size fit=$fit',
        (tester) async {
          final controller = LocalVideoTestController();
          final repository = playbackRepository();
          const frameKey = ValueKey('video-frame');
          const overlayKey = ValueKey('media-treatment');
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            repository.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    key: frameKey,
                    width: 320,
                    height: 560,
                    child: ModeratedVideo(
                      repository: repository,
                      assetId: 'approved-clip',
                      autoplay: false,
                      controllerFactory: (_) => controller,
                      fit: fit,
                      mediaOverlay: const ColoredBox(
                        key: overlayKey,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          controller.value = controller.value.copyWith(size: size);
          await tester.pump();
          final frame = tester.renderObject<RenderBox>(find.byKey(frameKey));
          final video = tester.renderObject<RenderBox>(
            find.byType(VideoPlayer),
          );
          final projected = MatrixUtils.transformRect(
            video.getTransformTo(frame),
            Offset.zero & video.size,
          );
          final frameRect = Offset.zero & frame.size;
          expect(frame.size, const Size(320, 560));
          if (fit == null) {
            // Existing embedded-player layout remains unchanged by default.
            expect(projected, frameRect);
            expect(find.byType(FittedBox), findsNothing);
          } else {
            expect(
              projected.width / projected.height,
              closeTo(size.aspectRatio, .000001),
            );
            expect(projected.left, lessThanOrEqualTo(.001));
            expect(projected.top, lessThanOrEqualTo(.001));
            expect(
              projected.right,
              greaterThanOrEqualTo(frameRect.right - .001),
            );
            expect(
              projected.bottom,
              greaterThanOrEqualTo(frameRect.bottom - .001),
            );
            final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
            expect(fitted.clipBehavior, Clip.hardEdge);
          }
          expect(
            tester.getRect(find.byKey(overlayKey)),
            tester.getRect(find.byKey(frameKey)),
          );
          for (final label in ['Reproducir video', 'Activar sonido']) {
            final control = tester.renderObject<RenderBox>(
              find.byTooltip(label),
            );
            final projectedControl = MatrixUtils.transformRect(
              control.getTransformTo(frame),
              Offset.zero & control.size,
            );
            expect(projectedControl.width, closeTo(control.size.width, .001));
            expect(projectedControl.height, closeTo(control.size.height, .001));
            expect(
              projectedControl.width,
              closeTo(projectedControl.height, .001),
            );
            expect(frameRect.contains(projectedControl.center), isTrue);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('media overlay preserves visible and working playback controls', (
    tester,
  ) async {
    final controller = LocalVideoTestController();
    final repository = playbackRepository();
    final showOverlay = ValueNotifier(false);
    final boundaryKey = GlobalKey();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      showOverlay.dispose();
      repository.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: dopmiTheme(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 320,
                height: 560,
                child: ColoredBox(
                  color: Colors.white,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: showOverlay,
                    builder: (_, enabled, _) => ModeratedVideo(
                      repository: repository,
                      assetId: 'approved-clip',
                      autoplay: false,
                      controllerFactory: (_) => controller,
                      mediaOverlay: enabled
                          ? const ColoredBox(color: Colors.black)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<List<Color>> sampleColors() async =>
        (await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final origin = tester.getTopLeft(find.byKey(boundaryKey));
          Color pixelAt(Offset point) {
            final offset =
                (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return Color.fromARGB(
              bytes!.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          }

          final labels = ['Reproducir video', 'Activar sonido'];
          final fills = <Color>[
            // Sample the filled circle beside the icon, away from its edge.
            for (final label in labels)
              pixelAt(
                tester.getCenter(find.byTooltip(label)) -
                    origin -
                    const Offset(14, 0),
              ),
          ];
          final glyphs = <Color>[];
          for (var i = 0; i < labels.length; i++) {
            final icon = find.descendant(
              of: find.byTooltip(labels[i]),
              matching: find.byType(Icon),
            );
            final bounds = tester.getRect(icon).shift(-origin);
            var glyph = fills[i];
            // The icon bounds stay inside the filled circle. Select an actual
            // painted glyph pixel rather than guessing a font-specific point.
            for (var y = bounds.top.ceil(); y < bounds.bottom.floor(); y++) {
              for (var x = bounds.left.ceil(); x < bounds.right.floor(); x++) {
                final pixel = pixelAt(Offset(x.toDouble(), y.toDouble()));
                if (contrastRatio(pixel, fills[i]) >
                    contrastRatio(glyph, fills[i])) {
                  glyph = pixel;
                }
              }
            }
            glyphs.add(glyph);
          }
          final colors = [...fills, ...glyphs, pixelAt(const Offset(160, 100))];
          image.dispose();
          return colors;
        }))!;

    final withoutOverlay = await sampleColors();
    expect(withoutOverlay.last.computeLuminance(), greaterThan(.8));
    showOverlay.value = true;
    await tester.pumpAndSettle();
    final withOverlay = await sampleColors();
    expect(withOverlay.take(4), withoutOverlay.take(4));
    expect(withOverlay.last, Colors.black);
    expect(withOverlay.last, isNot(withoutOverlay.last));
    // Circle brightness did not catch the production theme's translucent fill.
    // Measure the rendered icon against its fill on both light and dark media.
    for (final colors in [withoutOverlay, withOverlay]) {
      for (var i = 0; i < 2; i++) {
        expect(
          contrastRatio(colors[i], colors[i + 2]),
          greaterThanOrEqualTo(3),
          reason: 'Playback and sound icons must contrast with their fill',
        );
      }
    }
    expect(controller.value.volume, 0);
    expect(controller.value.isPlaying, isFalse);
    await tester.tap(find.byTooltip('Activar sonido'));
    await tester.pumpAndSettle();
    expect(controller.value.volume, 1);
    await tester.tap(find.byTooltip('Reproducir video'));
    await tester.pumpAndSettle();
    expect(controller.value.isPlaying, isTrue);
    expect(find.byTooltip('Pausar video'), findsOneWidget);
    expect(find.byTooltip('Silenciar video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
