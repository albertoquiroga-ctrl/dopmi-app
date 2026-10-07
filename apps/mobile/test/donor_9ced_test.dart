import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/discovery_empty.dart';
import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('9ced end copy keeps discover and favorites usable at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var restarts = 0;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SingleChildScrollView(
                child: DiscoveryEnd(restart: () => restarts++),
              ),
            ),
          ),
          GoRoute(
            path: '/messages',
            builder: (_, _) => const Scaffold(body: Text('Mis match')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: dopmiTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Todos los días hay historias nuevas esperando a alguien como tú.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Tip:'), findsNothing);
      final discover = find.widgetWithText(
        OutlinedButton,
        'Volver a descubrir',
      );
      await tester.ensureVisible(discover);
      await tester.pumpAndSettle();
      await tester.tap(discover);
      await tester.pumpAndSettle();
      expect(restarts, 1);
      final favorites = find.widgetWithText(FilledButton, 'Ir a mis favoritos');
      await tester.ensureVisible(favorites);
      await tester.pumpAndSettle();
      await tester.tap(favorites);
      await tester.pumpAndSettle();
      expect(find.text('Mis match'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9ced support header preserves notifications at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => SupportHomePage(
              data: const DataPage([], 0),
              page: 1,
              error: null,
              changePage: (_) {},
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) =>
                const Scaffold(body: Text('Notificaciones recibidas')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: MaterialApp.router(theme: dopmiTheme(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.text('Ayudar se siente bien');
      expect(title, findsOneWidget);
      final paragraph = tester.getRect(title);
      expect(paragraph.left, 20);
      expect(paragraph.right, lessThanOrEqualTo(300));
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(title),
        matchesSemantics(label: 'Ayudar se siente bien', isHeader: true),
      );
      semantics.dispose();
      final notifications = find.byTooltip('Notificaciones');
      await tester.tap(notifications);
      await tester.pumpAndSettle();
      expect(find.text('Notificaciones recibidas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
