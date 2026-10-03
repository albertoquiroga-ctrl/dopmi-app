import 'package:dopmi_mobile/features/identity/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Onboarding entrance moves ten pixels and fades over 450ms', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OnboardingEntrance(child: Text('Contenido'))),
      ),
    );
    final opacity = find.descendant(
      of: find.byType(OnboardingEntrance),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    final start = tester.getTopLeft(find.text('Contenido')).dy;
    await tester.pump(const Duration(milliseconds: 225));
    final progress = const Cubic(.22, 1, .36, 1).transform(.5);
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(progress, .00001));
    expect(
      start - tester.getTopLeft(find.text('Contenido')).dy,
      closeTo(10 * progress, .001),
    );
    await tester.pump(const Duration(milliseconds: 225));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(
      start - tester.getTopLeft(find.text('Contenido')).dy,
      closeTo(10, .001),
    );
  });
  for (final reduced in [false, true]) {
    testWidgets('Welcome summary follows delayed motion, reduced=$reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Scaffold(
              body: WelcomeSelectionEntrance(child: Text('Resumen')),
            ),
          ),
        ),
      );
      final opacity = find.descendant(
        of: find.byType(WelcomeSelectionEntrance),
        matching: find.byType(Opacity),
      );
      final start = tester.getTopLeft(find.text('Resumen')).dy;
      expect(tester.widget<Opacity>(opacity).opacity, reduced ? 1 : 0);
      if (!reduced) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.widget<Opacity>(opacity).opacity, 0);
        expect(tester.getTopLeft(find.text('Resumen')).dy, start);
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.widget<Opacity>(opacity).opacity, 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
        await tester.pump(const Duration(milliseconds: 310));
        expect(tester.widget<Opacity>(opacity).opacity, 1);
        expect(
          start - tester.getTopLeft(find.text('Resumen')).dy,
          closeTo(18, .001),
        );
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('Welcome footer uses its own delays, reduced=$reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Scaffold(
              body: WelcomeSelectionEntrance(
                footer: true,
                child: Text('Continuar'),
              ),
            ),
          ),
        ),
      );
      final opacity = find.descendant(
        of: find.byType(WelcomeSelectionEntrance),
        matching: find.byType(Opacity),
      );
      final start = tester.getTopLeft(find.text('Continuar')).dy;
      expect(tester.widget<Opacity>(opacity).opacity, reduced ? 1 : 0);
      if (!reduced) {
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.widget<Opacity>(opacity).opacity, 0);
        expect(tester.getTopLeft(find.text('Continuar')).dy, start);
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.widget<Opacity>(opacity).opacity, 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
        await tester.pump(const Duration(milliseconds: 241));
        expect(tester.widget<Opacity>(opacity).opacity, 1);
        expect(
          start - tester.getTopLeft(find.text('Continuar')).dy,
          closeTo(16, .001),
        );
      }
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
  for (final reduced in [false, true]) {
    testWidgets(
      'Welcome selection enters and Continue preserves intent, reduced=$reduced',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = GoRouter(
          initialLocation: '/welcome',
          routes: [
            GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
            GoRoute(
              path: '/onboarding',
              builder: (_, state) => Scaffold(
                body: Text('Intención: ${state.uri.queryParameters['intent']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced,
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Adoptar'));
        await tester.tap(find.text('Adoptar'));
        await tester.pumpAndSettle();
        expect(find.byType(WelcomeSelectionEntrance), findsNWidgets(2));
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text('Intención: adopt'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Continuar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Welcome offers the current two choices with fixed orbs and animated fill',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(377, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await tester.pumpAndSettle();
      final adopt = find.byKey(const ValueKey('welcome-orb-adopt'));
      final donate = find.byKey(const ValueKey('welcome-orb-rescue'));
      expect(tester.getSize(adopt), const Size(92, 92));
      expect(find.text('Donar'), findsNothing);
      expect(find.text('Dar en adopción'), findsOneWidget);
      final tap = find.ancestor(of: adopt, matching: find.byType(InkWell));
      expect(tester.widget<InkWell>(tap).splashFactory, NoSplash.splashFactory);
      await tester.tap(adopt);
      await tester.pump();
      expect(tester.getSize(adopt), const Size(92, 92));
      expect(tester.getSize(donate), const Size(92, 92));
      Color fill() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: adopt,
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      expect(fill(), Colors.white);
      await tester.pump(const Duration(milliseconds: 100));
      expect(fill(), isNot(Colors.white));
      expect(fill(), isNot(const Color(0xfffff6cf)));
      await tester.pumpAndSettle();
      expect(fill(), const Color(0xfffff6cf));
      await tester.tap(donate);
      await tester.pump();
      expect(tester.getSize(donate), const Size(92, 92));
      expect(tester.getSize(adopt), const Size(92, 92));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Reduced motion shows onboarding immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: OnboardingEntrance(child: Text('Contenido')),
        ),
      ),
    );
    expect(find.text('Contenido'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OnboardingEntrance),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });
}
