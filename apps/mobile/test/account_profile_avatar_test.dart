import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/features/profile/account_profile_avatar.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';

void main() {
  const owner = 'dd010000-0000-4000-8000-000000000010';
  const other = 'dd010000-0000-4000-8000-000000000011';
  const path = '$owner/$owner/dd010000-0000-4000-8000-000000000001.jpg';
  const updated = '$owner/$owner/dd010000-0000-4000-8000-000000000002.jpg';

  test('profile avatar path is cached per owner and refreshed only after persisted avatar change', () async {
    var loads = 0;
    String? stored = path;
    final repository = AccountPhotoRepository(
      owner: () => owner,
      rpc: (name, params) async {
        if (name == 'dopmi_save_account_photo') {
          stored = params['photo_path'] as String?;
        } else {
          loads++;
        }
        return stored == null ? null : {'photo_path': stored};
      },
      upload: (_, _) async => path,
      sign: (_) async => 'https://private.example.test',
    );
    final container = ProviderContainer(
      overrides: [accountPhotoRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);
    expect(
      await container.read(accountProfileAvatarPathProvider(owner).future),
      path,
    );
    expect(
      await container.read(accountProfileAvatarPathProvider(owner).future),
      path,
    );
    expect(loads, 1);
    await repository.savePath(updated);
    expect(
      await container.read(accountProfileAvatarPathProvider(owner).future),
      updated,
    );
    expect(loads, 2);
  });

  test(
    'late avatar for previous owner cannot populate new account profile',
    () async {
      String current = owner;
      final result = Completer<dynamic>();
      final repository = AccountPhotoRepository(
        owner: () => current,
        rpc: (_, _) => result.future,
        upload: (_, Uint8List bytes) async => path,
        sign: (_) async => 'https://private.example.test',
      );
      final container = ProviderContainer(
        overrides: [
          accountPhotoRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);
      final previous = container.read(
        accountProfileAvatarPathProvider(owner).future,
      );
      final rejected = expectLater(previous, throwsStateError);
      current = other;
      result.complete({'photo_path': path});
      await rejected;
      expect(
        container.read(accountProfileAvatarPathProvider(owner)).asData,
        isNull,
      );
    },
  );

  testWidgets('guest avatar uses initial fallback without a private RPC', (
    tester,
  ) async {
    var calls = 0;
    final repository = AccountPhotoRepository(
      owner: () => null,
      rpc: (_, _) async {
        calls++;
        return null;
      },
      upload: (_, _) async => path,
      sign: (_) async => 'https://private.example.test',
    );
    final identity = FakeIdentityRepository();
    addTearDown(identity.changes.close);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          accountPhotoRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AccountProfileAvatar(name: 'Ana')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
