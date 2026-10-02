import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show PhotoDraftCommunity;
import 'fake_identity_repository.dart';

void main() {
  testWidgets(
    'publication preserves old traits and saves selected new traits',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final repository = PhotoDraftCommunity();
      repository.post = Adoption({
        ...repository.post.data,
        'status': 'draft',
        'personality': ['affectionate'],
      });
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(repository),
          routerInitialLocationProvider.overrideWithValue('/my-adoptions/post'),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Continuar')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(repository.savedPayload?['personality'], ['affectionate']);
      await Scrollable.ensureVisible(
        tester.element(find.text('Alegre')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alegre'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Continuar')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(repository.savedPayload?['personality'], [
        'affectionate',
        'alegre',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
