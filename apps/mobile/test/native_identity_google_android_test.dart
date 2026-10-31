import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/native_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import 'support/google_sign_in_platform_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android Google keeps nonce absent and shares SDK initialization',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final originalPlatform = GoogleSignInPlatform.instance;
      final platform = FakeGoogleSignInPlatform();
      GoogleSignInPlatform.instance = platform;
      addTearDown(() => GoogleSignInPlatform.instance = originalPlatform);
      const config = AppConfig(
        url: 'http://127.0.0.1:54321',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleServerClientId: 'server-client.apps.googleusercontent.com',
      );

      final first = await PlatformNativeIdentity(config).authenticate('google');
      final second = await PlatformNativeIdentity(config)
          .authenticate('google');

      expect(platform.initializations, hasLength(1));
      expect(
        platform.initializations.single.serverClientId,
        config.googleServerClientId,
      );
      expect(platform.initializations.single.clientId, isNull);
      expect(platform.initializations.single.nonce, isNull);
      for (final credential in [first, second]) {
        expect(credential?.nonce, isNull);
        expect(credential?.idToken, isNotEmpty);
        expect(credential?.accessToken, 'google-access-token');
      }
    },
  );
}
