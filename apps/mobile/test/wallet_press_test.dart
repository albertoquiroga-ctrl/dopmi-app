import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/foundation.dart';

import 'package:dopmi_mobile/features/payments/native_wallet_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final provider in ['apple_pay', 'google_pay']) {
        testWidgets(
          'Wallet has no touch overlay and activates on release: provider=$provider scale=$scale platform=$platform',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(377, 852));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final selected = <String>[];
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  theme: dopmiTheme().copyWith(platform: platform),
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: NativeWalletButtons(
                        availableProvider: provider,
                        onPressed: selected.add,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final target = find.widgetWithText(
              OutlinedButton,
              provider == 'apple_pay' ? 'Apple Pay' : 'Google Pay',
            );
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
              reason: 'Held wallet must not change rendered pixels',
            );
            expect(selected, isEmpty);
            expect(tester.getRect(target), rect);
            await hold.cancel();
            await tester.pumpAndSettle();
            expect(selected, isEmpty);
            final tap = await tester.startGesture(rect.center);
            await tester.pump();
            await tap.up();
            await tester.pumpAndSettle();
            expect(selected, [provider]);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
