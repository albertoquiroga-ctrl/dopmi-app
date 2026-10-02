import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/message_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;

class NotificationCommunity extends FakeCommunity {
  bool fail = true;
  bool read = false;
  int calls = 0;
  @override
  Future<DataPage<Json>> notifications(int page) async => DataPage([
    {
      'id': 'notice-one',
      'kind': 'message',
      'title': 'Patricia te escribió',
      'thread_id': 'thread-one',
      'created_at': '2026-10-02T12:00:00Z',
      'read_at': read ? '2026-10-02T13:00:00Z' : null,
    },
  ], 1);
  @override
  Future<void> readNotification(String id) async {
    expect(id, 'notice-one');
    calls++;
    if (fail) throw Exception('offline');
    read = true;
  }
}

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'notification read failure retries before real destination; large=$large',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = NotificationCommunity();
        final destinations = <String>[];
        final router = GoRouter(
          initialLocation: '/notifications',
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, _) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/messages/:id',
              builder: (context, state) {
                destinations.add(state.pathParameters['id']!);
                return Scaffold(
                  body: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Volver'),
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
        expect(find.text('Notificaciones'), findsOneWidget);
        expect(find.text('Lo nuevo en Dopmi.'), findsNothing);
        await tester.tap(find.text('Patricia te escribió'));
        await tester.pumpAndSettle();
        expect(destinations, isEmpty);
        expect(repo.read, isFalse);
        expect(find.textContaining('No pudimos completar'), findsOneWidget);
        repo.fail = false;
        await tester.scrollUntilVisible(
          find.text('Patricia te escribió'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Patricia te escribió')),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Patricia te escribió'));
        await tester.pumpAndSettle();
        expect(destinations, ['thread-one']);
        expect(repo.calls, 2);
        await tester.tap(find.text('Volver'));
        await tester.pumpAndSettle();
        expect(repo.read, isTrue);
        expect(find.text('Patricia te escribió'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
