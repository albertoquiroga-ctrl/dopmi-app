import 'dart:async';

import 'package:dopmi_mobile/core/donor_notification_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';

import 'community_test.dart' show FakeCommunity;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class CounterCommunity extends FakeCommunity {
  int count = 3;
  bool fail = false;
  String? actor = 'one';
  Completer<int>? pending;
  VoidCallback? update;
  @override
  String? get userId => actor;
  @override
  Future<int> unreadNotificationCount() async {
    if (fail) throw Exception('offline');
    return pending?.future ?? count;
  }

  @override
  VoidCallback watch(List<String> tables, VoidCallback refresh) {
    expect(tables, ['dopmi_notifications']);
    update = refresh;
    return () => update = null;
  }
}

void main() {
  testWidgets(
    'notification count refreshes, hides errors and rejects another actor',
    (tester) async {
      final repo = CounterCommunity();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: DonorNotificationButton())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      repo.count = 0;
      repo.update!();
      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);
      repo.count = 2;
      repo.update!();
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      repo.fail = true;
      repo.update!();
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      expect(find.byTooltip('Notificaciones'), findsOneWidget);
      repo.fail = false;
      repo.pending = Completer<int>();
      repo.update!();
      repo.actor = 'two';
      repo.pending!.complete(9);
      await tester.pumpAndSettle();
      expect(find.text('9'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(repo.update, isNull);
    },
  );
  testWidgets('notification keyboard focus opens the notification route', (
    tester,
  ) async {
    final repo = CounterCommunity();
    final destinations = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Center(child: DonorNotificationButton())),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) {
            destinations.add(state.uri.path);
            repo.count = 0;
            return Scaffold(
              body: Column(
                children: [
                  const Text('Notificaciones recibidas'),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Regresar'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.style!.overlayColor!.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(button.style!.splashFactory, NoSplash.splashFactory);
    expect(tester.getSize(find.byType(IconButton)), const Size(42, 42));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(destinations, isEmpty);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('reference-keyboard-outline')),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(26));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(destinations, ['/notifications']);
    expect(find.text('Notificaciones recibidas'), findsOneWidget);
    await tester.tap(find.text('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
