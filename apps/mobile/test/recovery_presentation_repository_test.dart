import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recovery hint persists only safe intent in its backend namespace',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      const first = AppConfig(
        url: 'https://first.example.test',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
      );
      const second = AppConfig(
        url: 'https://second.example.test',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
      );
      final client = SupabaseClient(
        first.url,
        first.key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final one = SupabaseIdentityRepository(client, first, preferences);
      final other = SupabaseIdentityRepository(client, second, preferences);
      await one.rememberRecoveryIntent('rescue');
      expect(await one.recoveryIntent(), 'rescue');
      expect(await other.recoveryIntent(), isNull);
      expect(preferences.getKeys(), {
        'dopmi.first.example.test.recovery.intent',
      });
      expect(
        preferences.get('dopmi.first.example.test.recovery.intent'),
        'rescue',
      );
      final restored = SupabaseIdentityRepository(client, first, preferences);
      expect(await restored.recoveryIntent(), 'rescue');
      await restored.rememberRecoveryIntent('admin');
      expect(await restored.recoveryIntent(), 'adopt');
      await restored.rememberRecoveryIntent(null);
      expect(preferences.getKeys(), isEmpty);
      expect(await restored.recoveryPending(), isFalse);
    },
  );
}
