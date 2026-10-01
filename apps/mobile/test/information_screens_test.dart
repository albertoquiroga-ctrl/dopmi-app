import 'package:dopmi_mobile/features/profile/information_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<GoRouter> open(
    WidgetTester tester, {
    String path = '/about',
    Future<bool> Function(Uri)? opener,
  }) async {
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Perfil de prueba')),
        ),
        GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
        GoRoute(
          path: '/transparency',
          builder: (_, _) => const TransparencyScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (opener != null)
            informationLinkOpenerProvider.overrideWithValue(opener),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapVisible(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.scrollUntilVisible(target, 250);
    await Scrollable.ensureVisible(tester.element(target), alignment: .25);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'about pushes transparency and back restores about; direct back has a fallback',
    (tester) async {
      final router = await open(tester);
      await tapVisible(tester, 'Transparencia');
      expect(router.state.uri.path, '/transparency');
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/about');
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil de prueba'), findsOneWidget);
    },
  );

  testWidgets(
    'contact opens a draft using operational address and reports launcher failure',
    (tester) async {
      Uri? opened;
      await open(
        tester,
        opener: (uri) async {
          opened = uri;
          return false;
        },
      );
      await tapVisible(tester, 'Contacto');
      expect(opened?.scheme, 'mailto');
      expect(opened?.path, 'soporte@dopmi.org');
      expect(opened?.queryParameters['subject'], 'Ayuda con Dopmi');
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('transparency criteria can expand and collapse with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, path: '/transparency');
    await tapVisible(tester, 'Ver criterios');
    expect(find.textContaining('con desempate estable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'Ocultar criterios');
    expect(find.textContaining('con desempate estable'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
