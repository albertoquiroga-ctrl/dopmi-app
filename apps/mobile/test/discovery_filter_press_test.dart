import 'dart:ui' as ui;

import 'package:dopmi_mobile/features/adoption/discovery_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final outlined in [false, true]) {
      testWidgets(
        'filter option holds pixels and cancels safely: $scale/$outlined',
        (tester) async {
          final key = GlobalKey();
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: SizedBox(
                        width: 300,
                        child: FilterOption(
                          label: outlined ? 'Dormilón' : 'Hembra',
                          selected: false,
                          fill: outlined
                              ? personalityColors['dormilon']!
                              : Colors.white,
                          foreground: const Color(0xff15110d),
                          fontSize: outlined ? 12 : 14,
                          outlined: outlined,
                          onPressed: () => calls++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<List<int>?> pixels() => tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final result = bytes!.buffer.asUint8List().toList();
            image.dispose();
            return result;
          });
          final target = find.byType(TextButton);
          final rect = tester.getRect(target);
          final before = await pixels();
          final held = await tester.startGesture(rect.center);
          await tester.pump(const Duration(milliseconds: 200));
          expect(await pixels(), before);
          expect(tester.getRect(target), rect);
          expect(calls, 0);
          await held.cancel();
          await tester.pumpAndSettle();
          expect(calls, 0);
          expect(await pixels(), before);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
