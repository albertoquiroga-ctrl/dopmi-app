import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/rescue/verification_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final title in [
      'Identificación oficial',
      'Comprobante de domicilio',
    ]) {
      testWidgets(
        'document geometry and extended upload target: $title/$scale',
        (tester) async {
          tester.view.physicalSize = const Size(377, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final loader = FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
          await tester.runAsync(loader.load);
          var uploads = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: dopmiTheme(),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(377, 852),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: VerificationDocumentCard(
                        role: 'identity',
                        title: title,
                        onUpload: () => uploads++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = tester.getRect(
            find.byKey(const ValueKey('verification-document-identity')),
          );
          final heading = tester.getRect(find.text('$title *'));
          expect(heading.left - card.left, 15);
          expect(heading.top - card.top, closeTo(15, .001));
          if (scale == 1) expect(card.height, closeTo(67, .001));
          final target = find.byKey(
            const ValueKey('verification-upload-identity'),
          );
          final rect = tester.getRect(target);
          expect(rect.height, greaterThanOrEqualTo(48));
          final hold = await tester.startGesture(
            Offset(rect.center.dx, rect.top + 1),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(uploads, 0);
          await hold.cancel();
          await tester.pumpAndSettle();
          expect(uploads, 0);
          await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
          await tester.pumpAndSettle();
          expect(uploads, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
