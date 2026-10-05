import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show PhotoDraftCommunity;
import 'fake_identity_repository.dart';
import 'publication_frame_test.dart' show startPublication, tapPublication;

void main() {
  testWidgets(
    'new personality choices cap at three without clearing legacy traits',
    (tester) async {
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/post');
      await tapPublication(tester, find.text('Continuar'));
      expect(
        find.byKey(const ValueKey('publication-personality-dormilon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('publication-personality-protector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('publication-personality-obediente')),
        findsOneWidget,
      );
      for (final key in ['alegre', 'nervioso', 'dormilon']) {
        await tapPublication(
          tester,
          find.byKey(ValueKey('publication-personality-$key')),
        );
      }
      final fourth = find.byKey(
        const ValueKey('publication-personality-protector'),
      );
      expect(tester.widget<OutlinedButton>(fourth).onPressed, isNull);
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['personality'], [
        'alegre',
        'nervioso',
        'dormilon',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'historical four traits survive save and can be deliberately removed',
    (tester) async {
      final repo = PhotoDraftCommunity();
      repo.post = Adoption({
        ...repo.post.data,
        'personality': ['calm', 'active', 'sociable', 'independent'],
      });
      await startPublication(tester, repo, '/my-adoptions/post');
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['personality'], [
        'calm',
        'active',
        'sociable',
        'independent',
      ]);
      await tapPublication(
        tester,
        find.byKey(const ValueKey('publication-personality-active')),
      );
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['personality'], [
        'calm',
        'sociable',
        'independent',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

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
