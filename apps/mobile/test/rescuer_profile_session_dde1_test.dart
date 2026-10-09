import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/catalog_screens.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;
import 'rescuer_profile_published_test.dart' show PublishedCommunity;

class SessionProfile extends FakeRescuerProfile {
  SessionProfile() {
    value = {
      'owner_id': 'one',
      'display_name': 'Fresh owner draft',
      'bio': 'Fresh biography',
    };
  }
  final first = Completer<Json?>();
  bool delayed = false;
  int reads = 0;
  @override
  String? get userId => 'one';
  @override
  Future<Json?> load() async {
    reads++;
    if (delayed && reads == 1) return first.future;
    return value;
  }
}

void main() {
  testWidgets(
    'public withdrawal never reads or displays the owner private draft',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'private@example.test', verified: true);
      final repository = SessionProfile()
        ..value = {
          'owner_id': 'one',
          'display_name': 'Private unpublished name',
          'bio': 'Private unpublished biography',
        };
      final community = PublishedCommunity();
      addTearDown(() => identity.changes.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            rescuerProfileRepositoryProvider.overrideWithValue(repository),
            communityRepositoryProvider.overrideWithValue(community),
          ],
          child: const MaterialApp(home: PublicProfileScreen('one')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nombre p\u00fablico aprobado'), findsOneWidget);
      expect(find.text('Descripci\u00f3n aprobada.'), findsOneWidget);
      expect(
        find.text('Private unpublished name', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('Private unpublished biography', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('private@example.test', skipOffstage: false),
        findsNothing,
      );
      expect(repository.reads, 0);
      community.visible = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.text('Nombre p\u00fablico aprobado', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('Descripci\u00f3n aprobada.', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('Private unpublished name', skipOffstage: false),
        findsNothing,
      );
      expect(repository.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final delayed in [false, true]) {
    testWidgets(
      'owner hero rejects ${delayed ? 'late A to B to A' : 'mismatched'} private draft without leaking partial data',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity('one', 'owner@example.test', verified: true);
        final repository = SessionProfile()..delayed = delayed;
        if (!delayed) {
          repository.value = {
            'owner_id': 'other',
            'display_name': 'Foreign secret',
            'bio': 'Foreign private biography',
            'instagram_url': 'https://example.test/private',
          };
        }
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            rescuerProfileRepositoryProvider.overrideWithValue(repository),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RescuerProfileHero(identity.profile),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        if (delayed) {
          identity.emit(
            const IdentityEvent(
              Identity('other', 'other@example.test', verified: true),
            ),
          );
          await tester.pump();
          expect(
            find.text('Fresh owner draft', skipOffstage: false),
            findsNothing,
          );
          identity.emit(
            const IdentityEvent(
              Identity('one', 'owner@example.test', verified: true),
            ),
          );
          await tester.pump();
          await tester.pumpAndSettle();
          expect(find.text('Fresh owner draft'), findsOneWidget);
          repository.first.complete({
            'owner_id': 'one',
            'display_name': 'Stale private secret',
            'bio': 'Stale biography',
          });
          await tester.pumpAndSettle();
          expect(
            find.text('Stale private secret', skipOffstage: false),
            findsNothing,
          );
          expect(
            find.text('Stale biography', skipOffstage: false),
            findsNothing,
          );
          expect(find.text('Fresh owner draft'), findsOneWidget);
        } else {
          await tester.pumpAndSettle();
          expect(
            find.text('Foreign secret', skipOffstage: false),
            findsNothing,
          );
          expect(
            find.text('Foreign private biography', skipOffstage: false),
            findsNothing,
          );
          expect(
            find.text('https://example.test/private', skipOffstage: false),
            findsNothing,
          );
          repository.value = {
            'owner_id': 'one',
            'display_name': 'Fresh owner draft',
          };
          await tester.tap(find.text('Volver a intentar'));
          await tester.pumpAndSettle();
          expect(find.text('Fresh owner draft'), findsOneWidget);
        }
        expect(repository.saves, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
