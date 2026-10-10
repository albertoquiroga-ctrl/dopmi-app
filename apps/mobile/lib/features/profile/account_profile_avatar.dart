import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import '../identity/identity_controller.dart';
import 'account_photo_repository.dart';

final accountProfileAvatarPathProvider = FutureProvider.family<String?, String>(
  (ref, actor) {
    final repository = ref.watch(accountPhotoRepositoryProvider);
    void changed() => ref.invalidateSelf();
    repository.addListener(changed);
    ref.onDispose(() => repository.removeListener(changed));
    if (repository.owner() != actor) {
      return null;
    }
    return repository.loadPath();
  },
);

class AccountProfileAvatar extends ConsumerWidget {
  const AccountProfileAvatar({super.key, required this.name, this.size = 56});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: ref.watch(identityControllerProvider),
    builder: (context, _) {
      final actor = ref.read(identityControllerProvider).identity?.id;
      final fallback = CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xfff3f0ea),
        foregroundColor: const Color(0xff15110d),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      );
      if (actor == null) {
        return fallback;
      }
      final path = ref
          .watch(accountProfileAvatarPathProvider(actor))
          .asData
          ?.value;
      if (path == null) {
        return fallback;
      }
      final repository = ref.read(accountPhotoRepositoryProvider);
      return ClipOval(
        child: RemotePhoto(
          key: ValueKey('profile-avatar:$actor:$path'),
          width: size,
          height: size,
          source: PhotoRef(
            path: path,
            purpose: MediaPurpose.accountAvatar,
            revision: actor,
            persistence: PhotoPersistence.memory,
            sign: () => repository.signedUrl(path),
          ),
          loading: fallback,
          unavailable: (_) => fallback,
        ),
      );
    },
  );
}
