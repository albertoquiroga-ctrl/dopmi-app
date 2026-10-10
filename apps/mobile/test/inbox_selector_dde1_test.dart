import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_threads_test.dart' show InboxCommunity, inboxGroup, inboxThread;

void main() {
  testWidgets(
    'retired pet leaves active rail while Todos keeps its conversation',
    (tester) async {
      final repo = InboxCommunity()
        ..groups = [inboxGroup('one', [])..['selector_active'] = true]
        ..members = [inboxThread('ana')];
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
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      final pet = find.byKey(const ValueKey('rescuer-pet-one'));
      expect(pet, findsOneWidget);
      await tester.tap(pet);
      await tester.pumpAndSettle();
      expect(repo.flatRequests.last.$2, 'one');
      repo.groups.first['selector_active'] = false;
      repo.changed();
      await tester.pumpAndSettle();
      expect(pet, findsNothing);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.byKey(const ValueKey('rescuer-thread-ana')), findsOneWidget);
      expect(repo.flatRequests.last.$2, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
