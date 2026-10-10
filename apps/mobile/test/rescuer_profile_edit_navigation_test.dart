import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';

import 'profile_test_identity.dart';

import 'dart:typed_data';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class NavigationProfile extends FakeRescuerProfile {
  int transitions = 0, uploads = 0;

  @override
  Future<Json> transition(int version, String action) async {
    transitions++;
    return super.transition(version, action);
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    uploads++;
    return super.uploadAvatar(bytes);
  }
}

void main() {
  Future<(GoRouter, NavigationProfile)> open(
    WidgetTester tester,
    String origin,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity(
        'owner-one',
        'fixture@example.test',
        verified: true,
      )
      ..profile = const Profile(
        id: 'owner-one',
        name: 'Ana',
        phone: '',
        city: 'Monterrey',
        mode: 'rescuer',
        intent: 'rescue',
        status: 'active',
        termsVersion: currentTermsVersion,
        privacyVersion: currentPrivacyVersion,
        adultConfirmed: true,
      );
    final repository = NavigationProfile()..value['owner_id'] = 'owner-one';
    final container = ProviderContainer(
      overrides: [
        phoneVerificationRepositoryProvider.overrideWithValue(
          EditorTestPhone(),
        ),
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        rescuerProfileRepositoryProvider.overrideWithValue(repository),
        routerInitialLocationProvider.overrideWithValue(origin),
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
    final router = container.read(routerProvider);
    if (origin == '/profile') {
      final edit = find.byKey(const ValueKey('rescuer-profile-edit'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
    } else if (origin == '/settings/account') {
      await tester.tap(find.text('Editar perfil público'));
      await tester.pumpAndSettle();
    }
    expect(
      GoRouterState.of(
        tester.element(find.byType(RescuerPublicProfileEditScreen)),
      ).uri.path,
      '/rescuer/profile/edit',
    );
    expect(find.byType(RescuerPublicProfileEditScreen), findsOneWidget);
    expect(router.canPop(), origin != '/rescuer/profile/edit');
    return (router, repository);
  }

  for (final origin in [
    '/rescuer/profile/edit',
    '/profile',
    '/settings/account',
  ]) {
    for (final action in ['Cancelar', 'Volver', 'Sistema']) {
      testWidgets('public editor $action returns from $origin without writes', (
        tester,
      ) async {
        final (router, repository) = await open(tester, origin);
        final name = find.byKey(const ValueKey('public-profile-Nombre'));
        await tester.enterText(name, 'Cambio sin guardar');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (action == 'Cancelar') {
          final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
          await tester.scrollUntilVisible(
            cancel,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(RescuerPublicProfileEditScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(cancel);
        } else if (action == 'Volver') {
          await tester.tap(find.byTooltip('Volver'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        final destination = origin == '/settings/account'
            ? '/settings/account'
            : '/profile';
        expect(router.routeInformationProvider.value.uri.path, destination);
        expect(find.byType(RescuerPublicProfileEditScreen), findsNothing);
        expect(
          destination == '/profile'
              ? find.byType(ProfileScreen)
              : find.byType(RescuerAccountOptionsScreen),
          findsOneWidget,
        );
        expect(repository.saves, 0);
        expect(repository.transitions, 0);
        expect(repository.uploads, 0);
        expect(repository.value['display_name'], 'Refugio Luna');
        router.push('/rescuer/profile/edit');
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(name).controller!.text, 'Refugio Luna');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
