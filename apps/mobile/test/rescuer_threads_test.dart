import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/rescuer_threads_screen.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

Json inboxThread(String id, {int unread = 0, bool closed = false}) => {
  'id': id,
  'participant_name': 'Ana',
  'pet_name': 'Luna',
  'updated_at': '2026-10-04T18:30:00Z',
  'last_message': 'Mensaje $id',
  'unread_count': unread,
  'status': closed ? 'closed' : 'active',
};
Json inboxGroup(
  String id,
  List<Json> threads, {
  String name = 'Luna',
  int? count,
  int unread = 0,
}) => {
  'id': id,
  'pet_name': name,
  'photo': '',
  'case_id': '',
  'post_id': 'post-$id',
  'unread_count': unread,
  'thread_count': count ?? threads.length,
  'threads': threads,
  'threads_total': count ?? threads.length,
};

class InboxCommunity extends FakeCommunity {
  List<Json> groups = [], historical = [];
  final inboxRequests = <(int, bool)>[];
  final groupRequests = <(String, int, bool)>[];
  DataPage<Json> nextThreads = const DataPage([], 0);
  Completer<DataPage<Json>>? pendingThreads;
  bool failInbox = false, failMore = false;
  int? groupTotal;
  @override
  Future<DataPage<Json>> rescuerInbox(int page, {bool history = false}) async {
    inboxRequests.add((page, history));
    if (failInbox) throw const FormatException('Offline fixture');
    final items = history ? historical : groups;
    return DataPage(items, groupTotal ?? items.length);
  }

