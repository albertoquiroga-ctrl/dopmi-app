import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_metrics.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_social_dialog.dart';
import 'package:dopmi_mobile/features/profile/rescuer_social_section.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class Profile9cedRepository extends FakeRescuerProfile {
  Profile9cedRepository() {
    value = {
      ...value,
      'owner_id': 'one',
      'instagram_url': 'https://www.instagram.com/own_profile',
    };
  }
  @override
  String? get userId => 'one';
}

class Profile9cedDashboard extends FakeRescue {
  Profile9cedDashboard(this.status);
  final String status;
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'verification_status': status,
  };
}

Future<ProviderContainer> mount9cedProfile(
  WidgetTester tester,
  FakeIdentityRepository identity,
  Profile9cedRepository profile, {
  String status = 'approved',
}) async {
  await identity.setExperience('rescuer');
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(FakeCommunity()),
      rescueRepositoryProvider.overrideWithValue(Profile9cedDashboard(status)),
      rescuerProfileRepositoryProvider.overrideWithValue(profile),
      routerInitialLocationProvider.overrideWithValue('/profile'),
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

Future<void> reveal9ced(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .4);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profile owns moderated social editing; settings keeps Connect', (
    tester,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final profile = Profile9cedRepository();
    final container = await mount9cedProfile(tester, identity, profile);
    expect(find.byType(RescuerProfileMetrics), findsNothing);
    expect(find.byType(RescuerSocialSection), findsOneWidget);
    expect(find.text('Cuenta verificada'), findsOneWidget);
    expect(find.text('Verificado'), findsNothing);
    await reveal9ced(tester, find.byTooltip('Editar Instagram'));
    await tester.tap(find.byTooltip('Editar Instagram'));
    await tester.pumpAndSettle();
    expect(find.byType(RescuerSocialDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rescuer-social-input')),
      '@updated_profile',
    );
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(
      profile.value['instagram_url'],
      'https://www.instagram.com/updated_profile',
    );
    expect(profile.value['status'], 'draft');
    expect(profile.value['version'], 4);
    expect(profile.value['display_name'], 'Refugio Luna');
    expect(profile.saves, 1);
    expect(find.text('@updated_profile'), findsOneWidget);
    expect(find.textContaining('vinculada'), findsNothing);
    await reveal9ced(tester, find.text('Cuenta y privacidad'));
    await tester.tap(find.text('Cuenta y privacidad'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/settings');
    expect(find.byType(RescuerSocialSection), findsNothing);
    expect(find.text('Configurar pagos con Stripe'), findsOneWidget);
    expect(find.byKey(const ValueKey('rescuer-donor-switch')), findsNothing);
    expect(find.text('Cerrar sesión'), findsNothing);
    expect(find.text('Cuenta y privacidad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'adopter banner persists mode only after server success: $fail',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final container = await mount9cedProfile(
          tester,
          identity,
          Profile9cedRepository(),
        );
        identity.failSave = fail;
        final banner = find.byKey(const ValueKey('rescuer-adoptant-banner'));
        await reveal9ced(tester, banner);
        await tester.tap(banner);
        await tester.pumpAndSettle();
        expect(identity.profile.mode, fail ? 'rescuer' : 'donor');
        expect(identity.profile.id, 'one');
        expect(identity.profile.name, 'Ana');
        expect(
          container.read(routerProvider).state.uri.path,
          fail ? '/profile' : '/adoptions',
        );
        if (fail) {
          expect(banner, findsOneWidget);
          expect(find.byType(Notice), findsWidgets);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final status in ['not_started', 'submitted', 'changes_requested']) {
    testWidgets(
      'privacy and logout remain usable before verification: $status',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final profile = Profile9cedRepository();
        final container = await mount9cedProfile(
          tester,
          identity,
          profile,
          status: status,
        );
        expect(find.byType(RescuerSocialSection), findsNothing);
        for (final destination in [
          ('Sobre Nosotros', '/about'),
          ('Centro de ayuda', '/help'),
          ('Cuenta y privacidad', '/settings'),
        ]) {
          final link = find.text(destination.$1);
          await reveal9ced(tester, link);
          await tester.tap(link);
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, destination.$2);
          container.read(routerProvider).pop();
          await tester.pumpAndSettle();
        }
        await reveal9ced(tester, find.text('Cerrar sesión'));
        await tester.tap(find.text('Cerrar sesión'));
        await tester.pumpAndSettle();
        expect(identity.current, isNull);
        expect(find.byType(ProfileScreen), findsNothing);
        expect(profile.saves, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
