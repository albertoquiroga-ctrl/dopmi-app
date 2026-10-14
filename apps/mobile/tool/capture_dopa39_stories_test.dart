// Synthetic public fixtures; no network, accounts or payments.
import 'dart:convert';
import 'dart:io';

import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/rescue_test.dart' show FakeCaseUpdates;
import 'capture_dde1_support_test.dart' show SupportCaptureRescue, captureCase;
import 'capture_design_test.dart' show saveCapture;

void main() {
  testWidgets('DOPA39 story later photo error pause advance close evidence', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load(
            family == 'MaterialIcons'
                ? 'fonts/MaterialIcons-Regular.otf'
                : 'assets/fonts/$family.ttf',
          ),
        );
      await tester.runAsync(loader.load);
    }
    final output = Directory('../../.tools/dopa39-stories');
    final bytes = (await tester.runAsync(
      () => File('tool/fixtures/milo.png').readAsBytes(),
    ))!;
    await tester.runAsync(() => output.create(recursive: true));
    final frames = <Map<String, Object?>>[];
    for (final spec in [
      ('normal', const Size(377, 852), 1.0),
      ('115', const Size(377, 852), 1.15),
      ('200', const Size(320, 640), 2.0),
    ]) {
      for (final failure in [false, true]) {
        if (Platform.environment['CAPTURE_ERROR_ONLY'] == 'true' && !failure) {
          continue;
        }
        tester.view.physicalSize = spec.$2;
        var unavailable = failure;
        var downloads = 0;
        final runtime = PhotoRuntime(
          store: MemoryPhotoStore(),
          download: (_, _) async {
            downloads++;
            if (unavailable) throw StateError('synthetic unavailable');
            return bytes;
          },
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ProviderScope(
              key: UniqueKey(),
              overrides: [
                rescueRepositoryProvider.overrideWithValue(
                  SupportCaptureRescue(),
                ),
                caseUpdateRepositoryProvider.overrideWithValue(
                  FakeCaseUpdates(),
                ),
                photoRuntimeProvider.overrideWithValue(runtime),
              ],
              child: MaterialApp(
                theme: dopmiTheme(),
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(spec.$3)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              SupportStories(records: [captureCase]),
                        ),
                      ),
                      child: const Text('Abrir fixture'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir fixture'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // Complete local file decoding before establishing the sampled clock.
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
        }
        Future<void> frame(String state, int elapsed) async {
          expect(tester.takeException(), isNull);
          final photos = find.byType(RemotePhoto);
          frames.add({
            'scale': spec.$3,
            'state': state,
            'widgetClockMs': elapsed,
            'path': photos.evaluate().isEmpty
                ? null
                : tester.widget<RemotePhoto>(photos).source.path,
            'progress': find.byType(LinearProgressIndicator).evaluate().isEmpty
                ? null
                : tester
                      .widget<LinearProgressIndicator>(
                        find.byType(LinearProgressIndicator).first,
                      )
                      .value,
          });
          await tester.runAsync(
            () => saveCapture(boundary, '${output.path}/${spec.$1}-$state.png'),
          );
        }

        if (failure) {
          // PhotoRuntime retries once after its configured one-second delay.
          await tester.pump(const Duration(seconds: 2));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          expect(find.text('Reintentar foto'), findsOneWidget);
          final recovery = tester.getRect(find.text('Reintentar foto'));
          expect(
            recovery.bottom,
            lessThan(tester.getRect(find.text('Luna')).top),
          );
          expect(
            recovery.top,
            greaterThan(
              tester.getRect(find.byTooltip('Cerrar historias')).bottom,
            ),
          );
          await frame('error', 0);
          final failedDownloads = downloads;
          unavailable = false;
          await tester.tap(find.text('Reintentar foto'));
          await tester.pump();
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump();
          }
          expect(downloads, greaterThan(failedDownloads));
          expect(find.text('Reintentar foto'), findsNothing);
          expect(
            tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path,
            'fixture/luna.jpg',
          );
          expect(find.text('Luna'), findsOneWidget);
          await frame('recovered', 0);
        } else {
          tester.widget<RemotePhoto>(find.byType(RemotePhoto)).onDisplayed!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1300));
          await frame('elapsed', 1300);
          final progress = tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator).first,
              )
              .value;
          final hold = await tester.startGesture(const Offset(180, 300));
          await tester.pump(const Duration(milliseconds: 2000));
          expect(
            tester
                .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator).first,
                )
                .value,
            progress,
          );
          await frame('paused', 3300);
          await hold.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1300));
          await frame('resumed', 4600);
          final rect = tester.getRect(find.byType(RemotePhoto));
          await tester.tapAt(
            Offset(rect.left + rect.width * .8, rect.top + 80),
          );
          await tester.pump();
          for (var i = 0; i < 5; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump();
          }
          expect(
            tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path,
            'fixture/luna-2.jpg',
          );
          await frame('second-photo', 4600);
        }
        await tester.tap(find.byTooltip('Cerrar historias'));
        await tester.pumpAndSettle();
        expect(find.text('Abrir fixture'), findsOneWidget);
        await frame(failure ? 'error-closed' : 'closed', 4600);
        await tester.pumpWidget(const SizedBox.shrink());
        runtime.dispose();
      }
    }
    await tester.runAsync(
      () => File('${output.path}/frames.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(frames)),
    );
  });
}
