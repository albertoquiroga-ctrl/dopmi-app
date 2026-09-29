import 'dart:typed_data';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'community_test.dart' show FakeCommunity;

class FakeRescuerProfile implements RescuerProfileRepository {
  Json value = {
    'id': 'profile-one',
    'display_name': 'Refugio Luna',
    'bio': 'Rescate responsable.',
    'city': 'Monterrey',
    'region': 'Nuevo León',
    'instagram_url': '',
    'facebook_url': '',
    'avatar_path': '',
    'status': 'changes_requested',
    'review_feedback': 'Aclara la ciudad.',
    'version': 3,
  };
  int saves = 0;
  @override
  String? get userId => 'owner-one';
  @override
  Future<Json?> load() async => value;
  @override
  Future<Json> save(Json payload, {int? version}) async {
    saves++;
    value = {...value, ...payload, 'status': 'draft', 'version': version! + 1};
    return value;
  }

  @override
  Future<Json> transition(int version, String action) async {
    value = {
      ...value,
      'status': action == 'submit' ? 'submitted' : 'draft',
      'version': version + 1,
      'review_feedback': '',
    };
    return value;
  }

  @override
  Future<String> avatarUrl(String path) async => 'https://example.test/avatar';
  @override
  Future<String> uploadAvatar(Uint8List bytes) async => 'owner/avatar.jpg';
}

void main() {
  testWidgets('corrige, guarda y envía el perfil público sin datos privados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRescuerProfile();
    final identity = FakeIdentityRepository()
      ..user = const Identity('owner-one', 'ana@example.test', verified: true)
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
    addTearDown(() async => identity.changes.close());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescuerProfileRepositoryProvider.overrideWithValue(repo),
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          routerInitialLocationProvider.overrideWithValue(
            '/rescuer/profile/edit',
          ),
        ],
        child: const DopmiApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aclara la ciudad.'), findsOneWidget);
    expect(
      find.textContaining('domicilio, teléfono ni correo'),
      findsOneWidget,
    );
    expect(find.text('Teléfono'), findsNothing);
    expect(find.text('Correo'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, 'Ciudad'),
      'San Pedro Garza García',
    );
    await tester.tap(find.text('Enviar a revisión'));
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.value['city'], 'San Pedro Garza García');
    expect(repo.value['status'], 'submitted');
    expect(find.textContaining('Estado: En revisión'), findsOneWidget);
    expect(find.text('Retirar de revisión'), findsOneWidget);
  });
}
