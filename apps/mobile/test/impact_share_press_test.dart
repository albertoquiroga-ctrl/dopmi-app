import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/foundation.dart';

import 'package:dopmi_mobile/features/profile/impact_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      {
        testWidgets(
          'Impact share keeps its surface stable and activates on release: scale=$scale platform=$platform',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(377, 852));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            const channel = MethodChannel('dev.fluttercommunity.plus/share');
            final calls = <MethodCall>[];
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            messenger.setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return 'dev.fluttercommunity.plus/share/dismissed';
            });
            addTearDown(
              () => messenger.setMockMethodCallHandler(channel, null),
            );
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  theme: dopmiTheme().copyWith(platform: platform),
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        child: ImpactCaseCard(const {
                          'case_id': '41028a40-8b42-4c03-8417-8d33f91d6f52',
                          'public_data': {'pet_name': 'Choco'},
                          'allocated_cents': 7525,
                          'updates': [],
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final target = find.widgetWithText(OutlinedButton, 'Compartir');
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
              reason: 'Held share action must not change rendered pixels',
            );
            expect(calls, isEmpty);
            expect(tester.getRect(target), rect);
            await hold.cancel();
            await tester.pumpAndSettle();
            expect(calls, isEmpty);
            final tap = await tester.startGesture(rect.center);
            await tester.pump();
            await tap.up();
            await tester.pumpAndSettle();
            expect(calls, hasLength(1));
            expect(
              calls.single.arguments['text'],
              contains('41028a40-8b42-4c03-8417-8d33f91d6f52'),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
