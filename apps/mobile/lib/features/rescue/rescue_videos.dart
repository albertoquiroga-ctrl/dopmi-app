import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../core/media/video_repository.dart';
import '../../core/media/moderated_video.dart';
import '../../core/media/video_upload.dart';
import 'rescue_repository.dart';

/// Configured with the authenticated production client by the app bootstrap.
/// Absence means unavailable, never simulated media or local authorization.
final rescueVideosRepositoryProvider = Provider<VideoRepository?>(
  (ref) => null,
);
final rescueVideoIdentityProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(rescueVideosRepositoryProvider);
  yield repository?.identity();
  final changes = repository?.identityChanges;
  if (changes != null) {
    yield* changes.map((_) => repository?.identity()).distinct();
  }
});

const publicRescueVideoPurposes = {
  'thanks',
  'urgency',
  'public_update',
  'farewell',
};
List<String> publicRescueVideoIds(
  List<Map<String, dynamic>> values,
  String parentId,
) => values
    .where(
      (value) =>
          value['parent_id'] == parentId &&
          publicRescueVideoPurposes.contains(value['purpose']),
    )
    .map((value) => value['id'])
    .whereType<String>()
    .where((id) => id.isNotEmpty)
    .toSet()
    .toList();

class PublicRescueVideos extends ConsumerStatefulWidget {
  const PublicRescueVideos(this.parentId, {super.key});
  final String parentId;
  @override
  ConsumerState<PublicRescueVideos> createState() => _PublicRescueVideosState();
}

