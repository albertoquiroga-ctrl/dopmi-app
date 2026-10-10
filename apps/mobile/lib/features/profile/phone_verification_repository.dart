import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

final phoneVerificationRepositoryProvider =
    Provider<PhoneVerificationRepository>((ref) {
      final repository = SupabasePhoneVerificationRepository(
        Supabase.instance.client,
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

/// Phone UI only: never render provider messages, phone numbers or OTPs.
String phoneVerificationError(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'phone_exists':
        return 'Este número ya está vinculado a otra cuenta. Usa otro número o entra a la cuenta donde lo vinculaste.';
      case 'otp_expired':
        return 'El código venció o es incorrecto. Solicita uno nuevo y vuelve a intentar.';
      case 'over_sms_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Hubo demasiados intentos. Espera unos minutos y vuelve a intentar.';
    }
  }
  if (error is StateError) {
    const safeMessages = {
      'Inicia sesión para verificar tu teléfono.',
      'La sesión cambió. Vuelve a solicitar el código.',
      'La solicitud cambió. Usa el código más reciente.',
      'Solicita un código para este teléfono.',
      'La confirmación del teléfono todavía está pendiente.',
    };
    if (safeMessages.contains(error.message)) return error.message;
  }
  if (error is ArgumentError) {
    return 'Revisa el número con código de país y el código recibido por SMS.';
  }
  return 'No pudimos verificar el teléfono. Vuelve a intentar.';
}

abstract class PhoneVerificationRepository {
  String? get verifiedPhone;
  Future<void> requestPhoneCode(String e164);
  Future<void> verifyPhoneCode(String e164, String code);
  Future<void> resendPhoneCode(String e164);
}

/// Stateless Auth requests avoid SDK session writes and web BroadcastChannel.
class _PhoneAuthTransport {
  _PhoneAuthTransport(this.client, this.url, this.headers);
  final http.Client client;
  final String url;
  final Map<String, String> headers;

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final req = http.Request(method, Uri.parse('$url/$path'));
    req.headers.addAll({...headers, 'Content-Type': 'application/json'});
    if (body != null) {
      req.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await client.send(req));
    Map<String, dynamic> value;
    try {
      value = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const AuthException(
        'No pudimos confirmar la respuesta del servicio SMS.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawCode = value['error_code'] ?? value['code'];
      final code =
          rawCode is String && RegExp(r'^[a-z0-9_]{1,80}$').hasMatch(rawCode)
          ? rawCode
          : null;
      throw AuthException(
        'No pudimos verificar el teléfono. Vuelve a intentar.',
        statusCode: response.statusCode.toString(),
        code: code,
      );
    }
    return value;
  }

  Future<UserResponse> updateUser(UserAttributes attributes) async =>
      UserResponse.fromJson(await request('PUT', 'user', attributes.toJson()));

  Future<void> resend({required OtpType type, required String phone}) async {
    await request('POST', 'resend', {'type': 'phone_change', 'phone': phone});
  }

  Future<void> verifyOTP({
    required OtpType type,
    required String phone,
    required String token,
  }) async {
    await request('POST', 'verify', {
      'type': 'phone_change',
      'phone': phone,
      'token': token,
    });
  }

  Future<UserResponse> getUser() async =>
      UserResponse.fromJson(await request('GET', 'user'));
}

/// Changes the phone on the signed-in identity; never creates a second user.
class SupabasePhoneVerificationRepository
    implements PhoneVerificationRepository {
  SupabasePhoneVerificationRepository(
    this.client, {
    this.httpClient,
    String? authUrl,
  }) : _authUrl = authUrl ?? '${AppConfig.environment().url}/auth/v1' {
    _sessionToken = client.auth.currentSession?.accessToken;
    _subscription = client.auth.onAuthStateChange.listen(
      (state) {
        final token = state.session?.accessToken;
        if (token != _sessionToken ||
            state.event == AuthChangeEvent.signedOut) {
          _epoch++;
          _sessionToken = token;
          _pendingOwner = _pendingPhone = _confirmedOwner = _confirmedPhone =
              null;
        }
      },
      onError: (Object _) {
        _epoch++;
        _pendingOwner = _pendingPhone = _confirmedOwner = _confirmedPhone =
            null;
      },
    );
  }
  final SupabaseClient client;
  final http.Client? httpClient;
  final String _authUrl;
  late final StreamSubscription<AuthState> _subscription;
  int _epoch = 0, _requestGeneration = 0;
  String? _sessionToken, _confirmedOwner, _confirmedPhone;

  void dispose() {
    _subscription.cancel();
  }

  Future<T> _isolated<T>(
    Future<T> Function(_PhoneAuthTransport auth) action,
  ) async {
    final session = client.auth.currentSession;
    if (session == null) {
      throw StateError('Inicia sesión para verificar tu teléfono.');
    }
    final owner = session.user.id;
    final token = session.accessToken;
    final epoch = _epoch;
    final transport = httpClient ?? http.Client();
    final auth = _PhoneAuthTransport(transport, _authUrl, {
      ...client.auth.headers,
      'Authorization': 'Bearer $token',
    });
    try {
      final result = await action(auth);
      if (client.auth.currentUser?.id != owner ||
          client.auth.currentSession?.accessToken != token ||
          _epoch != epoch) {
        if (_pendingOwner == owner) {
          _pendingOwner = _pendingPhone = null;
        }
        if (_confirmedOwner == owner) {
          _confirmedOwner = _confirmedPhone = null;
        }
        throw StateError('La sesión cambió. Vuelve a solicitar el código.');
      }
      return result;
    } finally {
      if (httpClient == null) {
        transport.close();
      }
    }
  }

  String? _pendingOwner, _pendingPhone;

  @override
  String? get verifiedPhone {
    final user = client.auth.currentUser;
    if (_confirmedOwner == user?.id &&
        client.auth.currentSession?.accessToken == _sessionToken) {
      return _confirmedPhone;
    }
    final phone = user?.phone;
    return user?.phoneConfirmedAt != null && phone != null && phone.isNotEmpty
        ? '+${phone.replaceFirst(RegExp(r'^\+'), '')}'
        : null;
  }

  String _actor() {
    final actor = client.auth.currentUser?.id;
    if (actor == null) {
      throw StateError('Inicia sesión para verificar tu teléfono.');
    }
    return actor;
  }

  void _sameActor(String actor) {
    if (client.auth.currentUser?.id != actor) {
      if (_pendingOwner == actor) {
        _pendingOwner = _pendingPhone = null;
      }
      throw StateError('La sesión cambió. Vuelve a solicitar el código.');
    }
  }

  void _validatePhone(String phone) {
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      throw ArgumentError(
        'Usa el teléfono con código de país, por ejemplo +52.',
      );
    }
  }

  String _pendingActor(String phone) {
    _validatePhone(phone);
    final actor = _actor();
    if (_pendingOwner != actor || _pendingPhone != phone) {
      throw StateError('Solicita un código para este teléfono.');
    }
    return actor;
  }

  @override
  Future<void> requestPhoneCode(String e164) async {
    _validatePhone(e164);
    final actor = _actor();
    _pendingOwner = _pendingPhone = null;
    final generation = ++_requestGeneration;
    final response = await _isolated(
      (auth) => auth.updateUser(UserAttributes(phone: e164)),
    );
    if (generation != _requestGeneration) {
      throw StateError('La solicitud cambió. Usa el código más reciente.');
    }
    _sameActor(actor);
    if (response.user?.id != actor) {
      throw StateError('No pudimos confirmar la identidad de esta solicitud.');
    }
    _pendingOwner = actor;
    _pendingPhone = e164;
  }

  @override
  Future<void> resendPhoneCode(String e164) async {
    final actor = _pendingActor(e164);
    final generation = _requestGeneration;
    await _isolated(
      (auth) => auth.resend(type: OtpType.phoneChange, phone: e164),
    );
    _sameActor(actor);
    if (generation != _requestGeneration) {
      throw StateError('La solicitud cambió. Usa el código más reciente.');
    }
  }

  @override
  Future<void> verifyPhoneCode(String e164, String code) async {
    final actor = _pendingActor(e164);
    final generation = _requestGeneration;
    if (!RegExp(r'^[0-9]{4,10}$').hasMatch(code)) {
      throw ArgumentError('Ingresa el código recibido por SMS.');
    }
    final user = await _isolated((auth) async {
      await auth.verifyOTP(type: OtpType.phoneChange, phone: e164, token: code);
      _sameActor(actor);
      return (await auth.getUser()).user;
    });
    _sameActor(actor);
    if (generation != _requestGeneration) {
      throw StateError('La solicitud cambió. Usa el código más reciente.');
    }
    if (user?.id != actor ||
        user?.phone?.replaceFirst(RegExp(r'^\+'), '') != e164.substring(1) ||
        user?.phoneConfirmedAt == null) {
      // Secure phone change can require a second confirmation; do not mark it done.
      throw StateError('La confirmación del teléfono todavía está pendiente.');
    }
    _confirmedOwner = actor;
    _confirmedPhone = e164;
    _pendingOwner = _pendingPhone = null;
  }
}
