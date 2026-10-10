import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';

import 'profile_test_identity.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';

import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class PhotoDraftRepo extends FakeRescuerProfile {
  String? owner = 'owner-one';
  @override
  String? get userId => owner;
  int uploads = 0;
  bool reject = true;
  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    uploads++;
    return 'owner/avatar-new.jpg';
  }

  @override
  Future<Json> save(Json payload, {int? version}) async {
    if (reject) throw StateError('offline');
    return super.save(payload, version: version);
  }
}

void main() {
  testWidgets(
    'public photo selection stays local until save and retry reuses upload',
    (tester) async {
      final repo = PhotoDraftRepo();
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phoneVerificationRepositoryProvider.overrideWithValue(
              EditorTestPhone(),
            ),
            identityRepositoryProvider.overrideWithValue(editorTestIdentity()),
            rescuerProfileRepositoryProvider.overrideWithValue(repo),
            publicProfilePhotoPickerProvider.overrideWithValue(
              () async => XFile.fromData(bytes, name: 'photo.png'),
            ),
          ],
          child: const MaterialApp(home: RescuerPublicProfileEditScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('public-profile-photo')));
      await tester.pumpAndSettle();
      expect(repo.uploads, 0);
      expect(repo.saves, 0);
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
        isA<MemoryImage>(),
      );
      final save = find.widgetWithText(FilledButton, 'Guardar borrador');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.uploads, 1);
      expect(repo.saves, 0);
      repo.reject = false;
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.uploads, 1);
      expect(repo.value['avatar_path'], 'owner/avatar-new.jpg');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.uploads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cancel after selecting public photo discards preview without persistence',
    (tester) async {
      final repo = PhotoDraftRepo();
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
      );
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/edit',
            builder: (_, _) => const RescuerPublicProfileEditScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Scaffold(body: Text('Perfil destino')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phoneVerificationRepositoryProvider.overrideWithValue(
              EditorTestPhone(),
            ),
            identityRepositoryProvider.overrideWithValue(editorTestIdentity()),
            rescuerProfileRepositoryProvider.overrideWithValue(repo),
            publicProfilePhotoPickerProvider.overrideWithValue(
              () async => XFile.fromData(bytes, name: 'photo.png'),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('public-profile-photo')));
      await tester.pumpAndSettle();
      final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
      await tester.scrollUntilVisible(
        cancel,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('Perfil destino'), findsOneWidget);
      expect(repo.uploads, 0);
      expect(repo.saves, 0);
      router.go('/edit');
      await tester.pumpAndSettle();
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('public photo response from previous owner is discarded', (
    tester,
  ) async {
    final repo = PhotoDraftRepo();
    final selection = Completer<XFile?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneVerificationRepositoryProvider.overrideWithValue(
            EditorTestPhone(),
          ),
          identityRepositoryProvider.overrideWithValue(editorTestIdentity()),
          rescuerProfileRepositoryProvider.overrideWithValue(repo),
          publicProfilePhotoPickerProvider.overrideWithValue(
            () => selection.future,
          ),
        ],
        child: const MaterialApp(home: RescuerPublicProfileEditScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('public-profile-photo')));
    await tester.pump();
    repo.owner = 'other-owner';
    selection.complete(
      XFile.fromData(Uint8List.fromList([1]), name: 'ignored.png'),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isNull,
    );
    expect(repo.uploads, 0);
    expect(repo.saves, 0);
    expect(tester.takeException(), isNull);
  });
}
