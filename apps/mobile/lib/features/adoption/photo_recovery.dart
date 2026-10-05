import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui.dart';
import 'community_repository.dart';
import '../rescue/rescue_repository.dart';

String pendingPhotoKey(String userId) => 'dopmi-pending-photo-$userId';
const pendingPhotoActorKey = 'dopmi-pending-photo-actor';

class LostPhoto {
  const LostPhoto(this.postId, this.files, {this.rescue = false});
  final String postId;
  final bool rescue;
  final List<XFile> files;
}

final lostPhotoProvider = FutureProvider.family<LostPhoto?, String>((
  ref,
  userId,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final preferences = await SharedPreferences.getInstance();
  final id = preferences.getString(pendingPhotoKey(userId));
  if (id == null) return null;
  if (preferences.getString(pendingPhotoActorKey) != userId) {
    return LostPhoto(
      id.startsWith('rescue:') ? id.substring(7) : id,
      const [],
      rescue: id.startsWith('rescue:'),
    );
  }
  final lost = await ImagePicker().retrieveLostData();
  if (lost.isEmpty) return null;
  return LostPhoto(
    id.startsWith('rescue:') ? id.substring(7) : id,
    lost.files ?? [],
    rescue: id.startsWith('rescue:'),
  );
});

class PhotoRecoveryNotice extends ConsumerStatefulWidget {
  const PhotoRecoveryNotice({super.key});
  @override
  ConsumerState<PhotoRecoveryNotice> createState() => _PhotoRecoveryState();
}

class _PhotoRecoveryState extends ConsumerState<PhotoRecoveryNotice> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final repo = ref.read(communityRepositoryProvider),
        userId = ref.read(communityRepositoryProvider).userId;
    if (userId == null) return const SizedBox.shrink();
    final recovered = ref.watch(lostPhotoProvider(userId));
    return recovered.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Notice(
        'No pudimos recuperar la selección de fotos anterior. Tus campos se guardaron antes de abrir la galería; puedes retomar el borrador en Publicar.',
      ),
      data: (lost) {
        if (lost == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Notice(
              'Android interrumpió la selección de una foto. Tu borrador está guardado.',
            ),
            if (error != null) Notice(error!, isError: true),
            ActionButton(
              lost.files.isEmpty
                  ? 'Retomar borrador'
                  : 'Recuperar foto y retomar borrador',
              busy: busy,
              onPressed: () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  if (lost.rescue) {
                    final rescue = ref.read(rescueRepositoryProvider);
                    final detail = await rescue.detail(lost.postId);
                    final record = RescueRecord(Json.from(detail['record']));
                    if (record.kind != 'case' ||
                        record.data['owner_id'] != userId) {
                      throw const FormatException(
                        'El borrador ya no está disponible.',
                      );
                    }
                    if (lost.files.isNotEmpty &&
                        record.editable &&
                        record.files
                                .where((file) => file['role'] == 'public')
                                .length <
                            6) {
                      final bytes = await lost.files.first.readAsBytes();
                      if (bytes.length > 5242880) {
                        throw const FormatException(
                          'El archivo debe pesar hasta 5 MB.',
                        );
                      }
                      final path = await rescue.upload(
                        record.id,
                        bytes,
                        pdf: false,
                      );
                      await rescue.save(
                        'case',
                        record.publicData,
                        record.privateData,
                        [
                          ...record.files,
                          {'role': 'public', 'path': path},
                        ],
                        record: record,
                        parent: record.parent,
                      );
                    }
                    final preferences = await SharedPreferences.getInstance();
                    await preferences.remove(pendingPhotoKey(userId));
                    if (preferences.getString(pendingPhotoActorKey) == userId) {
                      await preferences.remove(pendingPhotoActorKey);
                    }
                    if (!mounted) return;
                    ref.invalidate(lostPhotoProvider(userId));
                    if (context.mounted) context.push('/rescue/${record.id}');
                    return;
                  }
                  final post = await repo.own(lost.postId);
                  if (post == null) {
                    throw const FormatException(
                      'El borrador ya no está disponible.',
                    );
                  }
                  if (lost.files.isNotEmpty &&
                      post.photos.length < 6 &&
                      [
                        'draft',
                        'changes_requested',
                        'rejected',
                        'archived',
                      ].contains(post.status)) {
                    final path = await repo.uploadPhoto(
                      post.id,
                      await lost.files.first.readAsBytes(),
                    );
                    await repo.save(
                      {
                        ...post.data,
                        'photos': [...post.photos, path],
                      },
                      id: post.id,
                      version: post.version,
                    );
                  }
                  final preferences = await SharedPreferences.getInstance();
                  await preferences.remove(pendingPhotoKey(userId));
                  if (preferences.getString(pendingPhotoActorKey) == userId) {
                    await preferences.remove(pendingPhotoActorKey);
                  }
                  if (!mounted) return;
                  ref.invalidate(lostPhotoProvider(userId));
                  if (context.mounted) context.push('/my-adoptions/${post.id}');
                } catch (cause) {
                  if (mounted) setState(() => error = communityError(cause));
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
