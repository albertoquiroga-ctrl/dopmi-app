import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/experience_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'dedicated experience change preserves personal data; failure=$fail',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity('one', 'ana@example.test', verified: true)
          ..failSave = fail;
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            routerInitialLocationProvider.overrideWithValue('/profile'),
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
        expect(find.byType(TextFormField), findsNothing);
        final target = find.byType(SwitchListTile);
        await tester.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(identity.profile.name, 'Ana');
        expect(identity.profile.phone, '');
        expect(identity.profile.mode, fail ? 'donor' : 'rescuer');
        expect(
          container.read(experienceProvider).value,
          fail ? AccountExperience.donor : AccountExperience.rescuer,
        );
        expect(
          container.read(routerProvider).state.uri.path,
          fail ? '/profile' : '/rescuer',
        );
        if (fail) {
          expect(
            find.text(
              'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.',
            ),
            findsOneWidget,
          );
        }
      },
    );
  }
  test(
    'editing personal data cannot reset a newer experience preference',
    () async {
      final repo = FakeIdentityRepository();
      await repo.setExperience('rescuer');
      await repo.saveProfile(
        name: 'Ana actualizada',
        phone: '',
        city: 'Monterrey',
      );
      expect(repo.profile.mode, 'rescuer');
    },
  );
}
