import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';

import 'fake_identity_repository.dart';

AccountPhotoRepository emptyAccountPhotoRepository(
  FakeIdentityRepository identity,
) {
  String? saved;
  return AccountPhotoRepository(
    owner: () => identity.current?.id,
    rpc: (name, params) async {
      if (name == 'dopmi_save_account_photo') {
        saved = params['photo_path'] as String?;
      }
      return saved == null ? null : {'photo_path': saved};
    },
    upload: (id, bytes) async =>
        '$id/$id/73000000-0000-4000-8000-000000000001.jpg',
    sign: (_) async => 'https://example.invalid/private-photo.jpg',
  );
}
