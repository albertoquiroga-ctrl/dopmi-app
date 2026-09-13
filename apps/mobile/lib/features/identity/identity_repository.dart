import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

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
  );
  final String id, name, phone, city, mode, intent, status;
  final String? termsVersion;
}

abstract class IdentityRepository {
  Identity? get current;
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
  Future<void> logout();
  Future<void> oauth(String provider);
  Future<Profile> loadProfile();
  Future<Profile> saveProfile({
    required String name,
    required String phone,
    required String city,
    required String mode,
  });
  Future<void> acceptTerms();
}

class SupabaseIdentityRepository implements IdentityRepository {
  SupabaseIdentityRepository(this.client, this.config, this.preferences);
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
        'terms_version': developmentTermsVersion,
        'terms_accepted': true,
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
  Future<void> logout() => client.auth.signOut(scope: SignOutScope.local);
  @override
  Future<void> oauth(String provider) async {
    if ((provider == 'google' && !config.googleEnabled) ||
        (provider == 'apple' && !config.appleEnabled)) {
      throw StateError('provider_not_configured');
    }
    final launched = await client.auth.signInWithOAuth(
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
  Future<Profile> saveProfile({
    required String name,
    required String phone,
    required String city,
    required String mode,
  }) async {
    final result = await client
        .from('profiles')
        .update({
          'display_name': name.trim(),
          'phone': phone.trim(),
          'city': city.trim(),
          'active_mode': mode,
        })
        .eq('id', client.auth.currentUser!.id)
        .select()
        .single();
    return Profile.fromJson(result);
  }

  @override
  Future<void> acceptTerms() async {
    await client.rpc('accept_current_terms');
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
    _ => 'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.',
  };
}
