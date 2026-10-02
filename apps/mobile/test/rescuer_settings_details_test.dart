import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

void main() {
  for (final mismatch in [false, true]) {
    testWidgets(
      'settings private social owner validation and real editor refresh: $mismatch',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        await identity.setExperience('rescuer');
        final profile = FakeRescuerProfile()
          ..value['owner_id'] = mismatch ? 'other' : 'one'
          ..value['instagram_url'] = 'https://www.instagram.com/own-profile';
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            rescuerProfileRepositoryProvider.overrideWithValue(profile),
            routerInitialLocationProvider.overrideWithValue('/settings'),
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
        expect(find.byTooltip('Notificaciones'), findsNothing);
        if (mismatch) {
          expect(
            find.text('https://www.instagram.com/own-profile'),
            findsNothing,
          );
          profile.value['owner_id'] = 'one';
          await tester.ensureVisible(find.text('Volver a intentar'));
          await tester.tap(find.text('Volver a intentar'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text('https://www.instagram.com/own-profile'),
          findsOneWidget,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byTooltip('Editar Instagram')),
          alignment: .35,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Editar Instagram'));
        await tester.pumpAndSettle();
        expect(find.byType(RescuerPublicProfileEditScreen), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Instagram (https://)',
          ),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .any(
                (field) =>
                    field.controller?.text ==
                    'https://www.instagram.com/own-profile',
              ),
          isTrue,
        );
        profile.value['instagram_url'] =
            'https://www.instagram.com/updated-profile';
        await tester.tap(find.byTooltip('Regresar'));
        await tester.pumpAndSettle();
        expect(
          find.text('https://www.instagram.com/updated-profile'),
          findsOneWidget,
        );
        expect(
          find.text('https://www.instagram.com/own-profile'),
          findsNothing,
        );
        expect(profile.saves, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
