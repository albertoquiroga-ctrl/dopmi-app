import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';

import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';

class EditorTestPhone extends PhoneVerificationRepository {
  @override
  String? get verifiedPhone => null;
  @override
  Future<void> requestPhoneCode(String e164) async {}
  @override
  Future<void> resendPhoneCode(String e164) async {}
  @override
  Future<void> verifyPhoneCode(String e164, String code) async {}
}

FakeIdentityRepository editorTestIdentity() {
  final repository = FakeIdentityRepository()
    ..user = const Identity(
      'owner-one',
      'private@example.test',
      verified: true,
    );
  addTearDown(() => repository.changes.close());
  return repository;
}
