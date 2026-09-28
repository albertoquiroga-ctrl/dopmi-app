import 'dart:async';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/native_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlledNativeIdentity implements NativeIdentity {
  final pending = Completer<NativeIdentityCredential?>();
  int calls = 0;
  @override
  bool supports(String provider) => true;
  @override
  Future<NativeIdentityCredential?> authenticate(String provider) {
    calls++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late ControlledNativeIdentity native;
  late SupabaseIdentityRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient(
      'http://127.0.0.1:54321',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    native = ControlledNativeIdentity();
    repository = SupabaseIdentityRepository(
      client,
      const AppConfig(
        url: 'http://127.0.0.1:54321',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleEnabled: true,
      ),
      await SharedPreferences.getInstance(),
      nativeIdentity: native,
    );
  });
  tearDown(() async => client.dispose());

  test('unknown and disabled providers never launch authentication', () async {
    await expectLater(repository.oauth('facebook'), throwsStateError);
    await expectLater(repository.oauth('apple'), throwsStateError);
    expect(native.calls, 0);
  });

  test(
    'cancelled native login creates no session and blocks double taps',
    () async {
      final first = repository.oauth('google');
      await repository.oauth('google');
      expect(native.calls, 1);
      native.pending.complete(null);
      await first;
      expect(client.auth.currentSession, isNull);
      await repository.oauth('google');
      expect(native.calls, 2);
    },
  );
}
