import 'dart:async';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/native_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import 'support/google_sign_in_platform_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'failed Google initialization stays failed across instances and retries',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final originalPlatform = GoogleSignInPlatform.instance;
      final platform = FakeGoogleSignInPlatform();
      platform.initializationBarrier = Completer<void>();
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      platform.initializationError = error;
      GoogleSignInPlatform.instance = platform;
      addTearDown(() => GoogleSignInPlatform.instance = originalPlatform);
      const config = AppConfig(
        url: 'http://127.0.0.1:54321',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleServerClientId: 'server-client.apps.googleusercontent.com',
        googleIosClientId: 'ios-client.apps.googleusercontent.com',
      );
      final first = PlatformNativeIdentity(config);
      final second = PlatformNativeIdentity(config);
      final firstFailure = expectLater(
        first.authenticate('google'),
        throwsA(same(error)),
      );
      final concurrentFailure = expectLater(
        second.authenticate('google'),
        throwsA(same(error)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(platform.initializations, hasLength(1));
      expect(platform.authentications, isEmpty);

      platform.initializationBarrier!.complete();
      await firstFailure;
      await concurrentFailure;
      platform.initializationError = null;
      await expectLater(first.authenticate('google'), throwsA(same(error)));
      await expectLater(second.authenticate('google'), throwsA(same(error)));

      expect(platform.initializations, hasLength(1));
      expect(platform.authentications, isEmpty);
    },
  );
}
