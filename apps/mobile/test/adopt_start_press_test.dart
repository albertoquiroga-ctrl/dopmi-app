import 'dart:ui' as ui;

import 'package:dopmi_mobile/features/adoption/adopt_start_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final large in [false, true]) {
    for (final action in ['Todavía no', 'Sí, contactar rescatista', 'Cerrar']) {
      testWidgets('contact confirmation press and cancel: $action/$large', (
        tester,
      ) async {
        tester.view.physicalSize = large
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final font = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
        await tester.runAsync(font.load);
        final key = GlobalKey();
        var completed = false;
        bool? result;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await confirmAdoptionContact(
                        context,
                        petName: 'Luna',
                        rescuerName: 'Refugio Luna',
                      );
                      completed = true;
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final target = action == 'Cerrar'
            ? find.byTooltip(action)
            : find.text(action);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        Future<List<int>?> pixels() => tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final result = bytes!.buffer.asUint8List().toList();
          image.dispose();
          return result;
        });
        final before = await pixels();
        final rect = tester.getRect(target);
        final gesture = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 200));
        expect(await pixels(), before);
        expect(tester.getRect(target), rect);
        expect(completed, false);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(await pixels(), before);
        expect(completed, false);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(completed, true);
        expect(result, action == 'Sí, contactar rescatista');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
