import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Guardian deck advances through three photos, loops and opens enrollment',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const Scaffold(body: GuardianSupportCard(height: 600)),
            ),
            GoRoute(
              path: '/guardian',
              builder: (_, state) => Scaffold(
                body: Text('Guardian ${state.uri.queryParameters['enroll']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        final carousel = find.byKey(
          const ValueKey('guardian-support-carousel'),
        );
        expect(find.bySemanticsLabel(RegExp('Imagen 1 de 3')), findsOneWidget);
        await tester.drag(carousel, const Offset(-700, 0));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('Imagen 2 de 3')), findsOneWidget);
        await tester.drag(carousel, const Offset(-700, 0));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('Imagen 3 de 3')), findsOneWidget);
        await tester.tap(find.byTooltip('Siguiente imagen Guardián'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('Imagen 1 de 3')), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('guardian-support-card-action')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Guardian 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final reduced in [false, true]) {
    testWidgets(
      'Guardian deck short drag/cancel never navigates; reduced=$reduced',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: const Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(40),
                    child: GuardianSupportCard(height: 420),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = find.byKey(const ValueKey('guardian-support-carousel'));
          await tester.drag(card, const Offset(-80, 0));
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel(RegExp('Imagen 1 de 3')),
            findsOneWidget,
          );
          final gesture = await tester.startGesture(tester.getCenter(card));
          await gesture.moveBy(const Offset(-160, 0));
          await tester.pump();
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel(RegExp('Imagen 1 de 3')),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('Siguiente imagen Guardián'));
          await tester.pump();
          if (reduced) {
            expect(
              find.bySemanticsLabel(RegExp('Imagen 2 de 3')),
              findsOneWidget,
            );
          } else {
            expect(
              find.bySemanticsLabel(RegExp('Imagen 1 de 3')),
              findsOneWidget,
            );
            await tester.pump(const Duration(milliseconds: 140));
            final moving = tester.widget<AnimatedContainer>(card);
            expect(moving.duration, const Duration(milliseconds: 280));
            expect(moving.transform!.storage[12], -420);
            await tester.pumpAndSettle();
            expect(
              find.bySemanticsLabel(RegExp('Imagen 2 de 3')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'keyboard next image advances without enrollment at scale $scale',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(40),
                  child: GuardianSupportCard(height: 420),
                ),
              ),
            ),
            GoRoute(
              path: '/guardian',
              builder: (_, _) => const Scaffold(body: Text('Enrollment')),
            ),
          ],
        );
        addTearDown(router.dispose);
        try {
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel(RegExp('Imagen 2 de 3')),
            findsOneWidget,
          );
          expect(router.state.uri.path, '/');
          expect(find.text('Enrollment'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
