import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/video_repository.dart';
import 'rescue_public_photo.dart';
import 'rescue_repository.dart';
import 'rescue_videos.dart';

bool hasUrgentCaseNeed(
  List<Map<String, dynamic>> needs,
  List<RescueRecord> expenses,
) =>
    needs.any(
      (item) =>
          const ['veterinary', 'medicine'].contains(item['type']) &&
          item['urgent'] == true,
    ) ||
    expenses.any(
      (item) =>
          const [
            'veterinary',
            'medicine',
          ].contains(item.publicData['category']) &&
          (item.privateData['urgency_reason'] as String? ?? '')
              .trim()
              .isNotEmpty,
    );

String? validUrgencyPhoto(String? path, List<Map<String, dynamic>> files) =>
    path != null &&
        files.any((file) => file['role'] == 'public' && file['path'] == path)
    ? path
    : null;

/// Uses the existing case gallery without removing or replacing its photos.
class UrgencyPhotoChoices extends StatelessWidget {
  const UrgencyPhotoChoices({super.key, required this.files});
  final List<Map<String, dynamic>> files;
  @override
  Widget build(BuildContext context) {
    final full = files.where((file) => file['role'] == 'public').length >= 6;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Foto de urgencia',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          if (full)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Ya tienes 6 fotos. Elige una foto del caso o retira una para añadir otra.',
              ),
            ),
          ListTile(
            enabled: !full,
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: full ? null : () => Navigator.pop(context, '__camera'),
          ),
          ListTile(
            enabled: !full,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            onTap: full ? null : () => Navigator.pop(context, '__gallery'),
          ),
          for (var i = 0; i < files.length; i++)
            if (files[i]['role'] == 'public')
              ListTile(
                title: Text('Usar foto del caso ${i + 1}'),
                onTap: () => Navigator.pop(context, files[i]['path'] as String),
              ),
        ],
      ),
    );
  }
}

class UrgencyComplement extends ConsumerStatefulWidget {
  const UrgencyComplement({
    super.key,
    required this.record,
    required this.eligible,
    required this.photoPath,
    required this.onPhoto,
    required this.onRemovePhoto,
    required this.onSave,
    this.needsSave = false,
    this.enabled = true,
    this.photoMutationsEnabled = true,
    this.onActivityChanged,
  });
  final RescueRecord? record;
  final bool eligible, needsSave, enabled, photoMutationsEnabled;
  final String? photoPath;
  final Future<void> Function() onPhoto, onRemovePhoto, onSave;
  final ValueChanged<bool>? onActivityChanged;
  @override
  ConsumerState<UrgencyComplement> createState() => _UrgencyComplementState();
}

