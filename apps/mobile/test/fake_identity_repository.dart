import 'dart:async';

import 'package:dopmi_mobile/features/identity/identity_repository.dart';

class FakeIdentityRepository implements IdentityRepository {
  final changes = StreamController<IdentityEvent>.broadcast(sync: true);
  Identity? user;
  Future<Identity?>? restoreResult;
  bool pending = false;
  bool failSave = false;
  int signupCount = 0, passwordUpdates = 0, loads = 0;
  String? signupIntent;
  Profile profile = const Profile(
    id: 'one',
    name: 'Ana',
    phone: '',
    city: '',
    mode: 'donor',
    intent: 'adopt',
    status: 'active',
    termsVersion: developmentTermsVersion,
  );
  void emit(IdentityEvent event) {
    user = event.identity;
    changes.add(event);
  }

  @override
  Identity? get current => user;
  @override
  Stream<IdentityEvent> get events => changes.stream;
  @override
  Future<Identity?> restore() async =>
      restoreResult != null ? await restoreResult : user;
  @override
  Future<bool> recoveryPending() async => pending;
  @override
  Future<void> rememberRecovery(bool value) async {
    pending = value;
  }

  @override
  Future<void> login(String email, String password) async {
    emit(IdentityEvent(Identity('one', email, verified: true)));
  }

  @override
  Future<void> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String intent,
  }) async {
    signupCount++;
    signupIntent = intent;
  }

  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> confirmCode(
    String email,
    String code, {
    required bool recovery,
  }) async {
    emit(
      IdentityEvent(Identity('one', email, verified: true), recovery: recovery),
    );
  }

  @override
  Future<void> requestRecovery(String email) async {}
  @override
  Future<void> updatePassword(String password) async {
    passwordUpdates++;
  }

  @override
  Future<void> logout() async {
    emit(const IdentityEvent(null, signedOut: true));
  }

  @override
  Future<void> oauth(String provider) async {}
  @override
  Future<Profile> loadProfile() async {
    loads++;
    return profile;
  }

  @override
  Future<Profile> saveProfile({
    required String name,
    required String phone,
    required String city,
    required String mode,
  }) async {
    if (failSave) throw StateError('network_unavailable');
    return profile = Profile(
      id: 'one',
      name: name,
      phone: phone,
      city: city,
      mode: mode,
      intent: profile.intent,
      status: profile.status,
      termsVersion: profile.termsVersion,
    );
  }

  @override
  Future<void> acceptTerms() async {}
}
