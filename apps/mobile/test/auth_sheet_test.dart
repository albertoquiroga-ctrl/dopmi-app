import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';

import 'fake_identity_repository.dart';

void main() {
  testWidgets(
    'access primary keeps reference color while held and acts once on release',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      var calls = 0;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: dopmiTheme(),
            home: AuthFrame(
              sheet: true,
              onBack: () {},
              child: ActionButton('Continuar', onPressed: () => calls++),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Continuar');
      final rect = tester.getRect(button);
      Future<List<int>?> sample() => tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final offset =
            (rect.center.dy.floor() * image.width + (rect.left + 30).floor()) *
            4;
        final color = bytes!.buffer.asUint8List().sublist(offset, offset + 4);
        image.dispose();
        return color;
      });
      final before = await sample();
      expect(before, [21, 17, 13, 255]);
      final gesture = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(await sample(), before);
      expect(calls, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [AuthFormMode.login, AuthFormMode.signup]) {
    testWidgets(
      'auth sheet scrolls with keyboard and 200% text without losing input, $mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final repo = FakeIdentityRepository();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => AuthFormScreen(mode: mode, intent: 'rescue'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(repo),
              configProvider.overrideWithValue(
                const AppConfig(url: '', key: '', redirect: ''),
              ),
            ],
            child: MaterialApp.router(
              theme: dopmiTheme(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sheet = find.byKey(const ValueKey('auth-form-sheet'));
        final email = find
            .byType(TextFormField)
            .at(mode == AuthFormMode.signup ? 1 : 0);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.getRect(sheet).bottom, closeTo(344, 1));
        expect(tester.getRect(sheet).top, greaterThanOrEqualTo(80));
        await tester.ensureVisible(email);
        await tester.enterText(email, 'ana@example.test');
        await tester.pumpAndSettle();
        final submit = find.widgetWithText(
          FilledButton,
          mode == AuthFormMode.login ? 'Inicia sesión' : 'Crea una cuenta',
        );
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(tester.getRect(submit).overlaps(tester.getRect(sheet)), isTrue);
        final label = find.descendant(of: submit, matching: find.byType(Text));
        expect(tester.widget<Text>(label).textAlign, TextAlign.center);
        expect(
          tester.getRect(label).top - tester.getRect(submit).top,
          greaterThanOrEqualTo(12),
        );
        expect(
          tester.getRect(submit).bottom - tester.getRect(label).bottom,
          greaterThanOrEqualTo(12),
        );
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(email).controller!.text,
          'ana@example.test',
        );
        expect(tester.getRect(sheet).bottom, closeTo(624, 1));
        expect(repo.signupCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
