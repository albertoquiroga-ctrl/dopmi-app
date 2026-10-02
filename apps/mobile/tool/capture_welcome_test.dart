import 'dart:io';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/features/identity/onboarding_screen.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Capture welcome selection with real fonts at normal and enlarged text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
        final font = FontLoader(family)
          ..addFont(
            rootBundle.load(
              family == 'MaterialIcons'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$family.ttf',
            ),
          );
        await tester.runAsync(font.load);
      }
      final out = Directory('../../.tools/design-review');
      await tester.runAsync(() => out.create(recursive: true));
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = scale == 1
            ? const Size(377, 852)
            : const Size(320, 640);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dopmiTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: boundary,
                child: const WelcomeScreen(),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/dopmi-wordmark.png'),
            boundary.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
        Future<void> save(String name) async {
          expect(tester.takeException(), isNull);
          final image = await tester.runAsync(
            () =>
                (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1),
          );
          final bytes = await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.png),
          );
          await tester.runAsync(
            () =>
                File('${out.path}/$name.png')
                    .writeAsBytes(bytes!.buffer.asUint8List()),
          );
          image!.dispose();
        }

        final suffix = scale == 1 ? '' : '-large';
        await save('welcome-empty$suffix');
        await tester.ensureVisible(find.text('Donar'));
        await tester.tap(find.text('Donar'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('¿Cómo quieres ayudar?'));
        await tester.pumpAndSettle();
        await save('welcome-selected$suffix');
        await tester.ensureVisible(find.text('Continuar'));
        expect(find.text('Continuar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
