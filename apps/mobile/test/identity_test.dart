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
    expect(controller.redirect('/privacy-notice'), isNull);
    expect(controller.redirect('/settings/account'), '/welcome');
    expect(controller.redirect('/contribute-case/case-one'), '/welcome');
    expect(controller.redirect('/reset-password'), '/welcome');
    repository.emit(
      const IdentityEvent(Identity('one', 'ana@example.test', verified: false)),
    );
    expect(controller.redirect('/profile'), '/welcome');
    expect(controller.redirect('/privacy-notice'), isNull);
    expect(controller.redirect('/settings/account'), '/welcome');
    expect(controller.redirect('/contribute-case/case-one'), '/welcome');
    repository.emit(
      const IdentityEvent(Identity('one', 'ana@example.test', verified: true)),
    );
    expect(controller.redirect('/login'), '/adoptions');
    expect(controller.redirect('/about'), isNull);
    expect(controller.redirect('/privacy-notice'), isNull);
    expect(controller.redirect('/settings/account'), isNull);
    expect(controller.redirect('/contribute-case/case-one'), isNull);
    expect(controller.redirect('/transparency'), isNull);
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
  test(
    'recovery presentation survives a transient null and clears on sign-out',
    () async {
      repository.recoveryPresentationIntent = 'rescue';
      await controller.initialize();
      expect(controller.recoveryIntent, 'rescue');
      repository.emit(const IdentityEvent(null));
      expect(controller.recoveryIntent, 'rescue');
      expect(repository.recoveryPresentationIntent, 'rescue');
      repository.emit(
        const IdentityEvent(
          Identity('one', 'ana@example.test', verified: true),
          recovery: true,
        ),
      );
      expect(controller.recoveryIntent, 'rescue');
      expect(controller.recoveryEmail, 'ana@example.test');
      expect(controller.redirect('/profile'), '/reset-password');
      await controller.logout();
      expect(controller.recoveryEmail, isNull);
      expect(controller.recoveryIntent, 'adopt');
      expect(repository.recoveryPresentationIntent, isNull);
    },
  );
  test(
    'invalid presentation hints cannot choose an account mode or recovery',
    () async {
      repository.recoveryPresentationIntent = 'admin';
      await controller.initialize();
      expect(controller.recoveryIntent, 'adopt');
      expect(controller.recovering, isFalse);
      expect(controller.redirect('/reset-password'), '/welcome');
      expect(repository.loads, 0);
    },
  );
  test(
    'recovery cannot update a replacement SDK actor before its event arrives',
    () async {
      await controller.initialize();
      await controller.prepareRecoveryPresentation(
        'rescue',
        'ana@example.test',
      );
      repository.emit(
        const IdentityEvent(
          Identity('one', 'ana@example.test', verified: true),
          recovery: true,
        ),
      );
      repository.user = const Identity(
        'other',
        'other@example.test',
        verified: true,
      );
      await expectLater(
        controller.completeRecovery('NewPassword123'),
        throwsStateError,
      );
      expect(repository.passwordUpdates, 0);
      expect(repository.current?.id, 'other');
    },
  );
  test(
    'replacement actor clears recovery authority and presentation',
    () async {
      await controller.initialize();
      await controller.prepareRecoveryPresentation(
        'rescue',
        'ana@example.test',
      );
      repository.emit(
        const IdentityEvent(
          Identity('one', 'ana@example.test', verified: true),
          recovery: true,
        ),
      );
      repository.emit(const IdentityEvent(null));
      repository.emit(
        const IdentityEvent(
          Identity('other', 'other@example.test', verified: true),
        ),
      );
      expect(controller.recovering, isFalse);
      expect(controller.recoveryEmail, isNull);
      expect(controller.recoveryIntent, 'adopt');
      expect(repository.recoveryPresentationIntent, isNull);
      expect(repository.pending, isFalse);
      await expectLater(
        controller.completeRecovery('NewPassword123'),
        throwsStateError,
      );
      expect(repository.passwordUpdates, 0);
    },
  );
  test('late password update cannot sign out a replacement actor', () async {
    final isolated = DelayedPasswordRepository();
    final owner = IdentityController(isolated);
    addTearDown(() async {
      owner.dispose();
      await isolated.changes.close();
    });
    await owner.initialize();
    isolated.emit(
      const IdentityEvent(
        Identity('one', 'ana@example.test', verified: true),
        recovery: true,
      ),
    );
    final update = owner.completeRecovery('NewPassword123');
    final rejected = expectLater(update, throwsStateError);
    isolated.emit(
      const IdentityEvent(
        Identity('other', 'other@example.test', verified: true),
      ),
    );
    isolated.response.complete();
    await rejected;
    expect(isolated.current?.id, 'other');
    expect(owner.identity?.id, 'other');
  });
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

class DelayedPasswordRepository extends FakeIdentityRepository {
  final response = Completer<void>();
  @override
  Future<void> updatePassword(String password) async {
    await response.future;
    await super.updatePassword(password);
  }
}
