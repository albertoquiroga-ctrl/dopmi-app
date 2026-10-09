import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> user(
  String id, {
  String phone = '',
  bool confirmed = false,
}) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'qa@example.test',
  'phone': phone,
  'created_at': '2026-10-08T00:00:00Z',
  if (confirmed) 'phone_confirmed_at': '2026-10-08T01:00:00Z',
  'app_metadata': {},
  'user_metadata': {},
};

Future<void> restore(SupabaseClient client, String id) => client.auth
    .recoverSession(
      jsonEncode({
        'access_token': 'token-$id',
        'refresh_token': 'refresh-$id',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'user': user(id),
      }),
    )
    .then((_) {});

void main() {
  const actor = 'dd010000-0000-4000-8000-000000000010';
  const other = 'dd010000-0000-4000-8000-000000000011';
  const phone = '+525512345678';

  for (final entry in {
    'phone_exists': 'Este número ya está vinculado a otra cuenta. Usa otro número o entra a la cuenta donde lo vinculaste.',
    'otp_expired': 'El código venció o es incorrecto. Solicita uno nuevo y vuelve a intentar.',
    'over_sms_send_rate_limit':
        'Hubo demasiados intentos. Espera unos minutos y vuelve a intentar.',
    'over_request_rate_limit':
        'Hubo demasiados intentos. Espera unos minutos y vuelve a intentar.',
  }.entries) {
    test(
      'SMS transport preserves safe code ${entry.key} for phone UI',
      () async {
        final transport = MockClient(
          (_) async => http.Response(
            jsonEncode({
              (entry.key == 'otp_expired' ? 'error_code' : 'code'): entry.key,
              'msg': '<html>private-provider-message phone OTP metadata</html>',
            }),
            entry.key.contains('rate_limit') ? 429 : 422,
          ),
        );
        final client = SupabaseClient(
          'https://qa.example.test',
          'qa-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: transport,
        );
        addTearDown(client.dispose);
        await restore(client, actor);
        final repo = SupabasePhoneVerificationRepository(
          client,
          authUrl: 'https://qa.example.test/auth/v1',
          httpClient: transport,
        );
        addTearDown(repo.dispose);
        Object? failure;
        try {
          await repo.requestPhoneCode(phone);
        } catch (error) {
          failure = error;
        }
        expect(failure, isA<AuthException>());
        expect(phoneVerificationError(failure!), entry.value);
        expect(
          (failure as AuthException).message,
          isNot(contains('private-provider')),
        );
        expect(repo.verifiedPhone, isNull);
        expect(client.auth.currentUser?.id, actor);
      },
    );
  }
  test(
    'phone errors never display unrecognized provider or arbitrary local text',
    () {
      for (final failure in <Object>[
        const AuthException('private-provider-message', code: 'unknown_code'),
        StateError('private-provider-message'),
        Exception('private-provider-message'),
      ]) {
        expect(
          phoneVerificationError(failure),
          'No pudimos verificar el teléfono. Vuelve a intentar.',
        );
      }
      expect(
        phoneVerificationError(
          StateError('La sesión cambió. Vuelve a solicitar el código.'),
        ),
        'La sesión cambió. Vuelve a solicitar el código.',
      );
    },
  );

  test('phone change/resend/verify retains UUID and confirms via authoritative getUser', () async {
    final requests = <http.Request>[];
    final transport = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/resend')) {
        return http.Response('{}', 200);
      }
      if (request.url.path.endsWith('/verify')) {
        return http.Response(jsonEncode({'user': user(actor)}), 200);
      }
      return http.Response(
        jsonEncode(
          user(
            actor,
            phone: request.method == 'GET' ? phone.substring(1) : '',
            confirmed: request.method == 'GET',
          ),
        ),
        200,
      );
    });
    final client = SupabaseClient(
      'https://qa.example.test',
      'qa-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: transport,
    );
    addTearDown(client.dispose);
    await restore(client, actor);
    final repo = SupabasePhoneVerificationRepository(
      client,
      authUrl: 'https://qa.example.test/auth/v1',
      httpClient: transport,
    );
    addTearDown(repo.dispose);
    await repo.requestPhoneCode(phone);
    await repo.resendPhoneCode(phone);
    await repo.verifyPhoneCode(phone, '123456');
    expect(client.auth.currentUser?.id, actor);
    expect(repo.verifiedPhone, phone);
    expect(requests.map((r) => r.method), ['PUT', 'POST', 'POST', 'GET']);
    expect(jsonDecode(requests[0].body)['phone'], phone);
    expect(jsonDecode(requests[1].body)['type'], 'phone_change');
    expect(jsonDecode(requests[2].body)['type'], 'phone_change');
    await expectLater(repo.resendPhoneCode(phone), throwsStateError);
    await restore(client, other);
    expect(repo.verifiedPhone, isNull);
  });

  test(
    'secure intermediate confirmation is pending and can continue',
    () async {
      var confirmed = false;
      final transport = MockClient((request) async {
        final value = user(
          actor,
          phone: confirmed ? phone.substring(1) : '',
          confirmed: confirmed,
        );
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/verify') ? {'user': value} : value,
          ),
          200,
        );
      });
      final client = SupabaseClient(
        'https://qa.example.test',
        'qa-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: transport,
      );
      addTearDown(client.dispose);
      await restore(client, actor);
      final repo = SupabasePhoneVerificationRepository(
        client,
        authUrl: 'https://qa.example.test/auth/v1',
        httpClient: transport,
      );
      addTearDown(repo.dispose);
      await repo.requestPhoneCode(phone);
      await expectLater(
        repo.verifyPhoneCode(phone, '123456'),
        throwsStateError,
      );
      confirmed = true;
      await repo.verifyPhoneCode(phone, '654321');
    },
  );

  test('invalid format and changing account before verify send no additional request', () async {
    var calls = 0;
    final transport = MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(user(actor)), 200);
    });
    final client = SupabaseClient(
      'https://qa.example.test',
      'qa-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: transport,
    );
    addTearDown(client.dispose);
    await restore(client, actor);
    final repo = SupabasePhoneVerificationRepository(
      client,
      authUrl: 'https://qa.example.test/auth/v1',
      httpClient: transport,
    );
    addTearDown(repo.dispose);
    await expectLater(repo.requestPhoneCode('5512345678'), throwsArgumentError);
    expect(calls, 0);
    await repo.requestPhoneCode(phone);
    await restore(client, other);
    await expectLater(repo.verifyPhoneCode(phone, '123456'), throwsStateError);
    expect(calls, 1);
  });

  test(
    'late phone request cannot restore previous user onto new account session',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final transport = MockClient((_) {
        started.complete();
        return response.future;
      });
      final client = SupabaseClient(
        'https://qa.example.test',
        'qa-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: transport,
      );
      addTearDown(client.dispose);
      await restore(client, actor);
      final repo = SupabasePhoneVerificationRepository(
        client,
        authUrl: 'https://qa.example.test/auth/v1',
        httpClient: transport,
      );
      addTearDown(repo.dispose);
      final pending = repo.requestPhoneCode(phone);
      final rejected = expectLater(pending, throwsStateError);
      await started.future;
      await restore(client, other);
      response.complete(http.Response(jsonEncode(user(actor)), 200));
      await rejected;
      expect(client.auth.currentUser?.id, other);
    },
  );

  test(
    'authoritative different UUID never confirms phone despite successful OTP',
    () async {
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/verify')) {
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode(
            user(
              request.method == 'GET' ? other : actor,
              phone: phone.substring(1),
              confirmed: true,
            ),
          ),
          200,
        );
      });
      final client = SupabaseClient(
        'https://qa.example.test',
        'qa-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: transport,
      );
      addTearDown(client.dispose);
      await restore(client, actor);
      final repo = SupabasePhoneVerificationRepository(
        client,
        authUrl: 'https://qa.example.test/auth/v1',
        httpClient: transport,
      );
      addTearDown(repo.dispose);
      await repo.requestPhoneCode(phone);
      await expectLater(
        repo.verifyPhoneCode(phone, '123456'),
        throwsStateError,
      );
      expect(repo.verifiedPhone, isNull);
      expect(client.auth.currentUser?.id, actor);
    },
  );
}
