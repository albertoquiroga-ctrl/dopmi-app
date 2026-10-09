import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_media_grid.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_metrics.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_preview.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'rescuer_profile_test.dart' show FakeRescuerProfile;
import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue;

class FakePhoneDde extends PhoneVerificationRepository {
  @override
  String? verifiedPhone;
  final calls = <String>[];
  @override
  Future<void> requestPhoneCode(String e164) async =>
      calls.add('request:$e164');
  @override
  Future<void> resendPhoneCode(String e164) async => calls.add('resend:$e164');
  @override
  Future<void> verifyPhoneCode(String e164, String code) async {
    calls.add('verify:$e164:$code');
    verifiedPhone = e164;
  }
}

class RevocationProfile extends FakeRescuerProfile {
  final actions = <String>[];
  @override
  Future<Json> transition(int version, String action) async {
    actions.add(action);
    value = {...value, 'version': version + 1, 'contact_consent': false};
    return value;
  }
}

void main() {
  testWidgets(
    'owner about shows own private contacts without writing them into the public draft',
    (tester) async {
      final profile = FakeRescuerProfile()
        ..value = {
          'owner_id': 'owner-one',
          'display_name': 'Refugio',
          'status': 'draft',
          'version': 1,
          'public_email': '',
          'public_phone': '',
          'contact_consent': false,
        };
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
      addTearDown(() => identity.changes.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            rescuerProfileRepositoryProvider.overrideWithValue(profile),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RescuerProfileHero(
                  identity.profile,
                  contactEmail: 'private@example.test',
                  contactPhone: '+525500000099',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private@example.test'), findsOneWidget);
      expect(find.text('+525500000099'), findsOneWidget);
      expect(find.text('Por completar'), findsNWidgets(3));
      expect(profile.value['public_email'], isEmpty);
      expect(profile.value['public_phone'], isEmpty);
      expect(find.text('Redes sociales'), findsNothing);
      expect(profile.saves, 0);
    },
  );
  testWidgets(
    'preview removes private draft permanently after account change and hides website without consent',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('owner-one', 'a@example.test', verified: true);
      addTearDown(() => identity.changes.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescuerProfileRepositoryProvider.overrideWithValue(
              FakeRescuerProfile(),
            ),
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const MaterialApp(
            home: RescuerProfilePreview(
              ownerId: 'owner-one',
              payload: {
                'display_name': 'Private draft A',
                'bio': 'Private biography A',
                'contact_consent': false,
                'website_url': 'https://private.example.test',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private draft A'), findsOneWidget);
      expect(find.byTooltip('Web: https://private.example.test'), findsNothing);
      identity.emit(
        const IdentityEvent(
          Identity('owner-two', 'b@example.test', verified: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private draft A'), findsNothing);
      expect(find.text('Private biography A'), findsNothing);
      identity.emit(
        const IdentityEvent(
          Identity('owner-one', 'a@example.test', verified: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private draft A'), findsNothing);
    },
  );

  testWidgets(
    'submitted contacts can be revoked without saving or withdrawing the public review',
    (tester) async {
      final repo = RevocationProfile()
        ..value = {
          'display_name': 'Refugio',
          'status': 'submitted',
          'contact_consent': true,
          'version': 4,
          'approved_snapshot': {'display_name': 'Refugio'},
        };
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'owner-one',
          'identity@example.test',
          verified: true,
        );
      addTearDown(() => identity.changes.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescuerProfileRepositoryProvider.overrideWithValue(repo),
            phoneVerificationRepositoryProvider.overrideWithValue(
              FakePhoneDde(),
            ),
            identityRepositoryProvider.overrideWithValue(identity),
          ],
          child: const MaterialApp(home: RescuerPublicProfileEditScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final checkbox = find.byType(CheckboxListTile);
      await tester.scrollUntilVisible(
        checkbox,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(repo.actions, ['revoke_contacts']);
      expect(repo.saves, 0);
      expect(repo.value['status'], 'submitted');
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      expect(tester.widget<CheckboxListTile>(checkbox).onChanged, isNull);
    },
  );

  testWidgets(
    'SMS confirmation stays bound to requested phone and never copies private phone into public contacts',
    (tester) async {
      final repo = FakeRescuerProfile();
      final phone = FakePhoneDde();
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'owner-one',
          'identity@example.test',
          verified: true,
        );
      addTearDown(() => identity.changes.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescuerProfileRepositoryProvider.overrideWithValue(repo),
            phoneVerificationRepositoryProvider.overrideWithValue(phone),
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const MaterialApp(home: RescuerPublicProfileEditScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final number = find.byKey(const ValueKey('profile-sms-phone'));
      await tester.ensureVisible(number);
      await tester.enterText(number, '+525512345678');
      await tester.ensureVisible(find.text('Vincular'));
      await tester.tap(find.text('Vincular'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(number);
      await tester.enterText(number, '+525587654321');
      final code = find.byKey(const ValueKey('profile-sms-code'));
      await tester.ensureVisible(code);
      await tester.enterText(code, '123456');
      await tester.ensureVisible(find.text('Confirmar código'));
      await tester.tap(find.text('Confirmar código'));
      await tester.pumpAndSettle();
      expect(phone.calls, [
        'request:+525512345678',
        'verify:+525512345678:123456',
      ]);
      expect(find.text('Vinculado: +525512345678'), findsOneWidget);
      final publicPhone = find.byKey(
        const ValueKey('public-profile-Teléfono público'),
      );
      await tester.ensureVisible(publicPhone);
      expect(tester.widget<TextField>(publicPhone).controller!.text, isEmpty);
      expect(repo.saves, 0);
    },
  );

  testWidgets(
    'draft preview preserves unsaved contact consent without publishing',
    (tester) async {
      final repo = FakeRescuerProfile();
      final phone = FakePhoneDde();
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'owner-one',
          'identity@example.test',
          verified: true,
        );
      addTearDown(() => identity.changes.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescuerProfileRepositoryProvider.overrideWithValue(repo),
            phoneVerificationRepositoryProvider.overrideWithValue(phone),
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const MaterialApp(home: RescuerPublicProfileEditScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final consent = find.byType(CheckboxListTile);
      await tester.scrollUntilVisible(
        consent,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<CheckboxListTile>(consent).value, isFalse);
      final contact = find.byKey(
        const ValueKey('public-profile-Correo público'),
      );
      await tester.scrollUntilVisible(
        contact,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(contact, 'public@example.test');
      await tester.scrollUntilVisible(
        consent,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(consent);
      final preview = find.text('Ver vista previa >');
      await tester.scrollUntilVisible(
        preview,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.byType(RescuerProfilePreview), findsOneWidget);
      expect(find.byTooltip('Correo: public@example.test'), findsOneWidget);
      expect(find.text('Resumen'), findsOneWidget);
      expect(find.text('Adopción'), findsOneWidget);
      expect(find.text('Apoyo'), findsOneWidget);
      expect(repo.saves, 0);
      expect(phone.calls, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        contact,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextField>(contact).controller!.text,
        'public@example.test',
      );
    },
  );

  testWidgets(
    'public media filters intersect species sex size and personality',
    (tester) async {
      Adoption pet(
        String id,
        String species,
        String sex,
        List<String> personality,
      ) => Adoption({
        'id': id,
        'pet_name': id,
        'species': species,
        'sex': sex,
        'size': 'small',
        'personality': personality,
        'photos': <String>[],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicProfileAdoptionGrid(
              adoptions: [
                pet('Luna', 'dog', 'female', ['playful']),
                pet('Milo', 'cat', 'female', ['playful']),
                pet('Rocky', 'dog', 'male', ['playful']),
                pet('Sol', 'dog', 'female', ['calm']),
              ],
              species: 'dog',
              filters: {
                'sex': 'female',
                'size': 'small',
                'personality': ['playful'],
              },
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('public-adoption-Luna')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('public-adoption-Milo')), findsNothing);
      expect(find.byKey(const ValueKey('public-adoption-Rocky')), findsNothing);
      expect(find.byKey(const ValueKey('public-adoption-Sol')), findsNothing);
    },
  );

  testWidgets(
    'public summary shows four real counts and unknowns instead of invented data',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PublicProfileMetrics(
              name: 'Refugio',
              metrics: {
                'active_adoptions': 7,
                'adopted_count': 3,
                'active_donation_cases': 2,
              },
            ),
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    },
  );
}
