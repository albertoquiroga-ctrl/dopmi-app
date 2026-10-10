import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import 'chat_photo_repository.dart';
import '../adoption/community_repository.dart';
import '../identity/experience_controller.dart';

class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble(this.message, {super.key, required this.mine});
  final Json message;
  final bool mine;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: ref.watch(experienceProvider),
    builder: (context, _) {
      final rescuer =
          ref.read(experienceProvider).value == AccountExperience.rescuer;
      final hasMedia = (message['attachment_path'] as String? ?? '').isNotEmpty;
      final date = DateTime.tryParse(message['created_at'] as String? ?? '')
          ?.toLocal();
      final time = date == null
          ? ''
          : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return LayoutBuilder(
        builder: (context, box) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: hasMedia
                ? const EdgeInsets.all(8)
                : const EdgeInsets.fromLTRB(16, 10, 16, 8),
            constraints: BoxConstraints(
              maxWidth: box.maxWidth * (hasMedia ? .72 : .78),
            ),
            decoration: BoxDecoration(
              color: mine
                  ? (rescuer ? purple : yellow)
                  : (rescuer
                        ? const Color(0xfff0eff8)
                        : const Color(0xffefede8)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(mine ? 24 : 12),
                bottomRight: Radius.circular(mine ? 12 : 24),
              ),
            ),
            child: Semantics(
              label: mine ? 'Mensaje enviado por ti' : 'Mensaje recibido',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((message['attachment_path'] as String? ?? '')
                      .isNotEmpty) ...[
                    ChatPrivatePhoto(message['attachment_path'] as String),
                    if ((message['body'] as String? ?? '').isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  if ((message['body'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: hasMedia
                          ? const EdgeInsets.symmetric(horizontal: 8)
                          : EdgeInsets.zero,
                      child: SelectableText(
                        message['body'] as String? ?? '',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.55,
                          color: mine && rescuer ? Colors.white : ink,
                        ),
                      ),
                    ),
                  if (date != null) ...[
                    const SizedBox(height: 3),
                    Padding(
                      padding: hasMedia
                          ? const EdgeInsets.fromLTRB(8, 0, 8, 4)
                          : EdgeInsets.zero,
                      child: Semantics(
                        label: 'Fecha del mensaje: ${date.toString()}',
                        child: ExcludeSemantics(
                          child: Text(
                            time,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              height: 1.2,
                              color: mine && rescuer
                                  ? Colors.white.withValues(alpha: .92)
                                  : (mine ? muted : const Color(0xff777289)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ChatPrivatePhoto extends ConsumerWidget {
  const ChatPrivatePhoto(this.path, {super.key, this.fullscreen = false});
  final String path;
  final bool fullscreen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(chatPhotoRepositoryProvider);
    final actor = repository.userId;
    final photo = RemotePhoto(
      key: ValueKey('chat-photo:$actor:$path'),
      source: PhotoRef(
        path: path,
        purpose: MediaPurpose.chatPhoto,
        revision: actor ?? '',
        persistence: PhotoPersistence.memory,
        sign: () async {
          if (actor == null || repository.userId != actor) {
            throw StateError('La sesión cambió.');
          }
          final url = await repository.photoUrl(path);
          if (repository.userId != actor) {
            throw StateError('La sesión cambió.');
          }
          return url;
        },
      ),
      width: fullscreen ? null : 220,
      height: fullscreen ? null : 165,
      loading: const Center(child: CircularProgressIndicator()),
      unavailable: (retry) => IconButton(
        tooltip: 'Reintentar foto privada',
        onPressed: retry,
        icon: const Icon(Icons.refresh),
      ),
    );
    if (fullscreen) {
      return InteractiveViewer(child: photo);
    }
    return Semantics(
      button: true,
      label: 'Ver foto del mensaje',
      child: InkWell(
        onTap: actor == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      title: const Text('Foto del mensaje'),
                      leading: IconButton(
                        tooltip: 'Cerrar foto',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    body: Center(
                      child: ChatPrivatePhoto(path, fullscreen: true),
                    ),
                  ),
                ),
              ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(aspectRatio: 4 / 3, child: photo),
        ),
      ),
    );
  }
}
