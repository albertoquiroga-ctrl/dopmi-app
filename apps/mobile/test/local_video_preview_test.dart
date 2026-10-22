import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/local_video_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'support/local_video_controller.dart';

Widget preview(
  LocalVideoTestController controller, {
  Future<void> Function()? upload,
  bool visible = true,
}) => MaterialApp(
  home: Scaffold(
    body: TickerMode(
      enabled: visible,
      child: LocalVideoPreview(
        file: XFile.fromData(Uint8List(5)),
        controllerFactory: (_) => controller,
        onUpload: upload ?? () async {},
        onDiscard: () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('decoder failure during acceptance still permits local discard', (
    tester,
  ) async {
    final controller = LocalVideoTestController();
    var uploads = 0;
    await tester.pumpWidget(
      preview(
        controller,
        upload: () async {
          uploads++;
        },
      ),
    );
    await tester.pumpAndSettle();
    final pausing = Completer<void>();
    controller.pausing = pausing;
    await tester.tap(find.text('Subir video'));
    await tester.pump();
    controller.value = controller.value.copyWith(
      errorDescription: 'decoder_interrupted',
    );
    await tester.pump();
    pausing.complete();
    await tester.pumpAndSettle();
    expect(uploads, 0);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Subir video'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Descartar selección'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.textContaining('La reproducción se interrumpió.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final failure in [
    'play',
    'volume',
    'background-pause',
    'offscreen-pause',
  ]) {
    testWidgets('platform $failure failure blocks upload and allows discard', (
      tester,
    ) async {
      final controller = LocalVideoTestController();
      var uploads = 0;
      final visible = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              child: LocalVideoPreview(
                file: XFile.fromData(Uint8List(5)),
                controllerFactory: (_) => controller,
                onUpload: () async {
                  uploads++;
                },
                onDiscard: () {},
              ),
              builder: (_, value, child) =>
                  TickerMode(enabled: value, child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (failure == 'play') {
        controller.failPlay = true;
        await tester.tap(find.byTooltip('Reproducir vista previa'));
      } else if (failure == 'volume') {
        controller.failVolume = true;
        await tester.tap(find.byTooltip('Activar sonido de vista previa'));
      } else {
        controller.failPause = true;
        if (failure == 'background-pause') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          visible.value = false;
        }
      }
      await tester.pumpAndSettle();
      if (failure == 'background-pause') {
        // Paused apps do not draw frames. Verify the retained failure on return.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Subir video'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Descarta la selección'), findsOneWidget);
      expect(find.text('Descartar selección'), findsOneWidget);
      expect(uploads, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      visible.dispose();
    });
  }

  for (final interruption in [
    'background',
    'offscreen',
    'dispose',
    'background-return',
    'offscreen-return',
  ]) {
    testWidgets('deferred replay seek cannot restart after $interruption', (
      tester,
    ) async {
      final seeking = Completer<void>();
      final controller = LocalVideoTestController(seeking: seeking);
      final visible = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              child: LocalVideoPreview(
                file: XFile.fromData(Uint8List(5)),
                controllerFactory: (_) => controller,
                onUpload: () async {},
                onDiscard: () {},
              ),
              builder: (_, value, child) =>
                  TickerMode(enabled: value, child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.value = controller.value.copyWith(
        position: controller.duration,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Reproducir vista previa'));
      await tester.pump();
      if (interruption.startsWith('background')) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else if (interruption.startsWith('offscreen')) {
        visible.value = false;
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pump();
      if (interruption == 'background-return') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      } else if (interruption == 'offscreen-return') {
        visible.value = true;
        await tester.pump();
      }
      seeking.complete();
      await tester.pumpAndSettle();
      expect(controller.playRequests, 0);
      expect(controller.value.isPlaying, isFalse);
      if (interruption.startsWith('background')) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpWidget(const SizedBox());
      visible.dispose();
    });
  }

  testWidgets(
    'local review shows duration, starts silent and never autoplays',
    (tester) async {
      final controller = LocalVideoTestController();
      await tester.pumpWidget(preview(controller));
      await tester.pumpAndSettle();
      expect(find.text('Duración: 2.0 s'), findsOneWidget);
      expect(controller.volumes, [0]);
      expect(controller.plays, 0);
      await tester.tap(find.byTooltip('Reproducir vista previa'));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      await tester.tap(find.byTooltip('Activar sonido de vista previa'));
      await tester.pump();
      expect(controller.value.volume, 1);
      await tester.tap(find.byTooltip('Pausar vista previa'));
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.disposed, isTrue);
    },
  );

  for (final duration in [Duration.zero, const Duration(milliseconds: 60001)]) {
    testWidgets('invalid duration $duration never permits uploading', (
      tester,
    ) async {
      var uploads = 0;
      final controller = LocalVideoTestController(duration: duration);
      await tester.pumpWidget(
        preview(controller, upload: () async => uploads++),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No pudimos revisar este video.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Subir video'),
            )
            .onPressed,
        isNull,
      );
      expect(uploads, 0);
      expect(controller.disposed, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('decoder failure blocks uploading and still offers discard', (
    tester,
  ) async {
    final controller = LocalVideoTestController(decoderFails: true);
    await tester.pumpWidget(preview(controller));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No pudimos revisar este video.'),
      findsOneWidget,
    );
    expect(find.text('Descartar selección'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Subir video'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('exactly sixty seconds remains a reviewable local video', (
    tester,
  ) async {
    final controller = LocalVideoTestController(
      duration: const Duration(seconds: 60),
    );
    await tester.pumpWidget(preview(controller));
    await tester.pumpAndSettle();
    expect(find.text('Duración: 60.0 s'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Subir video'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background pauses local playback and returning does not restart it',
    (tester) async {
      final controller = LocalVideoTestController();
      await tester.pumpWidget(preview(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reproducir vista previa'));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      expect(controller.plays, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'offscreen local preview pauses and never restarts by visibility',
    (tester) async {
      final controller = LocalVideoTestController();
      final visible = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              child: LocalVideoPreview(
                file: XFile.fromData(Uint8List(5)),
                controllerFactory: (_) => controller,
                onUpload: () async {},
                onDiscard: () {},
              ),
              builder: (_, value, child) =>
                  TickerMode(enabled: value, child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reproducir vista previa'));
      await tester.pump();
      visible.value = false;
      await tester.pumpAndSettle();
      expect(controller.value.isPlaying, isFalse);
      visible.value = true;
      await tester.pumpAndSettle();
      expect(controller.value.isPlaying, isFalse);
      expect(controller.plays, 1);
      await tester.pumpWidget(const SizedBox());
      visible.dispose();
    },
  );

  testWidgets('late initialization after leaving cannot authorize an upload', (
    tester,
  ) async {
    final initialized = Completer<void>();
    final controller = LocalVideoTestController(initializing: initialized);
    var uploads = 0;
    await tester.pumpWidget(preview(controller, upload: () async => uploads++));
    await tester.pump();
    expect(find.text('Preparando vista previa…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    initialized.complete();
    await tester.pumpAndSettle();
    expect(controller.disposed, isTrue);
    expect(uploads, 0);
  });
}
