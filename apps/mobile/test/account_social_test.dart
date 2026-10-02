import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/onboarding_flow.dart';

import 'fake_identity_repository.dart';

class SocialRepository extends FakeIdentityRepository {
  final requests = <String>[];
  final response = Completer<void>();
  @override
  Future<void> oauth(String provider) {
    requests.add(provider);
    return response.future;
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    SocialRepository repo, {
    bool enabled = true,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        identityRepositoryProvider.overrideWithValue(repo),
        configProvider.overrideWithValue(
          AppConfig(url: '', key: '', redirect: '', googleEnabled: enabled),
        ),
      ],
      child: MaterialApp(
        theme: dopmiTheme(),
        home: const Scaffold(body: AccountSocialActions()),
      ),
    ),
  );
  testWidgets(
    'compact login layout retains a 48px target and opens the real form',
    (tester) async {
      final repo = SocialRepository();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: AccountSocialActions()),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const AuthFormScreen(mode: AuthFormMode.login),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(repo),
            configProvider.overrideWithValue(
              const AppConfig(
                url: '',
                key: '',
                redirect: '',
                googleEnabled: true,
              ),
            ),
          ],
          child: MaterialApp.router(theme: dopmiTheme(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final login = find.widgetWithText(TextButton, 'Inicia sesión');
      expect(tester.getSize(login).height, greaterThanOrEqualTo(48));
      // Hit near the top of its native target, beyond the compact text bounds.
      await tester.tapAt(tester.getRect(login).topCenter + const Offset(0, 1));
      await tester.pumpAndSettle();
      expect(find.byType(AuthFormScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(repo.current, isNull);
    },
  );
  testWidgets('unconfigured providers expose no simulated access', (
    tester,
  ) async {
    final repo = SocialRepository();
    await mount(tester, repo, enabled: false);
    expect(find.byType(IconButton), findsNothing);
    expect(find.text('Continuar con'), findsNothing);
    expect(repo.requests, isEmpty);
  });
  testWidgets(
    'provider cancellation preserves unauthenticated identity and prevents duplicate requests',
    (tester) async {
      final repo = SocialRepository();
      await mount(tester, repo);
      final button = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Continuar con Google',
      );
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      expect(repo.requests, ['google']);
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      repo.response.complete();
      await tester.pumpAndSettle();
      expect(repo.current, isNull);
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
  testWidgets(
    'provider failure exposes recoverable error without entering app',
    (tester) async {
      final repo = SocialRepository();
      await mount(tester, repo);
      final button = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Continuar con Google',
      );
      await tester.tap(button);
      await tester.pump();
      repo.response.completeError(StateError('provider_not_configured'));
      await tester.pumpAndSettle();
      expect(repo.current, isNull);
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