class _PublicRescueVideosState extends ConsumerState<PublicRescueVideos> {
  Future<List<String>>? request;
  String? scope;
  @override
  Widget build(BuildContext context) {
    ref.watch(rescueVideoIdentityProvider);
    final repository = ref.watch(rescueVideosRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    final current = '${repository.identity()}:${widget.parentId}';
    if (request == null || scope != current) {
      scope = current;
      request = repository
          .publicVideos(widget.parentId)
          .then((items) => publicRescueVideoIds(items, widget.parentId));
    }
    return FutureBuilder<List<String>>(
      key: ValueKey(current),
      future: request,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(() => request = null),
            child: const Text('Reintentar videos públicos'),
          );
        }
        final ids = snapshot.data;
        if (ids == null || ids.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Videos del caso',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            for (final id in ids)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ModeratedVideo(
                  key: ValueKey('$current:$id'),
                  repository: repository,
                  assetId: id,
                  autoplay: false,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Own media always uses a persisted rescue ID/version and server policy.
/// Private evidence and an explicitly public update are distinct upload tasks.
class RescueVideoSection extends ConsumerStatefulWidget {
  const RescueVideoSection({
    super.key,
    required this.record,
    required this.purposes,
    this.needsSave = false,
    this.onSave,
    this.enabled = true,
    this.onChanged,
    this.showHeading = true,
  });
  final RescueRecord? record;
  final List<String> purposes;
  final bool needsSave, enabled, showHeading;
  final Future<void> Function()? onSave;
  final VoidCallback? onChanged;
  @override
  ConsumerState<RescueVideoSection> createState() => _RescueVideoSectionState();
}

class _RescueVideoSectionState extends ConsumerState<RescueVideoSection> {
  Future<VideoPolicy>? request;
  String? requestScope;
  String? previewScope;
  final suspendedPreviewPurposes = <String>{};
  final canceledPreviewIds = <String>{};
  bool saving = false;
  String? saveError;
  Future<void> saveDraft() async {
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await widget.onSave?.call();
    } catch (_) {
      if (mounted) {
        setState(
          () => saveError = 'No pudimos guardar el borrador. Intenta de nuevo antes de cargar el video.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(rescueVideoIdentityProvider);
    final repository = ref.watch(rescueVideosRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    final record = widget.record;
    if (record == null || widget.needsSave) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text('Videos del caso'),
          const Text(
            'Primero guarda el borrador para vincular el video con esta versión del expediente.',
          ),
          if (saveError != null) Text(saveError!),
          OutlinedButton(
            onPressed: !widget.enabled || saving || widget.onSave == null
                ? null
                : saveDraft,
            child: Text(
              saving ? 'Guardando…' : 'Guardar borrador para añadir videos',
            ),
          ),
        ],
      );
    }
    final actor = repository.identity();
    final current = '$actor:${record.id}:${record.version}';
    if (previewScope != current) {
      previewScope = current;
      suspendedPreviewPurposes.clear();
      canceledPreviewIds.clear();
    }
    if (request == null || requestScope != current) {
      requestScope = current;
      request = repository.policy(record.id);
    }
    return FutureBuilder<VideoPolicy>(
      key: ValueKey(current),
      future: request,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No pudimos consultar la disponibilidad de videos.'),
              TextButton(
                onPressed: () => setState(() => request = null),
                child: const Text('Reintentar disponibilidad de videos'),
              ),
            ],
          );
        }
        final policy = snapshot.data;
        if (policy == null || policy.enabled != true) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            for (final purpose in widget.purposes) ...[
              if (purpose == 'thanks' && policy.thanksRequired == true)
                const Text(
                  'Para enviar este nuevo caso, carga un video de agradecimiento y espera a que termine de procesarse. El equipo lo revisará antes de publicarlo.',
                ),
              if (purpose == 'expense_evidence')
                const Text(
                  'Este video es evidencia privada. No se publicará ni sustituye el comprobante del gasto.',
                ),
              if (purpose == 'public_update')
                const Text(
                  'Este video se propone para publicación. No uses comprobantes ni información privada.',
                ),
              if (purpose == 'farewell')
                const Text(
                  'La despedida es opcional. Compartirla no reabre el caso ni cambia los apoyos.',
                ),
              for (final value in policy.assets.where(
                (item) =>
                    item['purpose'] == purpose &&
                    !canceledPreviewIds.contains(item['id']) &&
                    !suspendedPreviewPurposes.contains(purpose),
              )) ...[
                if (value['matches_current_content'] == false)
                  const Text(
                    'Este video corresponde a una versión anterior del expediente. No acredita el contenido vigente.',
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${widget.showHeading ? 'Video ${videoPurposeLabel(purpose)}: ' : ''}${videoStateLabel(value['technical_state'] as String?)} · ${videoReviewLabel(value['moderation_state'] as String?)}',
                  ),
                ),
                if (value['technical_state'] == 'ready' &&
                    value['moderation_state'] != 'stale' &&
                    value['matches_current_content'] != false &&
                    value['id'] is String)
                  ModeratedVideo(
                    key: ValueKey('own:${value['id']}'),
                    repository: repository,
                    assetId: value['id'] as String,
                    autoplay: false,
                    semanticLabel: purpose == 'expense_evidence'
                        ? 'Evidencia privada en video'
                        : 'Vista previa del video del caso',
                  ),
              ],
              AbsorbPointer(
                absorbing: !widget.enabled,
                child: VideoUpload(
                  key: ValueKey('$current:$purpose'),
                  repository: repository,
                  parentId: record.id,
                  parentVersion: record.version,
                  purpose: purpose,
                  initialAssets: policy.assets
                      .where(
                        (asset) => asset['matches_current_content'] != false,
                      )
                      .toList(),
                  label: videoPurposeLabel(purpose),
                  showHeading: widget.showHeading,
                  onCancellationPendingChanged: (assetId) {
                    if (assetId == null ||
                        !mounted ||
                        requestScope != current ||
                        repository.identity() != actor) {
                      return;
                    }
                    setState(() {
                      suspendedPreviewPurposes.add(purpose);
                      canceledPreviewIds.add(assetId);
                    });
                  },
                  onChanged: (value) {
                    if (!mounted ||
                        requestScope != current ||
                        repository.identity() != actor) {
                      return;
                    }
                    // Keep stale policy previews hidden after a confirmed cancel.
                    // A subsequent upload has its own asset and refreshes policy.
                    if (value != null) suspendedPreviewPurposes.remove(purpose);
                    widget.onChanged?.call();
                    if (mounted) setState(() => request = null);
                  },
                  onReady: (_) {},
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }
}

String videoPurposeLabel(String purpose) => switch (purpose) {
  'thanks' => 'Agradecimiento',
  'urgency' => 'Complemento de urgencia (opcional)',
  'expense_evidence' => 'Evidencia privada en video (opcional)',
  'public_update' => 'Avance público en video (opcional)',
  'farewell' => 'Despedida (opcional)',
  _ => 'Video',
};
String videoStateLabel(String? state) => switch (state) {
  'ready' => 'Procesado',
  'processing' => 'Procesando',
  'failed' => 'No pudo procesarse',
  'canceled' => 'Cancelado',
  'deleted' => 'Eliminado',
  _ => 'Carga pendiente',
};
String videoReviewLabel(String? state) => switch (state) {
  'approved' => 'Aprobado',
  'rejected' => 'Requiere correcciones',
  'stale' => 'Corresponde a una versión anterior',
  _ => 'Pendiente de revisión',
};

class CaseVideoManager extends ConsumerStatefulWidget {
  const CaseVideoManager(this.caseId, {super.key});
  final String caseId;
  @override
  ConsumerState<CaseVideoManager> createState() => _CaseVideoManagerState();
}

class _CaseVideoManagerState extends ConsumerState<CaseVideoManager> {
  Future<RescueRecord>? request;
  String? requestScope;
  @override
  Widget build(BuildContext context) {
    ref.watch(rescueVideoIdentityProvider);
    final repository = ref.watch(rescueVideosRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    final scope = '${repository.identity()}:${widget.caseId}';
    if (request == null || requestScope != scope) {
      requestScope = scope;
      request = ref
          .read(rescueRepositoryProvider)
          .detail(widget.caseId)
          .then(
            (value) =>
                RescueRecord(Map<String, dynamic>.from(value['record'] as Map)),
          );
    }
    return FutureBuilder<RescueRecord>(
      key: ValueKey(scope),
      future: request,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(() => request = null),
            child: const Text('Reintentar videos del expediente'),
          );
        }
        final record = snapshot.data;
        if (record == null) return const SizedBox.shrink();
        return RescueVideoSection(
          record: record,
          purposes: record.status == 'closed'
              ? const ['farewell']
              : const ['public_update', 'farewell'],
        );
      },
    );
  }
}