class _UrgencyComplementState extends ConsumerState<UrgencyComplement> {
  Future<VideoPolicy>? request;
  String? scope, error;
  bool videoSelected = false, busy = false;
  bool videoActive = false;
  bool cancellationUncertain = false;
  List<Map<String, dynamic>> pendingCancellations = [];
  bool? reportedActivity;
  bool activityNotificationScheduled = false;
  void reportActivity(bool active) {
    if (widget.onActivityChanged == null ||
        reportedActivity == active ||
        activityNotificationScheduled) {
      return;
    }
    activityNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      activityNotificationScheduled = false;
      if (!mounted) return;
      final active =
          widget.eligible && (busy || videoActive || cancellationUncertain);
      if (reportedActivity == active) return;
      reportedActivity = active;
      widget.onActivityChanged?.call(active);
    });
  }

  void videoActivityChanged(bool active) {
    if (mounted && videoActive != active) {
      setState(() => videoActive = active);
    }
  }

  void refresh() {
    if (mounted) setState(() => request = null);
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No pudimos cambiar el complemento. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          request = null;
        });
      }
    }
  }

  Future<void> mutatePhoto(Future<void> Function() action) async {
    if (!widget.enabled || !widget.photoMutationsEnabled || busy) return;
    await act(action);
  }

  Future<void> cancelVideo(
    VideoRepository repository,
    List<Map<String, dynamic>> assets,
  ) async {
    final identity = repository.identity();
    if (identity == null) throw const VideoFailure('identity_changed');
    if (!cancellationUncertain) {
      pendingCancellations = assets.map(Map<String, dynamic>.from).toList();
    }
    if (mounted) setState(() => cancellationUncertain = true);
    for (final item in pendingCancellations) {
      final task = VideoUploadTask(
        parentId: widget.record!.id,
        parentVersion: item['parent_version'] as int,
        purpose: 'urgency',
        identity: identity,
        requestKey: item['request_key'] as String,
      )..assetId = item['id'] as String;
      await repository.cancel(task);
    }
    if (mounted) {
      setState(() {
        videoSelected = false;
        videoActive = false;
        cancellationUncertain = false;
        pendingCancellations = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    reportActivity(
      widget.eligible && (busy || videoActive || cancellationUncertain),
    );
    if (!widget.eligible ||
        (widget.record != null && widget.record!.kind != 'case')) {
      return const SizedBox.shrink();
    }
    ref.watch(rescueVideoIdentityProvider);
    final repository = ref.watch(rescueVideosRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    final record = widget.record;
    if (record == null || widget.needsSave) {
      return RescueVideoSection(
        record: record,
        purposes: const ['urgency'],
        needsSave: true,
        onSave: widget.onSave,
        enabled: widget.enabled,
        onActivityChanged: videoActivityChanged,
      );
    }
    final current =
        '${repository.identity()}:${record.id}:${record.version}:${widget.photoPath}';
    if (request == null || scope != current) {
      scope = current;
      request = repository.policy(record.id);
    }
    return FutureBuilder<VideoPolicy>(
      key: ValueKey(current),
      future: request,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(
            onPressed: refresh,
            child: const Text('Reintentar complemento de urgencia'),
          );
        }
        final policy = snapshot.data;
        if (policy == null || !policy.enabled || !policy.urgencyAllowed) {
          return const SizedBox.shrink();
        }
        final active = policy.assets
            .where(
              (asset) =>
                  asset['purpose'] == 'urgency' &&
                  !const [
                    'canceled',
                    'deleted',
                  ].contains(asset['technical_state']),
            )
            .toList();
        final photo = widget.photoPath;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Complemento de urgencia (opcional)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Puedes añadir una foto o un video para explicar esta urgencia. Elige sólo uno; se revisa antes de publicarse.',
            ),
            if (error != null) Text(error!),
            if (photo != null) ...[
              RescuePublicPhoto(photo, height: 160),
              const Text(
                'La foto también está en Fotos del caso. Quitar el complemento conserva esa foto en la galería.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed:
                        busy || !widget.enabled || !widget.photoMutationsEnabled
                        ? null
                        : () => mutatePhoto(widget.onPhoto),
                    child: const Text('Reemplazar foto de urgencia'),
                  ),
                  TextButton(
                    onPressed:
                        busy || !widget.enabled || !widget.photoMutationsEnabled
                        ? null
                        : () => mutatePhoto(widget.onRemovePhoto),
                    child: const Text('Quitar complemento de foto'),
                  ),
                ],
              ),
            ] else if (videoSelected ||
                active.isNotEmpty ||
                cancellationUncertain) ...[
              RescueVideoSection(
                record: record,
                purposes: const ['urgency'],
                showHeading: false,
                enabled: widget.enabled && !busy && !cancellationUncertain,
                onChanged: refresh,
                onActivityChanged: videoActivityChanged,
              ),
              TextButton(
                onPressed: busy || !widget.enabled
                    ? null
                    : () => act(() => cancelVideo(repository, active)),
                child: const Text('Quitar video y cambiar a foto'),
              ),
            ] else
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        busy || !widget.enabled || !widget.photoMutationsEnabled
                        ? null
                        : () => mutatePhoto(widget.onPhoto),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Añadir foto de urgencia'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !widget.enabled
                        ? null
                        : () => setState(() => videoSelected = true),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Añadir video de urgencia'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
