import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/discovery_empty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'discovery_stack_transition_test.dart'
    show CardPhotoCommunity, frontAction, openCards;

class HistoryCommunity extends CardPhotoCommunity {
  final marked = <String>[];
  final pages = <int>[];
  int resets = 0, favoriteCalls = 0;
  bool failRead = false, paged = false, bySpecies = false;

  @override
  Future<Set<String>> seenAdoptions() async {
    if (failRead) throw StateError('offline');
    return Set.of(seen);
  }

  @override
  Future<void> markAdoptionSeen(String id) async {
    marked.add(id);
    seen.add(id);
  }

  @override
  Future<void> resetSeenAdoptions() async {
    resets++;
    seen.clear();
  }

  @override
  Future<void> favorite(String id, bool saved) async {
    favoriteCalls++;
    await super.favorite(id, saved);
  }

  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) async {
    pages.add(page);
    if (bySpecies) {
      final items = discoveryItems!;
      final result = filters['species'] == 'dog'
          ? [items.first]
          : items.skip(1).toList();
      return DataPage(result, result.length);
    }
    if (!paged) return super.discovery(filters, page);
    final items = discoveryItems!;
    return DataPage(page == 1 ? items.take(2).toList() : [items.last], 3);
  }
}

void main() {
  testWidgets(
    'seen pages are skipped and only the decoded front enters history without analytics',
    (tester) async {
      final repository = HistoryCommunity()
        ..seen.addAll(['post', 'second'])
        ..paged = true;
      await openCards(tester, repository: repository, support: false);
      expect(repository.pages, [1, 2]);
      expect(find.text('Nube'), findsWidgets);
      expect(find.text('Luna'), findsNothing);
      expect(repository.marked, ['third']);
      expect(repository.recordedViews, isEmpty);
      expect(find.byType(DiscoveryEnd), findsNothing);
      await tester.tap(frontAction('Pasar'));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryEnd), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only explicit restart clears seen history and preserves favorites and views',
    (tester) async {
      final repository = HistoryCommunity()
        ..seen.addAll(['post', 'second', 'third']);
      repository.recordedViews.add('historic');
      await openCards(tester, repository: repository, support: false);
      expect(find.byType(DiscoveryEnd), findsOneWidget);
      expect(find.byType(DiscoveryEmpty), findsNothing);
      expect(repository.resets, 0);
      final restart = find.descendant(
        of: find.byType(DiscoveryEnd),
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(restart);
      await tester.tap(restart);
      await tester.pumpAndSettle();
      expect(repository.resets, 1);
      expect(find.text('Luna'), findsWidgets);
      expect(repository.marked, ['post']);
      expect(repository.recordedViews, ['historic']);
      expect(repository.favoriteCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing species preserves the account cycle until explicit restart',
    (tester) async {
      final repository = HistoryCommunity()..bySpecies = true;
      await openCards(tester, repository: repository, support: false);
      expect(repository.marked, ['post']);
      await tester.tap(find.text('Gatos'));
      await tester.pumpAndSettle();
      expect(find.text('Milo'), findsWidgets);
      expect(repository.marked, ['post', 'second']);
      await tester.tap(find.text('Perros'));
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsNothing);
      expect(find.byType(DiscoveryEnd), findsOneWidget);
      expect(repository.resets, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history read failure shows retry without catalog cards or a false empty/end',
    (tester) async {
      final repository = HistoryCommunity()..failRead = true;
      await openCards(tester, repository: repository, support: false);
      expect(repository.pages, isEmpty);
      expect(find.text('Luna'), findsNothing);
      expect(find.byType(DiscoveryEmpty), findsNothing);
      expect(find.byType(DiscoveryEnd), findsNothing);
      expect(find.text('Volver a intentar'), findsOneWidget);
      repository.failRead = false;
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsWidgets);
      expect(repository.marked, ['post']);
      expect(tester.takeException(), isNull);
    },
  );
}
