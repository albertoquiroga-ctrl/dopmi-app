import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_adoption_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;

class PendingPublicFavorite extends FakeCommunity {
  final pending = Completer<void>();
  String? requestedId;
  @override
  Future<void> favorite(String id, bool saved) {
    requestedId = id;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'obsolete favorite response cannot overwrite a replacement public card',
    (tester) async {
      final repo = PendingPublicFavorite();
      final selected = ValueNotifier(repo.post);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: dopmiTheme(),
            home: Scaffold(
              body: ValueListenableBuilder<Adoption>(
                valueListenable: selected,
                builder: (_, post, _) =>
                    PublicProfileAdoptionCard(post, open: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Guardar mascota'));
      await tester.pump();
      expect(repo.requestedId, repo.post.id);
      selected.value = Adoption({
        ...repo.post.data,
        'id': 'second',
        'pet_name': 'Toby',
        'saved': false,
        'distance_km': 3.4,
      });
      await tester.pumpAndSettle();
      expect(find.text('3.4 km'), findsOneWidget);
      expect(find.byTooltip('Guardar mascota'), findsOneWidget);
      repo.pending.completeError(Exception('old request offline'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Guardar mascota'), findsOneWidget);
      expect(find.text('Conoce la historia de Toby'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'public adoption save rolls back failure and retries real favorite',
    (tester) async {
      final repo = FakeCommunity()..failFavorite = true;
      var opened = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: dopmiTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 288,
                child: PublicProfileAdoptionCard(
                  repo.post,
                  open: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Guardar mascota'));
      await tester.pumpAndSettle();
      expect(repo.post.saved, isFalse);
      expect(find.byTooltip('Guardar mascota'), findsOneWidget);
      repo.failFavorite = false;
      await tester.tap(find.byTooltip('Guardar mascota'));
      await tester.pumpAndSettle();
      expect(repo.post.saved, isTrue);
      expect(find.byTooltip('Quitar de guardados'), findsOneWidget);
      await tester.tap(find.text('Conoce la historia de Luna'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
