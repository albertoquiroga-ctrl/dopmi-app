import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';

import 'fake_identity_repository.dart';

void main() {
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
          mode == AuthFormMode.login ? 'Iniciar sesión' : 'Crear cuenta',
        );
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(tester.getRect(submit).overlaps(tester.getRect(sheet)), isTrue);
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
