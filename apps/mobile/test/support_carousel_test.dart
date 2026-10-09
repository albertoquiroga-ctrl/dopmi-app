import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Guardian carousel snaps through three photos and opens enrollment',
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
}
