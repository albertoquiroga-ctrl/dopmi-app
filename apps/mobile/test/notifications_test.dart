import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/message_screens.dart';
import 'package:dopmi_mobile/features/communication/notification_frame.dart';
import 'package:dopmi_mobile/features/communication/notification_tile.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

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

class PagedNotifications extends NotificationCommunity {
  final pages = <int>[];
  @override
  Future<DataPage<Json>> notifications(int page) async {
    pages.add(page);
    return DataPage(
      List.generate(
        page == 1 ? 20 : 1,
        (index) => {
          'id': 'notice-${(page - 1) * 20 + index + 1}',
          'kind': 'review',
          'post_id': 'post-one',
          'title': 'Aviso ${(page - 1) * 20 + index + 1}',
          'created_at': '2026-10-02T12:00:00Z',
          'read_at': null,
        },
      ),
      21,
    );
  }
}

void main() {
  FakeIdentityRepository signedInDonor() {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    addTearDown(() async => identity.changes.close());
    return identity;
  }

  testWidgets(
    'compact time exposes the precise date without opening the notice',
    (tester) async {
      var taps = 0;
      final created = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationTile({
              'kind': 'message',
              'title': 'Aviso real',
              'created_at': created,
              'read_at': null,
            }, onTap: () => taps++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final precise = tester.widget<Tooltip>(find.byType(Tooltip)).message!;
      await tester.longPress(find.text('Hace 5 min'));
      await tester.pumpAndSettle();
      expect(find.text(precise), findsOneWidget);
      expect(taps, 0);
      expect(tester.takeException(), isNull);
    },
  );
  test('notification time uses actual elapsed time and calendar days', () {
    final now = DateTime(2026, 10, 2, 12, 0);
    String at(DateTime date) =>
        notificationTime(date.toIso8601String(), now: now);
    expect(at(now.subtract(const Duration(seconds: 30))), 'Ahora');
    expect(at(now.subtract(const Duration(minutes: 5))), 'Hace 5 min');
    expect(at(now.subtract(const Duration(hours: 2))), 'Hace 2 h');
    expect(at(DateTime(2026, 10, 1, 23, 59)), 'Ayer');
    expect(at(DateTime(2026, 9, 30)), 'Hace 2 días');
    expect(at(DateTime(2026, 9, 25)), '25/9/2026');
    expect(notificationTime('invalid', now: now), '');
    expect(at(now.add(const Duration(minutes: 5))), '2/10/2026 12:05');
    final midnight = DateTime(2026, 10, 2, 0, 1);
    expect(
      notificationTime(
        DateTime(2026, 10, 1, 23, 59).toIso8601String(),
        now: midnight,
      ),
      'Ayer',
    );
  });
  testWidgets('notification header keyboard returns to its fallback profile', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationFrame(children: []),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Perfil de regreso')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reference-keyboard-outline')),
      findsOneWidget,
    );
    expect(find.text('Perfil de regreso'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Perfil de regreso'), findsOneWidget);
  });
  for (final entry in [
    ('message', null, 'message'),
    ('rescue', 'case-one', 'case'),
    ('review', null, 'pet'),
  ]) {
    testWidgets('notification icon follows its real kind: ${entry.$1}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationTile({
              'kind': entry.$1,
              'rescue_id': entry.$2,
              'title': 'Aviso real',
              'created_at': '2026-10-02T12:00:00Z',
              'read_at': null,
            }, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final loader =
          tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
              as SvgAssetLoader;
      expect(loader.assetName, 'assets/profile/notif-${entry.$3}.svg');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('notifications paginate both ways at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = PagedNotifications();
    final identity = signedInDonor();
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider.overrideWithValue(repo),
          identityRepositoryProvider.overrideWithValue(identity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Página siguiente'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Página siguiente')),
      alignment: .8,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(repo.pages, [1, 2]);
    expect(find.text('Aviso 21'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Página anterior'));
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Página anterior')),
      alignment: .8,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Página anterior'));
    await tester.pumpAndSettle();
    expect(repo.pages, [1, 2, 1]);
    expect(find.text('Aviso 21'), findsNothing);
    expect(tester.takeException(), isNull);
  });
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
        final identity = signedInDonor();
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
            overrides: [
              communityRepositoryProvider.overrideWithValue(repo),
              identityRepositoryProvider.overrideWithValue(identity),
            ],
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
