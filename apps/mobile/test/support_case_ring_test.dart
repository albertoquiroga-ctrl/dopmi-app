import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final large in [false, true]) {
    for (final card in [false, true]) {
      testWidgets('Guardian support focus shape; card=$card large=$large', (
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
                body: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: 280,
                      child: card
                          ? GuardianSupportCard(height: large ? 780 : 300)
                          : const GuardianSupportDock(),
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/guardian',
              builder: (_, state) {
                destinations.add(state.uri.toString());
                return const Scaffold(body: Text('Presentación Guardian'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('reference-keyboard-outline')),
                    )
                    .decoration
                as BoxDecoration;
        expect(
          decoration.borderRadius,
          card
              ? const BorderRadius.vertical(top: Radius.circular(33))
              : BorderRadius.zero,
        );
        expect(destinations, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(destinations, ['/guardian?enroll=1']);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('support rail drag does not open a case; large=$large', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final destinations = <String>[];
      final records = List.generate(
        6,
        (index) => RescueRecord({
          'id': 'case-$index',
          'kind': 'case',
          'status': 'approved',
          'target_cents': 10000,
          'funded_cents': 5000,
          'public_data': {'pet_name': 'Mascota $index', 'photos': <String>[]},
        }),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => SupportHomePage(
              data: DataPage(records, 6),
              page: 1,
              error: null,
              changePage: (_) {},
            ),
          ),
          GoRoute(
            path: '/rescue-cases/:id',
            builder: (_, state) {
              destinations.add(state.pathParameters['id']!);
              return const Scaffold(body: Text('Caso seleccionado'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      final rail = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );
      final scroll = find.descendant(
        of: rail,
        matching: find.byType(Scrollable),
      );
      final first = find.byWidgetPredicate(
        (widget) => widget is SupportCaseRing && widget.record.id == 'case-0',
      );
      await tester.drag(first, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        greaterThan(0),
      );
      expect(destinations, isEmpty);
      final last = find.byWidgetPredicate(
        (widget) => widget is SupportCaseRing && widget.record.id == 'case-5',
      );
      await tester.scrollUntilVisible(last, 150, scrollable: scroll);
      await tester.pumpAndSettle();
      expect(destinations, isEmpty);
      await tester.scrollUntilVisible(first, -150, scrollable: scroll);
      await tester.pumpAndSettle();
      expect(destinations, isEmpty);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(destinations, ['case-0']);
      expect(find.text('Caso seleccionado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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
      final outline =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('reference-keyboard-outline')),
                  )
                  .decoration
              as BoxDecoration;
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
