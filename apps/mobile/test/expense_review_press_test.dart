import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/foundation.dart';

import 'package:dopmi_mobile/features/rescue/expense_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final section in [
        'Información para publicación',
        'Solo para revisión privada',
        'Comprobantes y fotos',
      ]) {
        testWidgets(
          'Expense review edit preserves press and cancels safely: section=$section scale=$scale platform=$platform',
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
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: scale > 1 ? 68.5 : 0,
                          ),
                          child: ExpenseReview(
                            values: const {
                              'title': 'Consulta',
                              'amount_cents': '123.45',
                            },
                            files: const [],
                            onOpen: (_) => fail('No existing file'),
                            onEditInformation: () => attachments++,
                            onEditPrivateInformation: () => attachments++,
                            onEditFiles: () => attachments++,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (scale > 1) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(section),
              );
              for (final match in RegExp(r'\S+').allMatches(section)) {
                expect(
                  paragraph.getBoxesForSelection(
                    TextSelection(
                      baseOffset: match.start,
                      extentOffset: match.end,
                    ),
                  ),
                  hasLength(1),
                  reason: 'A heading word must fit beside the edit action',
                );
              }
            }
            final target = find.descendant(
              of: find.byTooltip('Editar $section'),
              matching: find.byType(TextButton),
            );
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