  @override
  Future<DataPage<Json>> rescuerGroupThreads(
    String groupId,
    int page, {
    bool history = false,
  }) async {
    groupRequests.add((groupId, page, history));
    if (pendingThreads != null) return pendingThreads!.future;
    if (failMore) throw const FormatException('Offline page');
    return nextThreads;
  }
}

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    InboxCommunity repo, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = scale > 1
        ? const Size(320, 640)
        : const Size(384, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    await identity.setExperience('rescuer');
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue('/messages'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('failed inbox retries without inventing an empty result', (
    tester,
  ) async {
    final repo = InboxCommunity()
      ..failInbox = true
      ..groups = [
        inboxGroup('one', [inboxThread('thread-one')]),
      ];
    await start(tester, repo);
    expect(find.textContaining('No tienes casos'), findsNothing);
    expect(find.byType(RescuerInboxGroup), findsNothing);
    final before = repo.inboxRequests.length;
    repo.failInbox = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(repo.inboxRequests.length, greaterThan(before));
    expect(find.text('Mensaje thread-one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('empty owner inbox opens actual cases at scale $scale', (
      tester,
    ) async {
      final container = await start(tester, InboxCommunity(), scale: scale);
      expect(find.byType(RescuerThreadsScreen), findsOneWidget);
      expect(find.text('Mis match'), findsNothing);
      expect(
        find.textContaining('No tienes casos en adopción abiertos'),
        findsOneWidget,
      );
      final action = find.widgetWithText(FilledButton, 'Ver mis casos');
      await reveal(tester, action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/my-cases');
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'server counts, zero-chat groups and cancel/toggle at scale $scale',
      (tester) async {
        final repo = InboxCommunity()
          ..groups = [
            inboxGroup(
              'one',
              [inboxThread('thread-one', unread: 3)],
              count: 21,
              unread: 27,
            ),
            inboxGroup('two', [], name: 'Milo'),
          ];
        await start(tester, repo, scale: scale);
        expect(find.text('21 chats abiertos'), findsOneWidget);
        expect(find.text('9+'), findsOneWidget);
        expect(find.text('Mensaje thread-one'), findsOneWidget);
        await reveal(tester, find.text('Sin chats abiertos'));
        expect(
          find.text('Aún no hay mensajes para este caso.'),
          findsOneWidget,
        );
        final header = find.byKey(const ValueKey('rescuer-group-one'));
        await tester.ensureVisible(header);
        await tester.pumpAndSettle();
        final hold = await tester.startGesture(tester.getCenter(header));
        await tester.pump(const Duration(milliseconds: 150));
        await hold.cancel();
        await tester.pump();
        expect(find.text('Mensaje thread-one'), findsOneWidget);
        await tester.tap(header);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Mensaje thread-one'), findsNothing);
        final rotation = tester.widget<AnimatedRotation>(
          find.byKey(const ValueKey('rescuer-group-chevron-one')),
        );
        expect(rotation.duration, const Duration(milliseconds: 200));
        expect(rotation.turns, 0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'group page retry preserves page and deduplicates conversation IDs',
    (tester) async {
      final repo = InboxCommunity()
        ..groups = [
          inboxGroup('one', [inboxThread('thread-one')], count: 3),
        ]
        ..failMore = true
        ..nextThreads = DataPage([
          inboxThread('thread-one'),
          inboxThread('thread-two'),
          inboxThread('thread-three'),
        ], 3);
      await start(tester, repo);
      final more = find.byKey(const ValueKey('rescuer-group-more-one'));
      await reveal(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(repo.groupRequests, [('one', 2, false)]);
      expect(find.text('Volver a intentar'), findsOneWidget);
      repo.failMore = false;
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(repo.groupRequests, [('one', 2, false), ('one', 2, false)]);
      expect(find.text('Mensaje thread-one'), findsOneWidget);
      expect(find.byType(RescuerThreadRow), findsNWidgets(3));
      expect(find.text('3 chats abiertos'), findsOneWidget);
      expect(more, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('collapsed groups survive actual chat return and refresh', (
    tester,
  ) async {
    final repo = InboxCommunity()
      ..groups = [
        inboxGroup('one', [inboxThread('thread-one')]),
        inboxGroup('two', [inboxThread('thread-two')], name: 'Milo'),
      ];
    final container = await start(tester, repo);
    await tester.tap(find.byKey(const ValueKey('rescuer-group-two')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(RescuerThreadRow).first);
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).state.uri.path,
      '/messages/thread-one',
    );
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/messages');
    expect(find.text('Mensaje thread-two'), findsNothing);
    expect(find.text('Mensaje thread-one'), findsOneWidget);
    expect(repo.inboxRequests.length, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history remains reachable and Android Back restores active groups',
    (tester) async {
      final repo = InboxCommunity()
        ..historical = [
          inboxGroup('one', [
            inboxThread('old-thread', closed: true),
          ], name: 'Luna retirada'),
        ];
      final container = await start(tester, repo);
      final history = find.widgetWithText(TextButton, 'Historial de mensajes');
      await reveal(tester, history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(repo.inboxRequests.last, (1, true));
      expect(find.text('Luna retirada'), findsOneWidget);
      expect(find.text('Conversación cerrada'), findsOneWidget);
      expect(find.text('Mensaje old-thread'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/messages');
      expect(repo.inboxRequests.last, (1, false));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late group response cannot enter a different history selection',
    (tester) async {
      final repo = InboxCommunity()
        ..groups = [
          inboxGroup('one', [inboxThread('thread-one')], count: 2),
        ]
        ..pendingThreads = Completer<DataPage<Json>>();
      await start(tester, repo);
      final more = find.byKey(const ValueKey('rescuer-group-more-one'));
      await reveal(tester, more);
      await tester.tap(more);
      await tester.pump();
      final history = find.widgetWithText(TextButton, 'Historial de mensajes');
      await reveal(tester, history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      repo.pendingThreads!.complete(DataPage([inboxThread('late-private')], 2));
      await tester.pumpAndSettle();
      expect(find.text('Mensaje late-private'), findsNothing);
      expect(
        find.text('Aún no tienes conversaciones en tu historial.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('group paging uses the full server total', (tester) async {
    final repo = InboxCommunity()
      ..groupTotal = 21
      ..groups = [inboxGroup('one', [])];
    await start(tester, repo);
    final next = find.byTooltip('Página siguiente');
    await reveal(tester, next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(repo.inboxRequests.last, (2, false));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'personal conversations route preserves the experience and sends nothing',
    (tester) async {
      final repo = InboxCommunity();
      final container = await start(tester, repo);
      final action = find.widgetWithText(TextButton, 'Mis conversaciones');
      await reveal(tester, action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.path,
        '/my-conversations',
      );
      expect(find.byType(RescuerThreadsScreen), findsNothing);
      expect(repo.sentIds, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RescuerThreadsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
