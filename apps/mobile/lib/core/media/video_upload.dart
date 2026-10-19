import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'video_repository.dart';

/// Shared editor: keeps one file/request key/asset while retrying a lost upload.
/// Parent forms must wait for onReady before allowing a new case submission.
class VideoUpload extends StatefulWidget {
  const VideoUpload({
    super.key,
    required this.repository,
    required this.parentId,
    required this.parentVersion,
    required this.purpose,
    required this.onReady,
    this.onChanged,
    this.label = 'Video',
    this.picker,
    this.initialAssets = const [],
  });
  final List<Map<String, dynamic>> initialAssets;
  final VideoRepository repository;
  final String parentId, purpose, label;
  final int parentVersion;
  final ValueChanged<VideoAsset> onReady;
  final ValueChanged<VideoAsset?>? onChanged;
  final Future<XFile?> Function(ImageSource source)? picker;
  @override
  State<VideoUpload> createState() => _VideoUploadState();
}

class _VideoUploadState extends State<VideoUpload> {
  XFile? file;
  VideoUploadTask? task;
  VideoAsset? asset;
  String? error;
  String? scope;
  final canceledAssetIds = <String>{};
  double progress = 0;
  bool busy = false;
  int generation = 0;
  Timer? timer;
  StreamSubscription<void>? identitySubscription;
  void watchIdentity() {
    unawaited(identitySubscription?.cancel());
    identitySubscription = widget.repository.identityChanges?.listen((_) {
      if (mounted && scope != widget.repository.identity()) reset();
    });
  }

