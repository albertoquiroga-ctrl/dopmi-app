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

Json inboxThread(
  String id, {
  int unread = 0,
  bool closed = false,
  String group = 'one',
  String name = 'Luna',
  String person = 'Ana',
}) => {
  'id': id,
  'group_id': group,
  'participant_name': person,
  'pet_name': name,
  'photo': '',
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
  List<Json> groups = [], historical = [], members = [], oldMembers = [];
  final inboxRequests = <(int, bool)>[];
  final flatRequests = <(int, String?, bool, bool)>[];
  final watchers = <VoidCallback>[];
  bool failPets = false, failThreads = false, markRead = false;
  int? failPage;
  Completer<DataPage<Json>>? pendingThreads;
  String? pendingGroup;

  @override
  Future<DataPage<Json>> rescuerInbox(int page, {bool history = false}) async {
    inboxRequests.add((page, history));
    if (failPets) throw const FormatException('Offline selector');
    final items = history ? historical : groups;
    return DataPage(
      items.skip((page - 1) * 20).take(20).toList(),
      items.length,
    );
  }

  @override
  Future<DataPage<Json>> rescuerThreads(
    int page, {
    String? groupId,
    bool unreadOnly = false,
    bool history = false,
  }) async {
    flatRequests.add((page, groupId, unreadOnly, history));
    if (pendingThreads != null && groupId == pendingGroup) {
      return pendingThreads!.future;
    }
    if (failThreads || failPage == page) {
      throw const FormatException('Offline chats');
    }
    final items = (history ? oldMembers : members)
        .where(
          (e) =>
              (groupId == null || e['group_id'] == groupId) &&
              (!unreadOnly || (e['unread_count'] as int) > 0),
        )
        .toList();
    return DataPage(
      items.skip((page - 1) * 20).take(20).toList(),
      items.length,
    );
  }

  @override
  VoidCallback watch(List<String> tables, VoidCallback refresh) {
    watchers.add(refresh);
    return () => watchers.remove(refresh);
  }

  void changed() {
    for (final refresh in List<VoidCallback>.from(watchers)) {
      refresh();
    }
  }

  @override
  Future<void> readThread(String id) async {
    if (!markRead) return;
    for (final row in members.where((e) => e['id'] == id)) {
      row['unread_count'] = 0;
    }
    for (final group in groups) {
      group['unread_count'] = members
          .where((e) => e['group_id'] == group['id'])
          .fold<int>(0, (sum, e) => sum + (e['unread_count'] as int));
    }
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
        : const Size(377, 852);
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

  Finder pet(String id) => find.byKey(ValueKey('rescuer-pet-$id'));
  Finder row(String id) => find.byKey(ValueKey('rescuer-thread-$id'));
  final unreadFilter = find.byKey(const ValueKey('rescuer-unread-filter'));

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'pet and unread filters combine with complete badge counts at $scale',
      (tester) async {
        final repo = InboxCommunity()
          ..groups = [
            inboxGroup('one', [], unread: 27),
            inboxGroup('two', [], name: 'Milo'),
          ]
          ..members = [
            inboxThread('ana', unread: 3),
            inboxThread('sofia', person: 'Sofía'),
            inboxThread('carlos', group: 'two', name: 'Milo', person: 'Carlos'),
          ];
        await start(tester, repo, scale: scale);
        expect(find.text('9+'), findsOneWidget);
        await reveal(tester, find.byKey(const ValueKey('rescuer-chats-panel')));
        expect(find.byType(RescuerInboxGroup), findsNothing);
        expect(find.byType(RescuerThreadRow), findsNWidgets(3));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 650));
        await tester.pumpAndSettle();
        await tester.ensureVisible(pet('one'));
        await tester.tap(pet('one'));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('rescuer-chats-panel')));
        expect(repo.flatRequests.last, (1, 'one', false, false));
        expect(row('sofia'), findsOneWidget);
        expect(row('carlos'), findsNothing);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 650));
        await tester.pumpAndSettle();
        await reveal(tester, unreadFilter);
        await tester.tap(unreadFilter);
        await tester.pumpAndSettle();
        expect(repo.flatRequests.last, (1, 'one', true, false));
        expect(find.text('Mostrar todos'), findsOneWidget);
        expect(row('ana'), findsOneWidget);
        expect(row('sofia'), findsNothing);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 650));
        await tester.pumpAndSettle();
        expect(find.text('9+'), findsOneWidget);
        await tester.ensureVisible(pet('two'));
        await tester.tap(pet('two'));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('rescuer-chats-panel')));
        expect(repo.flatRequests.last, (1, 'two', true, false));
        expect(find.text('No tienes mensajes sin leer.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'empty inbox and horizontal drag preserve touch selection at $scale',
      (tester) async {
        final repo = InboxCommunity()
          ..groups = List.generate(
            8,
            (i) => inboxGroup('pet-$i', [], name: 'Mascota $i'),
          );
        await start(tester, repo, scale: scale);
        await reveal(tester, find.byKey(const ValueKey('rescuer-chats-panel')));
        expect(find.text('Aún no tienes mensajes'), findsOneWidget);
        expect(find.text('No tienes casos en adopción abiertos'), findsNothing);
        final before = repo.flatRequests.length;
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 650));
        await tester.pumpAndSettle();
        final rail = find.byKey(const ValueKey('rescuer-pet-rail'));
        await tester.ensureVisible(rail);
        await tester.drag(rail, const Offset(-230, 0));
        await tester.pumpAndSettle();
        expect(repo.flatRequests.length, before);
        await tester.ensureVisible(pet('pet-4'));
        await tester.pumpAndSettle();
        final hold = await tester.startGesture(tester.getCenter(pet('pet-4')));
        await tester.pump(const Duration(milliseconds: 150));
        await hold.cancel();
        await tester.pumpAndSettle();
        expect(repo.flatRequests.length, before);
        await tester.tap(pet('pet-4'));
        await tester.pumpAndSettle();
        expect(repo.flatRequests.last, (1, 'pet-4', false, false));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'read failure retries and never fabricates an empty conversation list',
    (tester) async {
      final repo = InboxCommunity()
        ..failThreads = true
        ..groups = [inboxGroup('one', [])]
        ..members = [inboxThread('ana')];
      await start(tester, repo);
      expect(find.text('Aún no tienes mensajes'), findsNothing);
      repo.failThreads = false;
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      expect(row('ana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'flat pagination uses server totals and changing either filter resets page',
    (tester) async {
      final repo = InboxCommunity()
        ..groups = [inboxGroup('one', [])]
        ..members = List.generate(
          23,
          (i) => inboxThread('thread-$i', unread: 1),
        );
      await start(tester, repo);
      final next = find.byTooltip('Página siguiente');
      await reveal(tester, next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last, (2, null, false, false));
      expect(find.byType(RescuerThreadRow), findsNWidgets(3));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 650));
      await tester.pumpAndSettle();
      await reveal(tester, unreadFilter);
      await tester.tap(unreadFilter);
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last, (1, null, true, false));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 650));
      await tester.pumpAndSettle();
      await tester.ensureVisible(pet('one'));
      await tester.tap(pet('one'));
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last, (1, 'one', true, false));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selector loads more than twenty pets without flattening group chats',
    (tester) async {
      final repo = InboxCommunity()
        ..groups = List.generate(
          25,
          (i) => inboxGroup('pet-$i', [
            inboxThread('nested-fake-$i'),
          ], name: 'Mascota $i'),
        );
      await start(tester, repo);
      expect(find.byType(RescuerThreadRow), findsNothing);
      final more = find.byKey(const ValueKey('rescuer-pets-more'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(repo.inboxRequests.last, (2, false));
      await tester.ensureVisible(pet('pet-24'));
      await tester.tap(pet('pet-24'));
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last, (1, 'pet-24', false, false));
      expect(more, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late query cannot enter a different pet selection', (
    tester,
  ) async {
    final repo = InboxCommunity()
      ..groups = [inboxGroup('one', []), inboxGroup('two', [], name: 'Milo')]
      ..members = [inboxThread('milo', group: 'two', name: 'Milo')];
    await start(tester, repo);
    repo.pendingGroup = 'one';
    repo.pendingThreads = Completer<DataPage<Json>>();
    await tester.tap(pet('one'));
    await tester.pump();
    await tester.tap(pet('two'));
    await tester.pumpAndSettle();
    repo.pendingThreads!.complete(DataPage([inboxThread('late-private')], 1));
    await tester.pumpAndSettle();
    expect(row('late-private'), findsNothing);
    expect(row('milo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removed selection resets to all only after an authorized selector refresh',
    (tester) async {
      final repo = InboxCommunity()
        ..groups = [inboxGroup('one', []), inboxGroup('two', [], name: 'Milo')]
        ..members = [inboxThread('milo', group: 'two', name: 'Milo')];
      await start(tester, repo);
      await tester.tap(pet('one'));
      await tester.pumpAndSettle();
      repo.groups.removeAt(0);
      repo.changed();
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last, (1, null, false, false));
      expect(row('milo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history remains reachable and system Back restores active filters',
    (tester) async {
      final repo = InboxCommunity()
        ..groups = [inboxGroup('one', [], unread: 1)]
        ..members = [inboxThread('ana', unread: 1)]
        ..historical = [inboxGroup('old', [], name: 'Luna retirada')]
        ..oldMembers = [
          inboxThread(
            'old-thread',
            group: 'old',
            name: 'Luna retirada',
            closed: true,
          ),
        ];
      final container = await start(tester, repo);
      await tester.tap(pet('one'));
      await tester.pumpAndSettle();
      await tester.tap(unreadFilter);
      await tester.pumpAndSettle();
      final history = find.widgetWithText(TextButton, 'Historial de mensajes');
      await reveal(tester, history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last, (1, null, false, true));
      expect(find.text('Conversación cerrada'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/messages');
      expect(repo.flatRequests.last, (1, 'one', true, false));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'two adopters open distinct real thread IDs; reading refreshes active unread filter',
    (tester) async {
      final repo = InboxCommunity()
        ..markRead = true
        ..groups = [inboxGroup('one', [], unread: 2)]
        ..members = [
          inboxThread('ana', unread: 1),
          inboxThread('sofia', unread: 1, person: 'Sofía'),
        ];
      final container = await start(tester, repo);
      await tester.tap(pet('one'));
      await tester.pumpAndSettle();
      await tester.tap(unreadFilter);
      await tester.pumpAndSettle();
      await tester.tap(row('sofia'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/messages/sofia');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last, (1, 'one', true, false));
      expect(row('sofia'), findsNothing);
      expect(row('ana'), findsOneWidget);
      await tester.tap(row('ana'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/messages/ana');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('No tienes mensajes sin leer.'), findsOneWidget);
      expect(repo.sentIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat return preserves selector and list scroll', (tester) async {
    final repo = InboxCommunity()
      ..groups = [inboxGroup('one', [])]
      ..members = List.generate(12, (i) => inboxThread('thread-$i'));
    final container = await start(tester, repo);
    await tester.tap(pet('one'));
    await tester.pumpAndSettle();
    await reveal(tester, row('thread-9'));
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(offset, greaterThan(0));
    await tester.tap(row('thread-9'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/messages/thread-9');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(repo.flatRequests.last, (1, 'one', false, false));
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      closeTo(offset, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal conversations keeps experience and sends nothing', (
    tester,
  ) async {
    final repo = InboxCommunity();
    final container = await start(tester, repo);
    final action = find.widgetWithText(TextButton, 'Mis conversaciones');
    await reveal(tester, action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/my-conversations');
    expect(find.byType(RescuerThreadsScreen), findsNothing);
    expect(repo.sentIds, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RescuerThreadsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
