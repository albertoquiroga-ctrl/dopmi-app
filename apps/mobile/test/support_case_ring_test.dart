import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets('support case keyboard destination; large=$large', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final destinations = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Center(
                child: SupportCaseRing(
                  RescueRecord({
                    'id': 'actual-case',
                    'kind': 'case',
                    'status': 'approved',
                    'target_cents': 10000,
                    'funded_cents': 5000,
                    'public_data': {'pet_name': 'Luna', 'photos': <String>[]},
                  }),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/rescue-cases/:id',
            builder: (_, state) {
              destinations.add(state.pathParameters['id']!);
              return const Scaffold(body: Text('Caso abierto'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.splashFactory, NoSplash.splashFactory);
      expect(ink.highlightColor, Colors.transparent);
      expect(ink.hoverColor, Colors.transparent);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reference-keyboard-outline')),
        findsOneWidget,
      );
      final outline = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('reference-keyboard-outline')),
      ).decoration as BoxDecoration;
      expect(outline.borderRadius, BorderRadius.zero);
      expect(destinations, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(destinations, ['actual-case']);
      expect(find.text('Caso abierto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
