import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/storage.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Runs explicitly against a disposable LOCAL Supabase stack. Auth, PostgreSQL,
// RLS and SMTP are real. Only the platform preference/keychain APIs are mocked;
// these tests do not claim to validate Android Keystore or iOS Keychain hardware.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  final configPath = Platform.environment['DOPMI_LOCAL_CONFIG'];
  if (configPath == null) {
    throw StateError('Set DOPMI_LOCAL_CONFIG to the local CLI status JSON.');
  }
  final status = jsonDecode(File(configPath).readAsStringSync()) as Map;
  final api = Uri.parse(status['API_URL'] as String);
  final mail = Uri.parse(status['INBUCKET_URL'] as String);
  for (final uri in [api, mail]) {
    if (uri.scheme != 'http' ||
        !['127.0.0.1', 'localhost'].contains(uri.host)) {
      throw StateError('Backend tests must only target loopback services.');
    }
  }
  final config = AppConfig(
    url: api.toString(),
    key: status['ANON_KEY'] as String,
    redirect: 'http://localhost:5175/auth/callback',
  );
  final admin = SupabaseClient(
    config.url,
    status['SERVICE_ROLE_KEY'] as String,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final http = HttpClient();
  late SupabaseIdentityRepository repository;
  IdentityController? controller;
  var initialized = false;
  late String email;
  late String namespace;

  Future<void> eventually(Future<bool> Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('The expected backend state did not arrive within 20 seconds.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<Map<String, dynamic>> readJson(Uri uri) async {
    final response = await (await http.getUrl(uri)).close();
    expect(response.statusCode, 200);
    return jsonDecode(await utf8.decodeStream(response))
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> emailMessage(String subject) async {
    Map<String, dynamic>? found;
    await eventually(() async {
      final result = await readJson(
        mail
            .resolve('/api/v1/search')
            .replace(queryParameters: {'query': 'to:$email'}),
      );
      final messages = (result['messages'] as List).cast<Map>();
      for (final message in messages) {
        if (message['Subject'] == subject) {
          found = await readJson(
            mail.resolve('/api/v1/message/${message['ID']}'),
          );
          return true;
        }
      }
      return false;
    });
    return found!;
  }

  String emailCode(Map<String, dynamic> message) {
    final match = RegExp(r'>\s*(\d{8})\s*<')
        .firstMatch(message['HTML'] as String);
    expect(match, isNotNull, reason: 'The Spanish email must contain an OTP.');
    return match!.group(1)!;
  }

  Future<void> startClient() async {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: SecureSessionStorage(namespace),
        pkceAsyncStorage: SecurePkceStorage(namespace),
      ),
    );
    initialized = true;
    repository = SupabaseIdentityRepository(
      Supabase.instance.client,
      config,
      await SharedPreferences.getInstance(),
    );
    controller = IdentityController(repository);
    await controller!.initialize();
  }

  Future<void> restartClient() async {
    controller!.dispose();
    controller = null;
    await Supabase.instance.dispose();
    initialized = false;
    await startClient();
  }

  setUp(() async {
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch}'
        '-${Random.secure().nextInt(1000000)}';
    email = 'dopmi-acceptance-$suffix@example.test';
    namespace = 'acceptance-$suffix';
    // This explicitly invoked test suite lives outside test/ to require a real
    // local backend without silently skipping acceptance checks in unit tests.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
    await startClient();
  });

  tearDown(() async {
    controller?.dispose();
    controller = null;
    if (initialized) {
      await Supabase.instance.dispose();
      initialized = false;
    }
    // Only delete the exact disposable identity created by this test.
    final users = await admin.auth.admin.listUsers();
    for (final user in users.where((user) => user.email == email)) {
      await admin.auth.admin.deleteUser(user.id);
    }
  });
  tearDownAll(() async {
    http.close();
    await admin.dispose();
  });

  for (final recoveryViaLink in [false, true]) {
    test(
      'real signup, profile, restored session and recovery via '
      '${recoveryViaLink ? 'PKCE link after restart' : 'email OTP'}',
      () async {
        final password = 'Initial${Random.secure().nextInt(1 << 30)}Ab9';
        final newPassword = 'Changed${Random.secure().nextInt(1 << 30)}Cd8';
        await repository.signup(
          name: 'Prueba de aceptación',
          email: email,
          phone: '',
          password: password,
          intent: 'rescue',
        );
        expect(repository.current, isNull);
        await expectLater(
          repository.login(email, password),
          throwsA(
            isA<AuthException>().having(
              (error) => error.code,
              'code',
              'email_not_confirmed',
            ),
          ),
        );
        final confirmation = await emailMessage('Confirma tu cuenta de Dopmi');
        await repository.confirmCode(
          email,
          emailCode(confirmation),
          recovery: false,
        );
        await eventually(() async => controller!.identity?.verified == true);
        final profile = await repository.loadProfile();
        expect(profile.name, 'Prueba de aceptación');
        expect(profile.termsVersion, developmentTermsVersion);
        expect(profile.intent, 'rescue');
        await repository.saveProfile(
          name: 'Perfil actualizado',
          phone: '5550000000',
          city: 'Ciudad de México',
          mode: 'rescuer',
        );
        expect(await repository.client.rpc('dopmi_is_admin'), isFalse);
        await expectLater(
          repository.client.rpc('admin_list_users'),
          throwsA(
            isA<PostgrestException>().having(
              (error) => error.code,
              'code',
              '42501',
            ),
          ),
        );
        await eventually(
          () => SecureSessionStorage(namespace).hasAccessToken(),
        );
        await restartClient();
        await eventually(() async => controller!.identity?.verified == true);
        expect(controller!.redirect('/welcome'), '/profile');
        final restored = await repository.loadProfile();
        expect(restored.name, 'Perfil actualizado');
        expect(restored.city, 'Ciudad de México');
        expect(restored.mode, 'rescuer');
        await expectLater(
          controller!.completeRecovery(newPassword),
          throwsStateError,
        );
        await controller!.logout();
        await eventually(
          () async => !await SecureSessionStorage(namespace).hasAccessToken(),
        );
        await repository.requestRecovery(email);
        final recovery = await emailMessage('Recupera tu acceso a Dopmi');
        await expectLater(
          repository.confirmCode(email, '00000000', recovery: true),
          throwsA(isA<AuthException>()),
        );
        if (recoveryViaLink) {
          // The verifier must survive closing the app before opening the email.
          await restartClient();
          final href = RegExp(r'href="([^"]+)"')
              .firstMatch(recovery['HTML'] as String)!
              .group(1)!;
          final verifyUrl = Uri.parse(href.replaceAll('&amp;', '&'));
          expect(verifyUrl.origin, api.origin);
          final request = await http.getUrl(verifyUrl);
          request.followRedirects = false;
          final response = await request.close();
          expect(response.statusCode, anyOf(302, 303));
          final callback = Uri.parse(response.headers.value('location')!);
          await response.drain<void>();
          expect(callback.origin, 'http://localhost:5175');
          expect(callback.path, '/auth/callback');
          await repository.client.auth.getSessionFromUrl(callback);
        } else {
          await repository.confirmCode(
            email,
            emailCode(recovery),
            recovery: true,
          );
        }
        await eventually(() async => controller!.recovering);
        expect(controller!.redirect('/profile'), '/reset-password');
        await eventually(repository.recoveryPending);
        await restartClient();
        await eventually(() async => controller!.identity != null);
        expect(controller!.redirect('/welcome'), '/reset-password');
        await controller!.completeRecovery(newPassword);
        expect(repository.current, isNull);
        expect(await repository.recoveryPending(), isFalse);
        await expectLater(
          repository.login(email, password),
          throwsA(
            isA<AuthException>().having(
              (error) => error.code,
              'code',
              'invalid_credentials',
            ),
          ),
        );
        await repository.login(email, newPassword);
        expect((await repository.loadProfile()).name, 'Perfil actualizado');
        await controller!.logout();
        await restartClient();
        expect(repository.current, isNull);
        expect(controller!.redirect('/profile'), '/welcome');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
