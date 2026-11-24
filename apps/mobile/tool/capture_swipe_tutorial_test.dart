import 'dart:io';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/swipe_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_design_test.dart' show saveCapture;

void main() {
  testWidgets('capture swipe tutorial at normal and accessible sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final family in ['Inter', 'MaterialIcons']) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load(
            family == 'MaterialIcons'
                ? 'fonts/MaterialIcons-Regular.otf'
                : 'assets/fonts/$family.ttf',
          ),
        );
      await tester.runAsync(loader.load);
    }
    final output = Directory('../../.tools/swipe-tutorial-20261124/captures');
    await tester.runAsync(() => output.create(recursive: true));
    for (final variant in [
      ('normal', 377.0, 852.0, 1.0),
      ('large', 320.0, 640.0, 2.0),
    ]) {
      tester.view.physicalSize = Size(variant.$2, variant.$3);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dopmiTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(variant.$4),
              ),
              child: child!,
            ),
            home: SwipeTutorial(onDone: () {}),
          ),
        ),
      );
      final context = tester.element(find.byType(SwipeTutorial));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/onboarding/rocky.png'),
          context,
        );
        if (context.mounted) {
          await precacheImage(
            const AssetImage('assets/dopmi-wordmark.png'),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      for (final step in [
        ('right', 'Probar guardar'),
        ('left', 'Probar pasar'),
        ('done', 'Empezar a descubrir'),
      ]) {
        await tester.runAsync(
          () => saveCapture(
            key,
            '${output.path}/${variant.$1}-${step.$1}-top.png',
          ),
        );
        final action = find.text(step.$2);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (variant.$1 == 'large') {
          await tester.runAsync(
            () => saveCapture(
              key,
              '${output.path}/${variant.$1}-${step.$1}-action.png',
            ),
          );
        }
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
