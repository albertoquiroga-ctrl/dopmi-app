import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';

import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class PhotoDraftRepo extends FakeRescuerProfile {
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
}
