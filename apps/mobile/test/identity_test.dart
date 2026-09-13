import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';

import 'fake_identity_repository.dart';

void main() {
  late FakeIdentityRepository repository;
  late IdentityController controller;
  setUp(() {
    repository = FakeIdentityRepository();
    controller = IdentityController(repository);
  });
  tearDown(() async {
    controller.dispose();
    await repository.changes.close();
  });
  test('requires a verified identity for the profile and blocks unauthenticated recovery', () async {
    await controller.initialize();
    expect(controller.redirect('/profile'), '/welcome');
    expect(controller.redirect('/reset-password'), '/welcome');
    repository.emit(
      const IdentityEvent(Identity('one', 'ana@example.test', verified: false)),
    );
    expect(controller.redirect('/profile'), '/welcome');
    repository.emit(
      const IdentityEvent(Identity('one', 'ana@example.test', verified: true)),
    );
    expect(controller.redirect('/login'), '/adoptions');
  });
  test(
    'recovery events and persisted recovery cannot fall through to profile',
    () async {
      await controller.initialize();
      repository.emit(
        const IdentityEvent(
          Identity('one', 'ana@example.test', verified: true),
          recovery: true,
        ),
      );
      expect(controller.redirect('/profile'), '/reset-password');
      expect(repository.pending, isTrue);
      await controller.completeRecovery('NewPassword123');
      expect(repository.passwordUpdates, 1);
      expect(controller.identity, isNull);
      expect(repository.pending, isFalse);
    },
  );
  test(
    'restores a session that was interrupted during password recovery',
    () async {
      repository.user = const Identity(
        'one',
        'ana@example.test',
        verified: true,
      );
      repository.pending = true;
      await controller.initialize();
      expect(controller.redirect('/welcome'), '/reset-password');
    },
  );
  test('late restoration cannot overwrite a newer sign-out', () async {
    final restoration = Completer<Identity?>();
    repository.restoreResult = restoration.future;
    final initialization = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    repository.emit(const IdentityEvent(null, signedOut: true));
    restoration.complete(
      const Identity('old', 'old@example.test', verified: true),
    );
    await initialization;
    expect(controller.identity, isNull);
  });
  test('normal signed-in sessions cannot change passwords through the recovery action', () async {
    repository.user = const Identity('one', 'ana@example.test', verified: true);
    await controller.initialize();
    await expectLater(
      controller.completeRecovery('NewPassword123'),
      throwsStateError,
    );
    expect(repository.passwordUpdates, 0);
  });
  test(
    'frontend configuration rejects server keys and insecure remote URLs',
    () {
      expect(
        const AppConfig(
          url: 'https://demo.supabase.co',
          key: 'sb_secret_x',
          redirect: 'io.dopmi.app://auth/callback',
        ).isValid,
        isFalse,
      );
      expect(
        const AppConfig(
          url: 'http://demo.supabase.co',
          key: 'sb_publishable_x',
          redirect: 'io.dopmi.app://auth/callback',
        ).isValid,
        isFalse,
      );
      expect(
        const AppConfig(
          url: 'https://demo.supabase.co',
          key: 'sb_publishable_x',
          redirect: 'io.dopmi.app://auth/callback',
        ).isValid,
        isTrue,
      );
    },
  );
}
