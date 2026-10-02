import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
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
