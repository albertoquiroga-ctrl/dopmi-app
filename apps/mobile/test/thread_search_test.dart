import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class ThreadListCommunity extends FakeCommunity {
  ThreadListCommunity() {
    savedItems = [];
    threadItems = [
      {
        'id': 'luna',
        'pet_name': 'Luna',
        'participant_name': 'Ana',
        'last_message': 'Mensaje de Luna',
      },
      {
        'id': 'milo',
        'pet_name': 'Milo',
        'participant_name': 'Patricia',
        'last_message': 'Mensaje de Milo',
      },
    ];
  }

  final queries = <String>[];

  @override
  Future<DataPage<Json>> threads(int page, {String search = ''}) async {
    queries.add(search);
    return DataPage(threadItems, threadItems.length);
  }
}

Future<ProviderContainer> mountThreads(
  WidgetTester tester,
  ThreadListCommunity repo, {
  required bool large,
}) async {
  tester.view.physicalSize = large
      ? const Size(320, 640)
      : const Size(384, 852);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(repo),
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

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'empty Chats offers a compact Discover action without search; large=$large',
      (tester) async {
        final repo = ThreadListCommunity()..threadItems = [];
        final container = await mountThreads(tester, repo, large: large);
        final card = find.byKey(const ValueKey('match-chats-empty'));
        final discover = find.descendant(
          of: card,
          matching: find.text('Descubrir'),
        );
        await tester.scrollUntilVisible(
          discover,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(discover);
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text(
              'Aún no tienes chats. Ponte en contacto con el rescatista de tu compañero favorito.',
            ),
          ),
          findsOneWidget,
        );
        final button = find.ancestor(
          of: discover,
          matching: find.byType(FilledButton),
        );
        expect(
          tester.getCenter(button).dx,
          large
              ? lessThanOrEqualTo(tester.getCenter(card).dx)
              : lessThan(tester.getCenter(card).dx),
          reason:
              'Discover is compact by default and can grow for enlarged text.',
        );
        expect(find.byTooltip('Buscar conversaciones'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(repo.queries, isNotEmpty);
        expect(repo.queries, everyElement(isEmpty));
        await tester.tap(discover);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/adoptions');
        expect(repo.sentIds, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Chats keeps existing conversations and their destination without a query; large=$large',
      (tester) async {
        final repo = ThreadListCommunity();
        final container = await mountThreads(tester, repo, large: large);
        await tester.scrollUntilVisible(
          find.text('Mensaje de Milo'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('match-thread-list')), findsOneWidget);
        expect(find.byKey(const ValueKey('match-chats-empty')), findsNothing);
        expect(find.text('Mensaje de Luna'), findsOneWidget);
        expect(find.text('Mensaje de Milo'), findsOneWidget);
        expect(find.byTooltip('Buscar conversaciones'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(repo.queries, isNotEmpty);
        expect(repo.queries, everyElement(isEmpty));
        await tester.ensureVisible(find.text('Mensaje de Luna'));
        await tester.tap(find.text('Mensaje de Luna'));
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/messages/luna');
        expect(repo.sentIds, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
