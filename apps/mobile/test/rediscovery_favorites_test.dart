import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/discovery_empty.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class RediscoveryCommunity extends FakeCommunity {
  final favoriteIds = <String>{};
  final favoriteWrites = <(String, bool)>[];
  final requestedPages = <int>[];
  final pages = <int, List<Adoption>>{};
  var resets = 0;

  Adoption pet(String id, String name) =>
      Adoption({...post.data, 'id': id, 'pet_name': name});

  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) async {
    requestedPages.add(page);
    return DataPage([
      for (final item in pages[page] ?? <Adoption>[])
        Adoption({...item.data, 'saved': favoriteIds.contains(item.id)}),
    ], pages.values.fold(0, (total, items) => total + items.length));
  }

  @override
  Future<void> favorite(String id, bool saved) async {
    favoriteWrites.add((id, saved));
    if (saved) {
      favoriteIds.add(id);
    } else {
      favoriteIds.remove(id);
    }
  }

  @override
  Future<DataPage<SavedEntry>> savedAdoptions(int page) async => DataPage([
    for (final item in pages.values.expand((items) => items))
      if (favoriteIds.contains(item.id))
        SavedEntry({...item.data, 'saved': true, 'available': true}),
  ], favoriteIds.length);

  @override
  Future<void> resetSeenAdoptions() async {
    resets++;
    await super.resetSeenAdoptions();
  }
}

class DelayedFavoriteCommunity extends RediscoveryCommunity {
  final allowFavorite = Completer<void>();
  final favoriteCommitted = Completer<void>();
  final allowRefresh = Completer<void>();
  var refreshWaiting = false;

  @override
  Future<void> favorite(String id, bool saved) async {
    await allowFavorite.future;
    await super.favorite(id, saved);
    favoriteCommitted.complete();
  }

  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) async {
    final snapshot = await super.discovery(filters, page);
    if (resets > 0) {
      refreshWaiting = true;
      await allowRefresh.future;
    }
    return snapshot;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    RediscoveryCommunity repository,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repository),
        routerInitialLocationProvider.overrideWithValue('/adoptions'),
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
  }

  Finder restartButton() => find.descendant(
    of: find.byType(DiscoveryEnd),
    matching: find.byType(OutlinedButton),
  );

  testWidgets(
    'rediscovery returns passed pets and preserves existing matches outside the deck',
    (tester) async {
      final repository = RediscoveryCommunity();
      repository.pages[1] = [
        repository.pet('liked', 'Luna favorita'),
        repository.pet('passed', 'Milo pasado'),
      ];
      repository.favoriteIds.add('liked');
      repository.seen.addAll({'liked', 'passed'});
      await open(tester, repository);
      expect(find.byType(DiscoveryEnd), findsOneWidget);

      await tester.ensureVisible(restartButton());
      await tester.pumpAndSettle();
      await tester.tap(restartButton());
      await tester.pumpAndSettle();

      expect(find.text('Luna favorita'), findsNothing);
      expect(find.text('Milo pasado'), findsOneWidget);
      expect(repository.resets, 1);
      expect(
        (await repository.savedAdoptions(1)).items.map((item) => item.id),
        ['liked'],
      );
      expect(repository.favoriteWrites, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a new client skips a page of server favorites and shows later eligible pets',
    (tester) async {
      final repository = RediscoveryCommunity();
      repository.pages.addAll({
        1: [
          repository.pet('liked', 'Luna favorita'),
          repository.pet('also-liked', 'Nina favorita'),
        ],
        2: [repository.pet('eligible', 'Milo disponible')],
      });
      repository.favoriteIds.addAll({'liked', 'also-liked'});
      // This device has no local or restored viewing history.
      await open(tester, repository);

      expect(find.text('Luna favorita'), findsNothing);
      expect(find.text('Nina favorita'), findsNothing);
      expect(find.text('Milo disponible'), findsOneWidget);
      expect(repository.requestedPages, [1, 2]);
      expect(repository.favoriteWrites, isEmpty);
      expect(
        (await repository.savedAdoptions(1)).items.map((item) => item.id),
        ['liked', 'also-liked'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a like completing during restart stays excluded from a stale catalog response',
    (tester) async {
      final repository = DelayedFavoriteCommunity();
      repository.pages[1] = [repository.pet('liked', 'Luna favorita')];
      await open(tester, repository);

      await tester.tap(find.byTooltip('Me gusta').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryEnd), findsOneWidget);
      await tester.ensureVisible(restartButton());
      await tester.pumpAndSettle();
      await tester.tap(restartButton());
      await tester.pump();
      expect(repository.refreshWaiting, isTrue);

      repository.allowFavorite.complete();
      await repository.favoriteCommitted.future;
      await tester.pump();
      repository.allowRefresh.complete();
      await tester.pumpAndSettle();

      expect(find.text('Luna favorita'), findsNothing);
      expect(find.byType(DiscoveryEnd), findsOneWidget);
      expect(
        (await repository.savedAdoptions(1)).items.map((item) => item.id),
        ['liked'],
      );
      expect(repository.favoriteWrites, [('liked', true)]);
      expect(tester.takeException(), isNull);
    },
  );
}
