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
    // Edge, source a3c969c: paused onb-in at 225 of 450 milliseconds.
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(.961383, .0005));
    expect(
      tester.getTopLeft(find.text('Contenido')).dy - (start - 10),
      closeTo(.386175, .005),
    );
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
  testWidgets('Welcome keeps fixed orbs and animates f693 selection outlines', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(377, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pumpAndSettle();
    final adopt = find.byKey(const ValueKey('welcome-orb-adopt'));
    final rescue = find.byKey(const ValueKey('welcome-orb-rescue'));
    expect(tester.getSize(adopt), const Size(92, 92));
    expect(find.text('Donar'), findsNothing);
    expect(find.text('Dar en adopción'), findsOneWidget);
    final tap = find.ancestor(of: adopt, matching: find.byType(InkWell));
    expect(tester.widget<InkWell>(tap).splashFactory, NoSplash.splashFactory);
    BoxDecoration outline(Finder orb) =>
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(of: orb, matching: find.byType(DecoratedBox))
                      .first,
                )
                .decoration
            as BoxDecoration;
    const ringColors = [
      Color(0xffeb6425),
      Color(0xffcbe8fa),
      Color(0xfffef3d4),
    ];
    expect((outline(adopt).gradient! as LinearGradient).colors, ringColors);
    expect((outline(rescue).gradient! as LinearGradient).colors, ringColors);
    await tester.tap(adopt);
    await tester.pump();
    expect(tester.getSize(adopt), const Size(92, 92));
    expect(tester.getSize(rescue), const Size(92, 92));
    expect((outline(rescue).gradient! as LinearGradient).colors, ringColors);
    await tester.pump(const Duration(milliseconds: 100));
    final fadingRing = outline(rescue).gradient! as LinearGradient;
    expect(fadingRing.colors.first.a, greaterThan(0));
    expect(fadingRing.colors.first.a, lessThan(1));
    await tester.pumpAndSettle();
    expect(outline(adopt).color, Colors.white);
    expect((outline(adopt).gradient! as LinearGradient).colors, ringColors);
    expect(outline(rescue).gradient, isNull);
    expect(
      outline(rescue).border,
      Border.all(color: const Color(0xffe8e8e8), width: 1.5),
    );
    await tester.tap(rescue);
    await tester.pump();
    expect(tester.getSize(rescue), const Size(92, 92));
    expect(tester.getSize(adopt), const Size(92, 92));
    await tester.pumpAndSettle();
    expect(outline(adopt).gradient, isNull);
    expect((outline(rescue).gradient! as LinearGradient).colors, ringColors);
    expect(tester.takeException(), isNull);
  });
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
