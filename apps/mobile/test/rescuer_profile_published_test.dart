import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class PublishedCommunity extends FakeCommunity {
  bool visible = true, fail = false, wrongOwner = false;
  final requested = <String>[];
  @override
  Future<Json?> publicProfile(String id) async {
    requested.add(id);
    if (fail) throw const FormatException('Offline');
    if (!visible) return null;
    return {
      'id': wrongOwner ? 'other' : id,
      'name': wrongOwner ? 'Nombre ajeno' : 'Nombre público aprobado',
      'city': 'Monterrey',
      'region': 'Nuevo León',
      'bio': 'Descripción aprobada.',
      'draft_bio': 'Texto privado no aprobado',
      'email': 'private-fixture@example.test',
    };
  }
}

void main() {
  testWidgets(
    'withdrawal removes public identity and biography without reading private draft fields',
    (tester) async {
      final community = PublishedCommunity();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityRepositoryProvider.overrideWithValue(community),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RescuerProfileHero(FakeIdentityRepository().profile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nombre público aprobado'), findsOneWidget);
      expect(find.text('Descripción aprobada.'), findsOneWidget);
      expect(find.text('Texto privado no aprobado'), findsNothing);
      expect(find.text('private-fixture@example.test'), findsNothing);
      expect(community.requested, ['one']);
      community.visible = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Nombre público aprobado'), findsNothing);
      expect(find.text('Descripción aprobada.'), findsNothing);
      expect(find.text('Sobre ti'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final mismatch in [false, true]) {
    testWidgets(
      'public read error or owner mismatch preserves valid dashboard and permits retry: $mismatch',
      (tester) async {
        final community = PublishedCommunity()
          ..wrongOwner = mismatch
          ..fail = !mismatch;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityRepositoryProvider.overrideWithValue(community),
              rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RescuerProfileHero(FakeIdentityRepository().profile),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Verificado'), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('Nombre ajeno'), findsNothing);
        expect(find.text('Descripción aprobada.'), findsNothing);
        community.fail = false;
        community.wrongOwner = false;
        await tester.ensureVisible(find.text('Reintentar perfil público'));
        await tester.tap(find.text('Reintentar perfil público'));
        await tester.pumpAndSettle();
        expect(find.text('Nombre público aprobado'), findsOneWidget);
        expect(find.text('Descripción aprobada.'), findsOneWidget);
        expect(community.requested, ['one', 'one']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
