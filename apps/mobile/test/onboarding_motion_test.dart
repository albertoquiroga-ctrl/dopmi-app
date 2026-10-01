import 'package:dopmi_mobile/features/identity/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
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
              body: WelcomeSummaryEntrance(child: Text('Resumen')),
            ),
          ),
        ),
      );
      final opacity = find.descendant(
        of: find.byType(WelcomeSummaryEntrance),
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
