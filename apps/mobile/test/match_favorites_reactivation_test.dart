import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'favorite_refresh_repository_test.dart'
    show FavoriteRefreshRepository, SilentFavoriteSocketClient;

class ReactivatedFavoritesCommunity extends FakeCommunity {
  ReactivatedFavoritesCommunity({bool saved = false}) {
    post = Adoption({
      ...post.data,
      'pet_name': 'Michi',
      'species': 'cat',
      'saved': saved,
    });
    failSend = false;
  }

  int favoriteReads = 0;

  // This repository deliberately emits no Realtime events. A successful write
  // is visible on the next read, as it is for the persisted server favorite.
  @override
  Future<DataPage<SavedEntry>> savedAdoptions(int page) async => DataPage([
    if (post.saved)
      SavedEntry({...post.data, 'available': true, 'saved': true}),
  ], post.saved ? 1 : 0);

  @override
  Future<DataPage<SavedEntry>> matchFavorites(int page) async {
    favoriteReads++;
    return sentIds.isNotEmpty
        ? const DataPage([], 0)
        : await savedAdoptions(page);
  }
}

class PendingFavoritesCommunity extends ReactivatedFavoritesCommunity {
  PendingFavoritesCommunity() {
    _transport = _PendingFavoriteRepository(client, (params) async {
      await allowFavorite.future;
      await super.favorite(
        params['post_id'] as String,
        params['saved'] as bool,
      );
    });
  }

  final allowFavorite = Completer<void>();
  final favoriteFinished = Completer<void>();
  final client = SilentFavoriteSocketClient();
  late final _PendingFavoriteRepository _transport;

  @override
  Future<void> favorite(String id, bool saved) async {
    await _transport.favorite(id, saved);
    favoriteFinished.complete();
  }

  @override
  VoidCallback watch(List<String> tables, VoidCallback refresh) =>
      _transport.watch(tables, refresh);
}

class _PendingFavoriteRepository extends FavoriteRefreshRepository {
  _PendingFavoriteRepository(super.client, this.write);
  final Future<void> Function(Json) write;

  @override
  Future<dynamic> rpc(String name, [Json params = const {}]) async {
    expect(name, 'dopmi_set_favorite');
    await write(params);
  }
}

Future<VoidCallback> mountMatches(
  WidgetTester tester,
  ReactivatedFavoritesCommunity repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final semantics = tester.ensureSemantics();
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(repository),
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
  return semantics.dispose;
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a like committing after Matches reopens refreshes without Realtime or polling',
    (tester) async {
      final repository = PendingFavoritesCommunity();
      addTearDown(repository.client.dispose);
      final disposeSemantics = await mountMatches(tester, repository);
      final started = tester.binding.clock.now();
      await openTab(tester, 'Adoptar');
      await tester.drag(find.text('Michi').hitTestable(), const Offset(230, 0));
      await tester.pumpAndSettle();
      expect(repository.post.saved, false);
      await openTab(tester, 'Mis match');
      expect(find.byTooltip('Escribir sobre Michi'), findsNothing);

      repository.allowFavorite.complete();
      await repository.favoriteFinished.future;
      await tester.pumpAndSettle();
      expect(repository.post.saved, true);
      expect(find.byTooltip('Escribir sobre Michi'), findsOneWidget);
      expect(
        tester.binding.clock.now().difference(started),
        lessThan(const Duration(seconds: 30)),
      );
      expect(tester.takeException(), isNull);
      disposeSemantics();
    },
  );

  testWidgets(
    'swiping right then returning to retained Matches shows the cat without Realtime or polling',
    (tester) async {
      final repository = ReactivatedFavoritesCommunity();
      final disposeSemantics = await mountMatches(tester, repository);
      final firstReads = repository.favoriteReads;
      expect(find.byTooltip('Escribir sobre Michi'), findsNothing);
      final started = tester.binding.clock.now();

      await openTab(tester, 'Adoptar');
      await tester.drag(find.text('Michi').hitTestable(), const Offset(230, 0));
      await tester.pumpAndSettle();
      expect(repository.post.saved, true);
      await openTab(tester, 'Mis match');

      expect(find.byTooltip('Escribir sobre Michi'), findsOneWidget);
      expect(repository.favoriteReads, greaterThan(firstReads));
      expect(
        tester.binding.clock.now().difference(started),
        lessThan(const Duration(seconds: 30)),
      );
      expect(tester.takeException(), isNull);
      disposeSemantics();
    },
  );

  testWidgets(
    'returning to retained Matches removes an unsaved cat without Realtime',
    (tester) async {
      final repository = ReactivatedFavoritesCommunity(saved: true);
      final disposeSemantics = await mountMatches(tester, repository);
      expect(find.byTooltip('Escribir sobre Michi'), findsOneWidget);

      await openTab(tester, 'Adoptar');
      await repository.favorite(repository.post.id, false);
      await openTab(tester, 'Mis match');

      expect(find.byTooltip('Escribir sobre Michi'), findsNothing);
      expect(tester.takeException(), isNull);
      disposeSemantics();
    },
  );

  testWidgets(
    'returning to Matches does not restore a favorite after an adopter message',
    (tester) async {
      final repository = ReactivatedFavoritesCommunity(saved: true);
      final disposeSemantics = await mountMatches(tester, repository);
      expect(find.byTooltip('Escribir sobre Michi'), findsOneWidget);

      await openTab(tester, 'Adoptar');
      await repository.sendMessage('thread-one', 'message-one', 'Hola');
      await openTab(tester, 'Mis match');
      expect(find.byTooltip('Escribir sobre Michi'), findsNothing);

      await openTab(tester, 'Adoptar');
      await repository.favorite(repository.post.id, true);
      await openTab(tester, 'Mis match');
      expect(find.byTooltip('Escribir sobre Michi'), findsNothing);
      expect(repository.post.saved, true);
      expect(tester.takeException(), isNull);
      disposeSemantics();
    },
  );
}
