import 'dart:io';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'support/local_video_controller.dart';

// Real Flutter layout with a decoder adapter fixture, not device playback or a
// claim about the final case editor. Footer reserves the case form's controls.
void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await inter.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final view in [
    ('normal', const Size(377, 852), 1.0),
    ('samsung115', const Size(411, 891), 1.15),
    ('large', const Size(320, 740), 2.0),
  ]) {
    for (final decoderFails in [false, true]) {
      testWidgets('local video review ${view.$1} decoderError=$decoderFails', (
        tester,
      ) async {
        tester.view.physicalSize = view.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <Map<String, dynamic>>[];
        final repo = VideoRepository(
          identity: () => 'fixture:session',
          invoke: (body) async {
            calls.add(Map.of(body));
            throw StateError('Selection must stay local');
          },
        );
        addTearDown(repo.dispose);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dopmiTheme(rescuer: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(view.$3)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: Scaffold(
                appBar: AppBar(title: const Text('Cuéntanos')),
                body: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: VideoUpload(
                            repository: repo,
                            parentId: 'fixture-case',
                            parentVersion: 1,
                            purpose: 'thanks',
                            label: 'Agradecimiento',
                            picker: (_) async => XFile.fromData(Uint8List(5)),
                            previewControllerFactory: (_) =>
                                LocalVideoTestController(
                                  decoderFails: decoderFails,
                                ),
                            onReady: (_) => fail('No upload requested'),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              onPressed: null,
                              child: Text('Continuar'),
                            ),
                            TextButton(
                              onPressed: null,
                              child: Text('Guardar borrador'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Elegir video'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(calls, isEmpty);
        final upload = find.widgetWithText(FilledButton, 'Subir video');
        expect(
          tester.widget<FilledButton>(upload).onPressed == null,
          decoderFails,
        );
        final state = decoderFails ? 'error' : 'ready';
        Future<void> capture(String position) async {
          final dir = Platform.environment['DOPMI_CAPTURE_DIR'];
          if (dir == null || dir.isEmpty) return;
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = Directory(dir);
            await output.create(recursive: true);
            await File('${output.path}/preview-${view.$1}-$state-$position.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('top');
        final discard = find.widgetWithText(TextButton, 'Descartar selección');
        await tester.ensureVisible(discard);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(discard);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(view.$2.width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(view.$2.height));
        await capture('actions');
        await tester.tap(discard);
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        expect(find.text('Elegir video'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
