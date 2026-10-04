import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/foundation.dart';

import 'package:dopmi_mobile/features/payments/guardian_payment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final remove in [false, true]) {
        testWidgets(
          'Card action has no touch overlay and activates on release: remove=$remove scale=$scale platform=$platform',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(377, 852));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            var defaults = 0, removals = 0;
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  theme: dopmiTheme().copyWith(platform: platform),
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: GuardianPaymentCardRow(
                        card: const GuardianPaymentCard(
                          id: 'pm_fixture',
                          brand: 'visa',
                          last4: '4242',
                          isDefault: false,
                        ),
                        showMakeDefault: true,
                        onMakeDefault: () => defaults++,
                        showRemove: true,
                        onRemove: () => removals++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final target = remove
                ? find.byTooltip('Eliminar tarjeta')
                : find.widgetWithText(TextButton, 'Hacer predeterminada');
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
              reason: 'Held card action must not change rendered pixels',
            );
            expect(defaults + removals, 0);
            expect(tester.getRect(target), rect);
            await hold.cancel();
            await tester.pumpAndSettle();
            expect(defaults + removals, 0);
            final tap = await tester.startGesture(rect.center);
            await tester.pump();
            await tap.up();
            await tester.pumpAndSettle();
            expect(defaults, remove ? 0 : 1);
            expect(removals, remove ? 1 : 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
