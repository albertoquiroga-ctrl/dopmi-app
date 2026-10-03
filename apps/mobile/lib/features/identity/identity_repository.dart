import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import 'native_identity.dart';

const currentTermsVersion = 'terms-2026-09-28';
const currentPrivacyVersion = 'privacy-2026-09-28';
// Kept for build-253 test fixtures and migration compatibility only.
const developmentTermsVersion = 'development-2026-09-13';

class Identity {
  const Identity(this.id, this.email, {required this.verified});
  final String id, email;
  final bool verified;
}

class IdentityEvent {
  const IdentityEvent(
    this.identity, {
    this.recovery = false,
    this.signedOut = false,
  });
  final Identity? identity;
  final bool recovery, signedOut;
}

class AccountNames {
  const AccountNames(this.firstName, this.lastName, {required this.saved});
  final String firstName, lastName;
  final bool saved;
  factory AccountNames.fromJson(Map<String, dynamic> json) => AccountNames(
    json['first_name'] as String,
    json['last_name'] as String,
    saved: json['name_parts_saved'] as bool,
  );
}

enum EmailChangeStatus { confirmed, pendingConfirmation }

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.mode,
    required this.intent,
    required this.status,
    required this.termsVersion,
    this.privacyVersion,
    this.adultConfirmed = false,
  });
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['display_name'] as String,
    phone: json['phone'] as String,
    city: json['city'] as String,
    mode: json['active_mode'] as String,
    intent: json['intent'] as String,
    status: json['account_status'] as String,
    termsVersion: json['terms_version'] as String?,
    privacyVersion: json['privacy_version'] as String?,
    adultConfirmed: json['adult_confirmed_at'] != null,
  );
  final String id, name, phone, city, mode, intent, status;
  final String? termsVersion;
  final String? privacyVersion;
  final bool adultConfirmed;
}

abstract class IdentityRepository {
  Identity? get current;
  Set<String> get linkedProviders => const {};
  Stream<IdentityEvent> get events;
  Future<Identity?> restore();
  Future<bool> recoveryPending();
  Future<void> rememberRecovery(bool pending);
  Future<void> login(String email, String password);
  Future<void> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String intent,
  });
  Future<void> resendConfirmation(String email);
  Future<void> confirmCode(String email, String code, {required bool recovery});
  Future<void> requestRecovery(String email);
  Future<void> updatePassword(String password);
  Future<EmailChangeStatus> changeEmail(String email);
  Future<void> logout();
  Future<void> oauth(String provider);
  Future<void> linkProvider(String provider);
  Future<Profile> loadProfile();
  Future<AccountNames> loadAccountNames();
  Future<Profile> saveAccountNames({
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
  });
  Future<Profile> setExperience(String mode);
  Future<Profile> saveProfile({
    required String name,
    required String phone,
    required String city,
  });
  Future<void> acceptTerms();
  Future<void> reauthenticate(String password) =>
      throw UnsupportedError('reauthentication_not_implemented');
  Future<void> reauthenticateWithProvider(String provider) =>
      throw UnsupportedError('provider_reauthentication_not_implemented');
  Future<Map<String, dynamic>> requestAccountDeletion(String requestKey) =>
      throw UnsupportedError('account_deletion_not_implemented');
}

class SupabaseIdentityRepository implements IdentityRepository {
  SupabaseIdentityRepository(
    this.client,
    this.config,
    this.preferences, {
    NativeIdentity? nativeIdentity,
  }) : nativeIdentity = nativeIdentity ?? PlatformNativeIdentity(config);
  final NativeIdentity nativeIdentity;
  bool _oauthBusy = false;
  final SupabaseClient client;
  final AppConfig config;
  final SharedPreferences preferences;
  String get recoveryKey => 'dopmi.${Uri.parse(config.url).host}.recovery';
  Identity? _identity(User? user) => user == null
      ? null
      : Identity(
          user.id,
          user.email ?? '',
          verified: user.emailConfirmedAt != null,
        );
  @override
  Identity? get current => _identity(client.auth.currentUser);
  @override
  Set<String> get linkedProviders =>
      client.auth.currentUser?.identities
          ?.map((identity) => identity.provider)
          .toSet() ??
      const {};
  @override
  Stream<IdentityEvent> get events => client.auth.onAuthStateChange.map(
    (event) => IdentityEvent(
      _identity(event.session?.user),
      recovery: event.event == AuthChangeEvent.passwordRecovery,
      signedOut: event.event == AuthChangeEvent.signedOut,
    ),
  );
  @override
  Future<Identity?> restore() async {
    if (client.auth.currentSession == null) return null;
    return _identity((await client.auth.getUser()).user);
  }

  @override
  Future<bool> recoveryPending() async =>
      preferences.getBool(recoveryKey) ?? false;
  @override
  Future<void> rememberRecovery(bool pending) async {
    await preferences.setBool(recoveryKey, pending);
  }

