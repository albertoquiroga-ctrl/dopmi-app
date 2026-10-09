import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:dopmi_mobile/features/profile/social_verification_screen.dart';
import 'package:dopmi_mobile/features/profile/social_verification_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'social_verification_test.dart' show SocialFixture;
import 'community_test.dart' show FakeCommunity;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;
import 'rescue_test.dart' show FakeRescue;

class FooterCommunity extends FakeCommunity {
  @override
  String? get userId => 'owner-one';
}

class FooterDashboard extends FakeRescue {
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'verification_status': 'not_started',
  };
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'owner profile opens real social verification at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'owner-one',
            'private@example.test',
            verified: true,
          )
          ..profile = const Profile(
            id: 'owner-one',
            name: 'Ana',
            phone: '',
            city: '',
            mode: 'rescuer',
            intent: 'rescue',
            status: 'active',
            termsVersion: currentTermsVersion,
            privacyVersion: currentPrivacyVersion,
            adultConfirmed: true,
          );
        addTearDown(identity.changes.close);
        final profile = FakeRescuerProfile();
        final social = SocialFixture()..owner = 'owner-one';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              socialVerificationRepositoryProvider.overrideWithValue(social),
              identityRepositoryProvider.overrideWithValue(identity),
              communityRepositoryProvider.overrideWithValue(FooterCommunity()),
              rescuerProfileRepositoryProvider.overrideWithValue(profile),
              rescueRepositoryProvider.overrideWithValue(FooterDashboard()),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RescuerProfileHero(identity.profile),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final entry = find.byKey(const ValueKey('owner-social-verification'));
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        expect(entry.hitTestable(), findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(SocialVerificationScreen), findsOneWidget);
        expect(
          social.calls.where((call) => call['operation'] == 'list'),
          hasLength(1),
        );
        expect(
          social.calls.where((call) => call['operation'] == 'start'),
          isEmpty,
        );
        expect(profile.saves, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
