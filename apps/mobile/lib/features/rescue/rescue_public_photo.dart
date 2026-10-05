import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import 'rescue_repository.dart';

PhotoRef rescuePhotoSource(RescueRepository repository, String path) =>
    PhotoRef(
      path: path,
      purpose: MediaPurpose.rescuePhoto,
      persistence: PhotoPersistence.ordinary,
      sign: () => repository.fileUrl(path),
    );

class RescuePublicPhoto extends ConsumerWidget {
  const RescuePublicPhoto(
    this.path, {
    super.key,
    this.height = 220,
    this.radius = 20,
    this.compact = false,
  });
  final String path;
  final double height, radius;
  final bool compact;

  Widget unavailable(VoidCallback retry) => compact
      ? SizedBox(
          height: height,
          child: Center(
            child: IconButton(
              tooltip: 'Foto no disponible. Reintentar foto',
              onPressed: retry,
              icon: const Icon(Icons.refresh),
            ),
          ),
        )
      : SizedBox(
          height: height,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Foto no disponible'),
                TextButton(
                  onPressed: retry,
                  child: const Text('Reintentar foto'),
                ),
              ],
            ),
          ),
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(rescueRepositoryProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: RemotePhoto(
          source: rescuePhotoSource(repository, path),
          height: height,
          width: double.infinity,
          loading: compact
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Cargando foto',
                    ),
                  ),
                )
              : const Center(child: Text('Cargando foto…')),
          unavailable: unavailable,
        ),
      ),
    );
  }
}