  @override
  Future<void> login(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String intent,
  }) async {
    await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: config.redirect,
      data: {
        'display_name': name.trim(),
        'phone': phone.trim(),
        'intent': intent,
        'terms_version': currentTermsVersion,
        'terms_accepted': true,
        'privacy_version': currentPrivacyVersion,
        'adult_confirmed': true,
      },
    );
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: config.redirect,
    );
  }

  @override
  Future<void> confirmCode(
    String email,
    String code, {
    required bool recovery,
  }) async {
    await client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: recovery ? OtpType.recovery : OtpType.signup,
    );
  }

  @override
  Future<void> requestRecovery(String email) => client.auth
      .resetPasswordForEmail(email.trim(), redirectTo: config.redirect);
  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<EmailChangeStatus> changeEmail(String email) async {
    final actor = current?.id;
    if (actor == null) throw StateError('profile_owner_changed');
    final target = email.trim();
    if (target.isEmpty ||
        target.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(target)) {
      throw const AuthException('Escribe un correo electrónico válido.');
    }
    if (current?.email.toLowerCase() == target.toLowerCase()) {
      return EmailChangeStatus.confirmed;
    }
    if (client.auth.currentUser?.newEmail?.toLowerCase() == target.toLowerCase()) {
      return EmailChangeStatus.pendingConfirmation;
    }
    final response = await client.auth.updateUser(
      UserAttributes(email: target),
      emailRedirectTo: config.redirect,
    );
    if (current?.id != actor || response.user?.id != actor) {
      throw StateError('profile_owner_changed');
    }
    if (response.user?.email?.toLowerCase() == target.toLowerCase()) {
      return EmailChangeStatus.confirmed;
    }
    if (response.user?.newEmail?.toLowerCase() == target.toLowerCase()) {
      return EmailChangeStatus.pendingConfirmation;
    }
    throw StateError('email_change_not_acknowledged');
  }

  @override
  Future<void> logout() => client.auth.signOut(scope: SignOutScope.local);
  @override
  Future<void> oauth(String provider) async {
    if (!['google', 'apple'].contains(provider) ||
        (provider == 'google' && !config.googleEnabled) ||
        (provider == 'apple' && !config.appleEnabled)) {
      throw StateError('provider_not_configured');
    }
    if (_oauthBusy) return;
    _oauthBusy = true;
    try {
      if (nativeIdentity.supports(provider)) {
        final credential = await nativeIdentity.authenticate(provider);
        if (credential == null) return;
        await client.auth.signInWithIdToken(
          provider: provider == 'apple'
              ? OAuthProvider.apple
              : OAuthProvider.google,
          idToken: credential.idToken,
          accessToken: credential.accessToken,
          nonce: credential.nonce,
        );
        if (provider == 'apple') await _registerAppleCredential(credential);
        return;
      }
      final launched = await client.auth.signInWithOAuth(
        provider == 'apple' ? OAuthProvider.apple : OAuthProvider.google,
        redirectTo: config.redirect,
      );
      if (!launched) throw StateError('browser_not_opened');
    } finally {
      _oauthBusy = false;
    }
  }

  Future<void> _registerAppleCredential(
    NativeIdentityCredential credential,
  ) async {
    final result = await client.functions.invoke(
      'apple-credentials',
      body: {'code': credential.authorizationCode, 'nonce': credential.nonce},
    );
    if (result.status >= 400) {
      throw const AuthException('apple_registration_incomplete');
    }
  }

  @override
  Future<void> linkProvider(String provider) async {
    if (!['google', 'apple'].contains(provider) ||
        (provider == 'google' && !config.googleEnabled) ||
        (provider == 'apple' && !config.appleEnabled)) {
      throw StateError('provider_not_configured');
    }
    if (nativeIdentity.supports(provider)) {
      final credential = await nativeIdentity.authenticate(provider);
      if (credential == null) return;
      await client.auth.linkIdentityWithIdToken(
        provider: provider == 'apple'
            ? OAuthProvider.apple
            : OAuthProvider.google,
        idToken: credential.idToken,
        accessToken: credential.accessToken,
        nonce: credential.nonce,
      );
      if (provider == 'apple') await _registerAppleCredential(credential);
      return;
    }
    final launched = await client.auth.linkIdentity(
      provider == 'apple' ? OAuthProvider.apple : OAuthProvider.google,
      redirectTo: config.redirect,
    );
    if (!launched) throw StateError('browser_not_opened');
  }

  @override
  Future<Profile> loadProfile() async => Profile.fromJson(
    await client
        .from('profiles')
        .select()
        .eq('id', client.auth.currentUser!.id)
        .single(),
  );
  @override
  Future<Profile> setExperience(String mode) async {
    if (!['donor', 'rescuer'].contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    final owner = client.auth.currentUser!.id;
    final result = await client
        .from('profiles')
        .update({'active_mode': mode})
        .eq('id', owner)
        .select()
        .single();
    if (client.auth.currentUser?.id != owner) {
      throw StateError('profile_owner_changed');
    }
    return Profile.fromJson(result);
  }

  @override
  Future<Profile> saveProfile({
    required String name,
    required String phone,
    required String city,
  }) async {
    final result = await client
        .from('profiles')
        .update({
          'display_name': name.trim(),
          'phone': phone.trim(),
          'city': city.trim(),
        })
        .eq('id', client.auth.currentUser!.id)
        .select()
        .single();
    return Profile.fromJson(result);
  }

  @override
  Future<AccountNames> loadAccountNames() async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('profile_owner_changed');
    final result = await client.rpc('dopmi_my_account_names');
    if (client.auth.currentUser?.id != owner) {
      throw StateError('profile_owner_changed');
    }
    return AccountNames.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<Profile> saveAccountNames({
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
  }) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('profile_owner_changed');
    final result = await client.rpc(
      'dopmi_save_account_names',
      params: {
        'payload': {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
          'city': city.trim(),
        },
      },
    );
    if (client.auth.currentUser?.id != owner) {
      throw StateError('profile_owner_changed');
    }
    final profile = Profile.fromJson(Map<String, dynamic>.from(result as Map));
    if (profile.id != owner) throw StateError('profile_owner_changed');
    return profile;
  }

  @override
  Future<void> acceptTerms() async {
    await client.rpc(
      'dopmi_accept_legal',
      params: {
        'accepted_terms': currentTermsVersion,
        'accepted_privacy': currentPrivacyVersion,
        'confirms_adult': true,
      },
    );
  }

  @override
  Future<void> reauthenticate(String password) async {
    final email = current?.email;
    if (email == null || email.isEmpty || password.isEmpty) {
      throw const AuthException('recent_sign_in_required');
    }
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> reauthenticateWithProvider(String provider) async {
    final owner = current?.id;
    if (owner == null || !linkedProviders.contains(provider)) {
      throw const AuthException('recent_sign_in_required');
    }
    final credential = await nativeIdentity.authenticate(provider);
    if (credential == null) {
      throw const AuthException('reauthentication_canceled');
    }
    await client.auth.signInWithIdToken(
      provider: provider == 'apple'
          ? OAuthProvider.apple
          : OAuthProvider.google,
      idToken: credential.idToken,
      accessToken: credential.accessToken,
      nonce: credential.nonce,
    );
    if (current?.id != owner) {
      await client.auth.signOut(scope: SignOutScope.local);
      throw const AuthException('identity_mismatch');
    }
    if (provider == 'apple') await _registerAppleCredential(credential);
  }

  @override
  Future<Map<String, dynamic>> requestAccountDeletion(String requestKey) async {
    final result = await client.functions.invoke(
      'account-deletion',
      body: {'request_key': requestKey, 'confirmation': 'ELIMINAR'},
    );
    if (result.status >= 400) {
      final code = result.data is Map ? result.data['error']?.toString() : null;
      throw AuthException(code ?? 'deletion_unavailable');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }
}

String identityError(Object error) {
  final code = error is AuthException
      ? error.code
      : error is PostgrestException
      ? error.code
      : null;
  return switch (code) {
    'invalid_credentials' => 'Revisa tu correo y contraseña.',
    'email_not_confirmed' => 'Primero confirma tu correo. Puedes solicitar otro enlace desde la pantalla de confirmación.',
    'otp_expired' || 'flow_state_expired' || 'flow_state_not_found' => 'El enlace o código venció. Solicita uno nuevo y ábrelo en este dispositivo.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Espera unos minutos antes de solicitar otro correo.',
    'email_address_invalid' ||
    'validation_failed' => 'Revisa que tu correo sea válido.',
    'email_address_not_authorized' => 'El envío de correo de este entorno todavía necesita configuración. Contacta al responsable de Dopmi.',
    'weak_password' =>
      'Usa al menos 10 caracteres, una mayúscula, una minúscula y un número.',
    'same_password' => 'Elige una contraseña diferente a la anterior.',
    '42501' => 'Tu cuenta no tiene permiso para realizar esta acción.',
    'recent_sign_in_required' =>
      'Por seguridad, vuelve a iniciar sesión antes de eliminar tu cuenta.',
    'confirmation_required' => 'Escribe ELIMINAR para confirmar.',
    'deletion_unavailable' => 'No pudimos completar la eliminación. Tu acceso quedó bloqueado de forma segura; soporte puede revisar el proceso.',
    'apple_registration_incomplete' => 'Apple autorizó el acceso, pero no pudimos preparar su revocación segura. Inténtalo otra vez.',
    'reauthentication_canceled' => 'Cancelaste la confirmación de identidad.',
    'identity_mismatch' => 'El proveedor devolvió otra cuenta. Inicia sesión nuevamente con la cuenta vinculada.',
    _ => 'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.',
  };
}
