import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/privacy_notice_screen.dart';
import 'package:dopmi_mobile/features/identity/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

void main() {
  for (final intent in ['adopt', 'rescue']) {
    testWidgets(
      'actual $intent introduction system back restores the previous slide and its entrance',
      (tester) async {
        tester.view.physicalSize = const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final identity = FakeIdentityRepository();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            routerInitialLocationProvider.overrideWithValue(
              '/onboarding?intent=$intent',
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        );
        await tester.pumpAndSettle();
        final first = intent == 'adopt'
            ? 'Tu nuevo mejor amigo ya te espera.'
            : 'Encontrarle hogar también es parte del rescate.';
        final second = intent == 'adopt'
            ? 'Conoce a quien cuida cada historia.'
            : 'Tú lo cuidas. Te ayudamos a cubrir lo que necesita.';
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        expect(find.text(second), findsOneWidget);
        final dots = find.byType(AnimatedContainer);
        expect(dots, findsNWidgets(2));
        // Each dot includes 4px outer margin on either side. The new step
        // recreates the dots, so their final widths exist at the first frame.
        expect(tester.getSize(dots.at(0)).width, 16);
        expect(tester.getSize(dots.at(1)).width, 32);
        final entrance = find.descendant(
          of: find.byType(OnboardingEntrance),
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(entrance).opacity, 0);
        await tester.pump(const Duration(milliseconds: 225));
        expect(
          tester.widget<Opacity>(entrance).opacity,
          inExclusiveRange(0, 1),
        );
        await tester.pump(const Duration(milliseconds: 225));
        expect(tester.widget<Opacity>(entrance).opacity, 1);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text(first), findsOneWidget);
        expect(find.text(second), findsNothing);
        expect(
          container.read(routerProvider).state.uri.toString(),
          '/onboarding?intent=$intent',
        );
        expect(tester.widget<Opacity>(entrance).opacity, 0);
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.widget<Opacity>(entrance).opacity, 1);
        expect(identity.signupCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'actual signup legal route and system back are immediate and retain private draft',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = FakeIdentityRepository();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          routerInitialLocationProvider.overrideWithValue(
            '/signup?intent=rescue',
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'draft@example.test',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final consent = find.byType(AuthConsentRow);
      await tester.ensureVisible(consent);
      final before = tester.getTopLeft(consent);
      await tester.tap(find.text('Aviso de Privacidad').hitTestable());
      await tester.pump();
      expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
      final route = ModalRoute.of(
        tester.element(find.byType(PrivacyNoticeScreen)),
      )!;
      expect(route.transitionDuration, Duration.zero);
      expect(route.animation!.status, AnimationStatus.completed);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PrivacyNoticeScreen), findsNothing);
      expect(tester.getTopLeft(consent), before);
      expect(tester.widget<AuthConsentRow>(consent).value, isFalse);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'draft@example.test',
      );
      expect(
        container.read(routerProvider).state.uri.toString(),
        '/signup?intent=rescue',
      );
      expect(identity.signupCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('route replacement and back are immediate on $platform', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Perfil')),
          ),
          GoRoute(
            path: '/guardian',
            builder: (_, _) => const Scaffold(body: Text('Guardián')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: dopmiTheme().copyWith(platform: platform),
          routerConfig: router,
        ),
      );
      final originalPosition = tester.getTopLeft(find.text('Perfil'));
      router.push('/guardian');
      await tester.pump();
      expect(find.text('Guardián'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Guardián')), originalPosition);
      final route = ModalRoute.of(tester.element(find.text('Guardián')))!;
      expect(route.animation!.status, AnimationStatus.completed);
      expect(route.transitionDuration, Duration.zero);
      router.pop();
      await tester.pump();
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Guardián'), findsNothing);
      expect(tester.getTopLeft(find.text('Perfil')), originalPosition);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
