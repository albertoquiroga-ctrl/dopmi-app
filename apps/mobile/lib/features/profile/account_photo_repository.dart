import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/media/media_store.dart';

final accountPhotoRepositoryProvider = Provider<AccountPhotoRepository>((ref) {
  final repository = AccountPhotoRepository.supabase();
  ref.onDispose(repository.dispose);
  return repository;
});

class AccountPhotoRepository extends ChangeNotifier {
  AccountPhotoRepository({
    required this.owner,
    required this.rpc,
    required this.upload,
    required this.sign,
  });
  factory AccountPhotoRepository.supabase() {
    final client = Supabase.instance.client;
    final media = MediaStore(client);
    return AccountPhotoRepository(
      owner: () => client.auth.currentUser?.id,
      rpc: (name, params) => client.rpc(name, params: params),
      upload: (id, bytes) =>
          media.upload(id, bytes, MediaPurpose.accountAvatar),
      sign: (path) => media.signedUrl(path, MediaPurpose.accountAvatar),
    );
  }
  final String? Function() owner;
  final Future<dynamic> Function(String, Map<String, dynamic>) rpc;
  final Future<String> Function(String, Uint8List) upload;
  final Future<String> Function(String) sign;

  String requireOwner() {
    final value = owner();
    if (value == null) throw StateError('account_photo_owner_changed');
    return value;
  }

  void checkOwner(String expected) {
    if (owner() != expected) throw StateError('account_photo_owner_changed');
  }

  void validatePath(String path, String actor) {
    if (!RegExp(
      '^${RegExp.escape(actor)}/${RegExp.escape(actor)}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\.jpg\$',
    ).hasMatch(path)) {
      throw StateError('invalid_account_photo');
    }
  }

  String? readPath(dynamic result, String actor) {
    if (result == null) return null;
    if (result is! Map || result['photo_path'] is! String) {
      throw StateError('invalid_account_photo');
    }
    final path = result['photo_path'] as String;
    validatePath(path, actor);
    return path;
  }

  Future<String?> loadPath() async {
    final actor = requireOwner();
    final result = await rpc('dopmi_my_account_photo', {});
    checkOwner(actor);
    return readPath(result, actor);
  }

  Future<String> uploadPhoto(Uint8List bytes) async {
    final actor = requireOwner();
    final path = await upload(actor, bytes);
    checkOwner(actor);
    validatePath(path, actor);
    return path;
  }

  Future<String> signedUrl(String path) async {
    final actor = requireOwner();
    validatePath(path, actor);
    final result = await sign(path);
    checkOwner(actor);
    return result;
  }

  Future<void> savePath(String? path) async {
    final actor = requireOwner();
    if (path != null) validatePath(path, actor);
    try {
      final result = await rpc('dopmi_save_account_photo', {
        'photo_path': path,
      });
      checkOwner(actor);
      if (readPath(result, actor) != path) {
        throw StateError('invalid_account_photo');
      }
      notifyListeners();
    } catch (error, stack) {
      if (error is PostgrestException || error is StateError) rethrow;
      checkOwner(actor);
      try {
        final result = await rpc('dopmi_my_account_photo', {});
        checkOwner(actor);
        if (readPath(result, actor) == path) {
          notifyListeners();
          return;
        }
      } catch (_) {
        checkOwner(actor);
      }
      Error.throwWithStackTrace(error, stack);
    }
  }
}
