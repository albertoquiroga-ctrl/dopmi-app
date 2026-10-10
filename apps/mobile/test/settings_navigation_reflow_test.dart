import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final enabled in [false, true]) {
      testWidgets(
        'settings keeps whole words and touch action: $scale/$enabled',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final font = FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
          await tester.runAsync(font.load);
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: dopmiTheme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RescuerNavigationRow(
                      standardSettings: true,
                      title: 'Información básica',
                      subtitle: 'Edita tu perfil y datos personales',
                      icon: 'icon-user',
                      path: '/basic-info',
                      enabled: enabled,
                      onPressed: () => calls++,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final title = find.text('Información básica');
          final paragraph = tester.renderObject<RenderParagraph>(title);
          final wordBoxes = paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 11),
          );
          expect(
            wordBoxes,
            hasLength(1),
            reason: 'Información stays on one line',
          );
          final card = find.byKey(const ValueKey('rescuer-navigation-card'));
          final rect = tester.getRect(card);
          expect(rect.contains(tester.getRect(title).topLeft), isTrue);
          expect(rect.contains(tester.getRect(title).bottomRight), isTrue);
          final hold = await tester.startGesture(rect.center);
          await tester.pump(const Duration(milliseconds: 150));
          await hold.cancel();
          await tester.pumpAndSettle();
          expect(calls, 0);
          expect(tester.getRect(card), rect);
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(calls, enabled ? 1 : 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