  @override
  void initState() {
    super.initState();
    scope = widget.repository.identity();
    watchIdentity();
    hydrate();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && scope != widget.repository.identity()) reset();
    });
  }

  @override
  void didUpdateWidget(covariant VideoUpload old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository ||
        old.parentId != widget.parentId ||
        old.parentVersion != widget.parentVersion ||
        old.purpose != widget.purpose) {
      watchIdentity();
      reset();
    } else if (task == null) {
      hydrate();
    }
  }

  void hydrate() {
    if (task != null || scope == null) return;
    for (final row in widget.initialAssets) {
      if (row['parent_id'] != widget.parentId ||
          canceledAssetIds.contains(row['id']) ||
          row['purpose'] != widget.purpose ||
          row['moderation_state'] == 'stale' ||
          ['canceled', 'deleted'].contains(row['technical_state'])) {
        continue;
      }
      if (row['request_key'] is! String ||
          row['parent_version'] is! int ||
          row['bytes'] is! int) {
        continue;
      }
      asset = VideoAsset.fromJson(row);
      task = VideoUploadTask(
        parentId: widget.parentId,
        parentVersion: row['parent_version'] as int,
        purpose: widget.purpose,
        identity: scope!,
        requestKey: row['request_key'] as String,
        expectedBytes: row['bytes'] as int,
        fileFingerprint: row['file_fingerprint'] as String?,
      )..assetId = asset!.id;
      break;
    }
  }

  void reset() {
    generation++;
    task?.cancel();
    file = null;
    task = null;
    asset = null;
    error = null;
    progress = 0;
    busy = false;
    scope = widget.repository.identity();
    hydrate();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    generation++;
    task?.cancel();
    timer?.cancel();
    unawaited(identitySubscription?.cancel());
    super.dispose();
  }

  bool current(int value) =>
      mounted && value == generation && scope == widget.repository.identity();
  Future<void> pick(ImageSource source) async {
    if (busy) return;
    final run = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected =
          await (widget.picker?.call(source) ??
              ImagePicker().pickVideo(
                source: source,
                maxDuration: videoMaxDuration,
              ));
      if (!current(run)) return;
      if (selected == null) {
        setState(() => busy = false);
        return;
      }
      if (scope == null) throw const VideoFailure('identity_changed');
      final size = await selected.length();
      if (!current(run)) return;
      if (size < 1 || size > videoMaxBytes) {
        throw const VideoFailure('file_size');
      }
      if (task?.assetId != null && task!.fileFingerprint == null) {
        throw const VideoFailure('file_changed');
      }
      file = selected;
      task ??= VideoUploadTask(
        parentId: widget.parentId,
        parentVersion: widget.parentVersion,
        purpose: widget.purpose,
        identity: scope!,
      );
      asset = null;
      widget.onChanged?.call(null);
      await upload(run);
    } catch (cause) {
      if (current(run)) {
        setState(() {
          error = message(cause);
          busy = false;
        });
      }
    }
  }

  Future<void> upload(int run) async {
    if (file == null || task == null) return;
    if (current(run)) {
      setState(() {
        busy = true;
        error = null;
      });
    }
    try {
      final value = await widget.repository.upload(
        task!,
        file!,
        onProgress: (done, total) {
          if (current(run)) setState(() => progress = done / total);
        },
      );
      if (!current(run)) return;
      setState(() {
        asset = value;
        busy = false;
        error = null;
      });
      widget.onChanged?.call(value);
      if (value.ready) widget.onReady(value);
    } catch (cause) {
      if (current(run)) {
        setState(() {
          error = message(cause);
          busy = false;
        });
      }
    }
  }

  Future<void> refresh() async {
    final id = task?.assetId;
    if (id == null) return;
    final run = ++generation;
    setState(() => busy = true);
    try {
      final value = await widget.repository.status(id);
      if (!current(run)) return;
      setState(() {
        asset = value;
        busy = false;
        error = null;
      });
      widget.onChanged?.call(value);
      if (value.ready) widget.onReady(value);
    } catch (cause) {
      if (current(run)) {
        setState(() {
          busy = false;
          error = message(cause);
        });
      }
    }
  }

  Future<void> cancel() async {
    final previous = task;
    if (previous == null) return;
    final run = ++generation;
    setState(() => busy = true);
    try {
      await widget.repository.cancel(previous);
      if (!current(run)) return;
      if (previous.assetId != null) canceledAssetIds.add(previous.assetId!);
      reset();
      widget.onChanged?.call(null);
    } catch (cause) {
      if (current(run)) {
        setState(() {
          busy = false;
          error = message(cause);
        });
      }
    }
  }

  String message(Object cause) => switch (cause) {
    VideoFailure(code: 'file_changed') => 'Elige exactamente el mismo archivo para reanudar. Si ya no lo tienes, cancela la carga antes de elegir otro.',
    VideoFailure(code: 'file_size') => 'Elige un video de hasta 200 MB.',
    VideoFailure(code: 'needs_reconciliation') =>
      'La carga necesita revisión. No la vuelvas a crear; contacta a soporte.',
    VideoFailure(code: 'identity_changed') =>
      'Tu sesión cambió. Vuelve a elegir el video.',
    VideoFailure(code: 'canceled') => 'Carga cancelada.',
    _ => 'No pudimos completar la carga. Puedes reintentar el mismo video.',
  };
  @override
  Widget build(BuildContext context) {
    final state = asset?.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
        const Text(
          'Hasta 60 segundos. El video pasa por revisión antes de publicarse.',
        ),
        if (file == null && !['ready', 'processing', 'failed'].contains(state))
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy || scope == null || task?.assetId != null
                    ? null
                    : () => pick(ImageSource.camera),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Grabar video'),
              ),
              OutlinedButton.icon(
                onPressed: busy || scope == null
                    ? null
                    : () => pick(ImageSource.gallery),
                icon: const Icon(Icons.video_library_outlined),
                label: Text(
                  task?.assetId == null
                      ? 'Elegir video'
                      : 'Elegir mismo video para reanudar',
                ),
              ),
            ],
          ),
        if (busy) ...[
          LinearProgressIndicator(
            value: progress > 0 && progress < 1 ? progress : null,
          ),
          Text('Cargando ${(progress * 100).round()} %'),
        ],
        if (state == 'ready')
          const Text('Video procesado. La publicación requiere revisión.'),
        if (state == 'processing' || state == 'uploading')
          const Text('Estamos procesando tu video.'),
        if (state == 'failed')
          const Text(
            'El video no pudo procesarse. Cancélalo y elige otro de hasta 60 segundos.',
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (task != null)
          Wrap(
            spacing: 8,
            children: [
              if (!busy &&
                  error != null &&
                  task?.canceled != true &&
                  file != null)
                TextButton(
                  onPressed: () => upload(++generation),
                  child: const Text('Reintentar carga'),
                ),
              if (!busy &&
                  task?.assetId != null &&
                  !['failed', 'canceled', 'deleted', 'ready'].contains(state))
                TextButton(
                  onPressed: refresh,
                  child: const Text('Comprobar video'),
                ),
              TextButton(
                onPressed: cancel,
                child: const Text('Cancelar video'),
              ),
            ],
          ),
      ],
    );
  }
}
