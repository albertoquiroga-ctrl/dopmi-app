import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/foundation.dart';

import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final selected in [false, true]) {
        testWidgets(
          'Publication choice preserves press and cancels safely: selected=$selected scale=$scale platform=$platform',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(377, 852));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final changes = <String>[];
            final choice = ValueNotifier<String>(selected ? 'female' : 'male');
            addTearDown(choice.dispose);
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  theme: dopmiTheme().copyWith(platform: platform),
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: ValueListenableBuilder<String>(
                        valueListenable: choice,
                        builder: (context, value, _) => PublicationChoiceRow(
                          label: 'Sexo',
                          options: const {'male': 'Macho', 'female': 'Hembra'},
                          value: value,
                          onChanged: (next) {
                            changes.add(next);
                            choice.value = next;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final target = find.widgetWithText(OutlinedButton, 'Hembra');
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
              reason: 'Held choice must not change rendered pixels',
            );
            expect(changes, isEmpty);
            expect(tester.getRect(target), rect);
            await hold.cancel();
            await tester.pumpAndSettle();
            expect(changes, isEmpty);
            expect(listEquals(await pixels(), before), isTrue);
            final tap = await tester.startGesture(rect.center);
            await tester.pump();
            await tap.up();
            await tester.pump();
            expect(
              tester
                  .widget<PublicationChoiceRow>(
                    find.byType(PublicationChoiceRow),
                  )
                  .value,
              'female',
            );
            expect(listEquals(await pixels(), before), selected);
            final firstSelectionFrame = await pixels();
            await tester.pumpAndSettle();
            expect(
              listEquals(await pixels(), firstSelectionFrame),
              isTrue,
              reason: 'Source selection has no CSS transition',
            );
            expect(changes, ['female']);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
