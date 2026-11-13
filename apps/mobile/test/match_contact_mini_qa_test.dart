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

class FavoriteContactCommunity extends FakeCommunity {
  FavoriteContactCommunity() {
    savedItems = [
      SavedEntry({
        'id': 'saved-zelda',
        'pet_name': 'Zelda',
        'available': true,
        'photos': <String>[],
      }),
    ];
  }

  final startedPosts = <String>[];
  Completer<String>? pendingStart;
  bool contacted = false;

  @override
  Future<DataPage<SavedEntry>> matchFavorites(int page) async =>
      contacted || sentIds.isNotEmpty
      ? const DataPage([], 0)
      : await savedAdoptions(page);

  @override
  Future<String> startThread(String postId) async {
    startedPosts.add(postId);
    final threadId = pendingStart == null
        ? 'thread-one'
        : await pendingStart!.future;
    contacted = true;
    return threadId;
  }
}

Future<ProviderContainer> mountFavoriteContact(
  WidgetTester tester,
  FavoriteContactCommunity repo,
) async {
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
  for (final dismissal in ['later', 'close']) {
    testWidgets(
      'favorite uses its public name and cancellation writes nothing: $dismissal',
      (tester) async {
        final repo = FavoriteContactCommunity();
        final container = await mountFavoriteContact(tester, repo);
        await tester.tap(find.byTooltip('Escribir sobre Zelda'));
        await tester.pumpAndSettle();
        expect(find.text('Conectar con Zelda'), findsOneWidget);
        expect(find.text('Conectar con la mascota'), findsNothing);
        expect(repo.startedPosts, isEmpty);
        await tester.tap(
          dismissal == 'later'
              ? find.text('Todavía no')
              : find.byTooltip('Cerrar'),
        );
        await tester.pumpAndSettle();
        expect(repo.startedPosts, isEmpty);
        expect(repo.sentIds, isEmpty);
        expect(find.byTooltip('Escribir sobre Zelda'), findsOneWidget);
        expect(container.read(routerProvider).state.uri.path, '/messages');
        expect(find.text('Sí, contactar rescatista'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('repeated contact waits for the same confirmed request', (
    tester,
  ) async {
    final repo = FavoriteContactCommunity()..pendingStart = Completer<String>();
    final container = await mountFavoriteContact(tester, repo);
    final contact = find.byTooltip('Escribir sobre Zelda');
    await tester.tap(contact);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, contactar rescatista'));
    await tester.pump();
    expect(repo.startedPosts, ['saved-zelda']);
    await tester.tap(contact);
    await tester.pump();
    expect(repo.startedPosts, ['saved-zelda']);
    expect(find.text('Sí, contactar rescatista'), findsNothing);
    expect(container.read(routerProvider).state.uri.path, '/messages');
    repo.pendingStart!.complete('thread-one');
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).state.uri.path,
      '/messages/thread-one',
    );
    expect(repo.startedPosts, ['saved-zelda']);
    expect(repo.sentIds, isEmpty);
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/messages');
    expect(contact, findsNothing);
    expect((await repo.savedAdoptions(1)).items.single.id, 'saved-zelda');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'returning from an existing chat refreshes favorites without Realtime',
    (tester) async {
      final repo = FavoriteContactCommunity()
        ..threadItems = [
          {
            'id': 'thread-one',
            'post_id': 'saved-zelda',
            'pet_name': 'Zelda',
            'participant_name': 'Ana',
            'last_message': 'Mensaje de Ana',
          },
        ];
      final container = await mountFavoriteContact(tester, repo);
      final favorite = find.byTooltip('Escribir sobre Zelda');
      expect(favorite, findsOneWidget);
      final thread = find.text('Mensaje de Ana');
      await tester.ensureVisible(thread);
      await tester.tap(thread);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.path,
        '/messages/thread-one',
      );

      await tester.enterText(find.byType(TextField), 'Hola, me interesa Zelda');
      await tester.pump();
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(repo.sentIds, hasLength(1));

      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(favorite, findsNothing);
      expect(find.text('Mensaje de Ana'), findsOneWidget);
      expect((await repo.savedAdoptions(1)).items.single.id, 'saved-zelda');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed contact keeps the favorite in Mis matches', (
    tester,
  ) async {
    final repo = FavoriteContactCommunity()..pendingStart = Completer<String>();
    final container = await mountFavoriteContact(tester, repo);
    final contact = find.byTooltip('Escribir sobre Zelda');
    await tester.tap(contact);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, contactar rescatista'));
    await tester.pump();
    repo.pendingStart!.completeError(StateError('fixture contact failure'));
    await tester.pumpAndSettle();
    expect(repo.startedPosts, ['saved-zelda']);
    expect(contact, findsOneWidget);
    expect(container.read(routerProvider).state.uri.path, '/messages');
    expect(tester.takeException(), isNull);
  });
}
