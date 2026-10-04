import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/foundation.dart';

import 'package:dopmi_mobile/features/rescue/verification_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final section in ['Continuar a verificación', 'Después', 'Cerrar']) {
        testWidgets(
          'Verification intro preserves press and cancels safely: section=$section scale=$scale platform=$platform',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(377, 852));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            var attachments = 0;
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  theme: dopmiTheme().copyWith(platform: platform),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: const Size(377, 852),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: VerificationIntroScreen(
                      onContinue: () => attachments++,
                      onLater: () => attachments++,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final target = section == 'Cerrar'
                ? find.byTooltip('Cerrar')
                : find
                      .ancestor(
                        of: find.text(section),
                        matching: find.byWidgetPredicate(
                          (w) => w is ButtonStyleButton,
                        ),
                      )
                      .first;
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            final rect = tester.getRect(target);
            Future<List<int>> pixels() async =>
                (await tester.runAsync(() async {
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
                }))!;
            final before = await pixels();
            final hold = await tester.startGesture(rect.center);
            await tester.pump(const Duration(milliseconds: 200));
            expect(
              listEquals(await pixels(), before),
              isTrue,
              reason: 'Held edit link must not change rendered pixels',
            );
            expect(attachments, 0);
            expect(tester.getRect(target), rect);
            await hold.cancel();
            await tester.pumpAndSettle();
            expect(attachments, 0);
            final tap = await tester.startGesture(rect.center);
            await tester.pump();
            await tap.up();
            await tester.pumpAndSettle();
            expect(attachments, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
