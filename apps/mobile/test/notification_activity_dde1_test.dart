import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/notification_activity_repository.dart';
import 'package:dopmi_mobile/features/communication/notification_activity_screen.dart';
import 'package:dopmi_mobile/features/communication/notification_tile.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class ActivityNotifications extends NotificationActivityRepository {
  ActivityNotifications() : super(FakeRescue().client);
  bool read = false, available = true;
  int opens = 0;
  Json get item => {
    'id': 'one',
    'kind': 'guardian',
    'title': 'Tu pago Guardián fue confirmado',
    'body': 'Consulta las asignaciones.',
    'tone': 'positive',
    'thumb_style': 'brand',
    'created_at': '2026-10-08T12:00:00Z',
    'read_at': read ? '2026-10-08T13:00:00Z' : null,
    'available': available,
    'target_kind': available ? 'history' : null,
  };
  @override
  Future<DataPage<Json>> page(int page) async => DataPage([item], 1);
  @override
  Future<Json> open(String id) async {
    opens++;
    read = true;
    return item;
  }
}

void main() {
  test('notification targets are an explicit whitelist and unavailable destinations stay closed', () {
    expect(
      notificationActivityRoute({'available': true, 'target_kind': 'history'}),
      '/payments',
    );
    expect(
      notificationActivityRoute({
        'available': true,
        'target_kind': 'received_history',
      }),
      '/rescuer/received-payments',
    );
    expect(
      notificationActivityRoute({
        'available': false,
        'target_kind': 'thread',
        'target_id': 'one',
      }),
      isNull,
    );
    expect(
      notificationActivityRoute({
        'available': true,
        'target_kind': 'https://evil.test',
      }),
      isNull,
    );
  });
  for (final available in [true, false]) {
    testWidgets(
      'notification uses authorized refreshed destination; available=$available',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'synthetic@example.test',
            verified: true,
          );
        final repo = ActivityNotifications()..available = available;
        final router = GoRouter(
          initialLocation: '/notifications',
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, _) => const NotificationActivityScreen(),
            ),
            GoRoute(
              path: '/payments',
              builder: (_, _) =>
                  const Scaffold(body: Text('Mi historial real')),
            ),
          ],
        );
        addTearDown(router.dispose);
        addTearDown(identity.changes.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              notificationActivityRepositoryProvider.overrideWithValue(repo),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(NotificationTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tu pago Guardián fue confirmado'));
        await tester.pumpAndSettle();
        expect(repo.opens, 1);
        expect(repo.read, true);
        if (available) {
          expect(find.text('Mi historial real'), findsOneWidget);
        } else {
          expect(
            find.text('Este contenido ya no está disponible.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
