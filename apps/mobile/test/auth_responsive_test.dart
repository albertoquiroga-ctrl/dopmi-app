import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_identity_repository.dart';

void main() {
  testWidgets(
    'restored recovery opens reset without a profile or consent gate',
    (tester) async {
      final repository = FakeIdentityRepository()
        ..user = const Identity('one', 'qa@example.test', verified: true)
        ..pending = true;
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repository),
          configProvider.overrideWithValue(
            const AppConfig(url: '', key: '', redirect: ''),
          ),
          routerInitialLocationProvider.overrideWithValue('/reset-password'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Una nueva\ncontraseña.'), findsOneWidget);
      expect(find.byType(AuthFormScreen), findsOneWidget);
      expect(find.text('Antes de continuar'), findsNothing);
      expect(repository.loads, 0);
      expect(
        find.widgetWithText(FilledButton, 'Actualizar contraseña'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final title in [
    'Recupera tu acceso.',
    'Una nueva\ncontraseña.',
    'Revisa tu correo.',
  ]) {
    testWidgets('access heading keeps whole words at enlarged text: $title', (
      tester,
    ) async {
      final loader = FontLoader('Fraunces')
        ..addFont(rootBundle.load('assets/fonts/Fraunces.ttf'));
      await tester.runAsync(loader.load);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dopmiTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: AuthFrame(
            onBack: () {},
            child: AuthHeading(
              title,
              'Las instrucciones permanecen accesibles.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      for (final match in RegExp(r'\S+').allMatches(title)) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
        );
        expect(
          boxes.map((box) => box.top.round()).toSet(),
          hasLength(1),
          reason: 'The word ${match.group(0)} must stay on one line.',
        );
      }
      expect(tester.getRect(find.text(title)).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(find.text(title)).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  }
}
