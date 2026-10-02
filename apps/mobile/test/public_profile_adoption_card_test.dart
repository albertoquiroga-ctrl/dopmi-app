import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_adoption_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;

void main() {
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
