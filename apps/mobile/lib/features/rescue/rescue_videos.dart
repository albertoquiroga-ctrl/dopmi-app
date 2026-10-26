import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../core/media/video_repository.dart';
import '../../core/media/moderated_video.dart';
import '../../core/media/video_upload.dart';
import '../../core/design_tokens.dart';
import '../adoption/publication_frame.dart';
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

/// Metadata from the public-list endpoint, not an authorization decision.
/// Playback still obtains a fresh server-authorized lease for the asset ID.
class PublicRescueVideo {
  const PublicRescueVideo({
    required this.id,
    required this.parentId,
    required this.purpose,
    this.duration,
    this.createdAt,
  });
  final String id, parentId, purpose;
  final double? duration;
  final DateTime? createdAt;

  String get label => switch (purpose) {
    'urgency' => 'Urgencia',
    'thanks' => 'Agradecimiento',
    'public_update' => 'Avance público',
    'farewell' => 'Despedida',
    _ => 'Video del caso',
  };
  String get semanticLabel => switch (purpose) {
    'urgency' => 'Video de urgencia',
    'thanks' => 'Video de agradecimiento',
    'public_update' => 'Video de avance público',
    'farewell' => 'Video de despedida',
    _ => 'Video del caso',
  };
}

/// Keep endpoint order within each purpose; do not infer approval from owner
/// uploads or accept private evidence under a generic video label.
List<PublicRescueVideo> publicRescueVideoMetadata(
  List<Map<String, dynamic>> values,
  String parentId,
) {
  final seen = <String>{};
  final bindings = <String, (Object?, Object?)>{};
  final conflicting = <String>{};
  for (final value in values) {
    final id = value['id'];
    if (id is! String) continue;
    final binding = (value['parent_id'], value['purpose']);
    if (bindings[id] != null && bindings[id] != binding) conflicting.add(id);
    bindings.putIfAbsent(id, () => binding);
  }
  final videos = <PublicRescueVideo>[];
  for (final value in values) {
    final id = value['id'];
    final purpose = value['purpose'];
    if (value['parent_id'] != parentId ||
        !publicRescueVideoPurposes.contains(purpose) ||
        id is! String ||
        id.trim().isEmpty ||
        id != id.trim() ||
        conflicting.contains(id) ||
        !seen.add(id)) {
      continue;
    }
    videos.add(
      PublicRescueVideo(
        id: id,
        parentId: parentId,
        purpose: purpose as String,
        duration: value['duration'] is num
            ? (value['duration'] as num).toDouble()
            : null,
        createdAt: value['created_at'] is String
            ? DateTime.tryParse(value['created_at'] as String)
            : null,
      ),
    );
  }
  return videos;
}

/// Compatibility for existing callers that only need IDs, in endpoint order.
List<String> publicRescueVideoIds(
  List<Map<String, dynamic>> values,
  String parentId,
) => publicRescueVideoMetadata(
  values,
  parentId,
).map((video) => video.id).toList();

class PublicRescueVideos extends ConsumerStatefulWidget {
  const PublicRescueVideos(this.parentId, {super.key});
  final String parentId;
  @override
  ConsumerState<PublicRescueVideos> createState() => _PublicRescueVideosState();
}

class _PublicRescueVideosState extends ConsumerState<PublicRescueVideos> {
  Future<List<PublicRescueVideo>>? request;
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
          .then((items) => publicRescueVideoMetadata(items, widget.parentId));
    }
    return FutureBuilder<List<PublicRescueVideo>>(
      key: ValueKey(current),
      future: request,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(() => request = null),
            child: const Text('Reintentar videos públicos'),
          );
        }
        final videos = snapshot.data;
        if (videos == null || videos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Videos del caso',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            for (final video in videos)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(video.label),
                    const SizedBox(height: 6),
                    ModeratedVideo(
                      key: ValueKey('$current:${video.id}'),
                      repository: repository,
                      assetId: video.id,
                      autoplay: false,
                      semanticLabel: video.semanticLabel,
                    ),
                  ],
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
    this.onContinueChanged,
    this.onActivityChanged,
    this.showHeading = true,
    this.publicationThanks = false,
  });
  final RescueRecord? record;
  final List<String> purposes;
  final bool needsSave, enabled, showHeading, publicationThanks;
  final Future<void> Function()? onSave;
  final VoidCallback? onChanged;
  final ValueChanged<bool>? onContinueChanged, onActivityChanged;
  @override
  ConsumerState<RescueVideoSection> createState() => _RescueVideoSectionState();
}

class _RescueVideoSectionState extends ConsumerState<RescueVideoSection> {
  Future<VideoPolicy>? request;
  String? requestScope;
  String? previewScope;
  VideoPolicy? lastPolicy;
  final uploadActivity = <String, bool>{};
  (bool, bool)? reportedStatus, pendingStatus;
  bool statusNotificationScheduled = false;
  final suspendedPreviewPurposes = <String>{};
  final canceledPreviewIds = <String>{};
  bool saving = false;
  String? saveError;
  void reportStatus(bool canContinue, bool active) {
    pendingStatus = (canContinue, active);
    if (reportedStatus == pendingStatus || statusNotificationScheduled) return;
    statusNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      statusNotificationScheduled = false;
      if (!mounted || pendingStatus == reportedStatus) return;
      final status = pendingStatus!;
      reportedStatus = status;
      widget.onContinueChanged?.call(status.$1);
      widget.onActivityChanged?.call(status.$2);
    });
  }

  void refreshPolicy() {
    if (mounted) setState(() => request = null);
  }

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

  Future<void> showThanksHelp() => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      '¿Por qué subir este video?',
                      style: TextStyle(
                        fontSize: 22,
                        height: 28 / 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff151423),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final item in const [
                (
                  'Confianza:',
                  ' quienes apoyan quieren ver que su ayuda llega a la mascota.',
                ),
                (
                  'Gratitud:',
                  ' un mensaje breve refuerza la comunidad y motiva a seguir donando.',
                ),
                (
                  'Qué mostrar:',
                  ' debe salir la mascota; es opcional que aparezcas tú en el video.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: item.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: item.$2),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: DopmiTokens.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'Hasta 60 segundos. Primero eliges o grabas el video y lo revisas en tu teléfono. La carga comienza al confirmar Subir video en la revisión. Debe terminar de procesarse antes de enviar el caso; el equipo lo revisará antes de publicarlo.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: Color(0xff616174),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: FilledButton.styleFrom(
                  backgroundColor: DopmiTokens.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(rescueVideoIdentityProvider);
    final repository = ref.watch(rescueVideosRepositoryProvider);
    if (repository == null) {
      reportStatus(false, false);
      return widget.onContinueChanged == null
          ? const SizedBox.shrink()
          : const Text('No pudimos consultar la disponibilidad de videos.');
    }
    final record = widget.record;
    if (record == null || widget.needsSave) {
      reportStatus(false, uploadActivity.values.any((active) => active));
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
      lastPolicy = null;
      uploadActivity.clear();
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
        final policyResolved =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            snapshot.hasData;
        if (policyResolved &&
            !(uploadActivity.values.any((active) => active) &&
                snapshot.data?.enabled == false &&
                lastPolicy?.enabled == true)) {
          lastPolicy = snapshot.data;
        }
        final policy = lastPolicy;
        final active = widget.purposes.any(
          (purpose) => uploadActivity[purpose] ?? (policy?.enabled == true),
        );
        final thanksReady =
            policy?.assets.any(
              (asset) =>
                  asset['parent_id'] == record.id &&
                  asset['purpose'] == 'thanks' &&
                  asset['id'] is String &&
                  (asset['id'] as String).isNotEmpty &&
                  asset['technical_state'] == 'ready' &&
                  asset['matches_current_content'] == true &&
                  const [
                    'pending',
                    'approved',
                  ].contains(asset['moderation_state']) &&
                  !canceledPreviewIds.contains(asset['id']) &&
                  !suspendedPreviewPurposes.contains('thanks'),
            ) ??
            false;
        reportStatus(
          policyResolved &&
              !active &&
              policy != null &&
              (!policy.enabled ||
                  !widget.purposes.contains('thanks') ||
                  !policy.thanksRequired ||
                  thanksReady),
          active,
        );
        final policyError = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No pudimos consultar la disponibilidad de videos.'),
            TextButton(
              onPressed: refreshPolicy,
              child: const Text('Reintentar disponibilidad de videos'),
            ),
          ],
        );
        if (snapshot.hasError && policy == null) {
          return policyError;
        }
        if (policy == null || policy.enabled != true) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.publicationThanks) const SizedBox(height: 16),
            if (snapshot.hasError) policyError,
            for (final purpose in widget.purposes) ...[
              if (widget.publicationThanks && purpose == 'thanks') ...[
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Video de agradecimiento'),
                      if (policy.thanksRequired)
                        const TextSpan(text: ' *')
                      else
                        const TextSpan(text: ' (opcional)'),
                    ],
                  ),
                  key: const ValueKey('publication-thanks-video-title'),
                  style: const TextStyle(
                    fontSize: 18,
                    height: 28 / 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff151423),
                  ),
                ),
                const SizedBox(height: 16),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Dile gracias a las personas que apoyan a la causa.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' En el video deberá salir la mascota. Es opcional que aparezca el/la rescatista.',
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Color(0xff616174),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (purpose == 'thanks' &&
                  policy.thanksRequired == true &&
                  !widget.publicationThanks)
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
                  showHeading:
                      widget.showHeading &&
                      !(widget.publicationThanks && purpose == 'thanks'),
                  selectionBuilder:
                      widget.publicationThanks && purpose == 'thanks'
                      ? (context, camera, gallery, label) =>
                            PublicationVideoPicker(
                              onCamera: widget.enabled ? camera : null,
                              onGallery: widget.enabled ? gallery : null,
                              galleryLabel: label == 'Elegir video'
                                  ? 'Subir video'
                                  : label,
                            )
                      : null,
                  onCancellationPendingChanged: (assetId) {
                    if (assetId == null ||
                        !mounted ||
                        requestScope != current ||
                        repository.identity() != actor) {
                      return;
                    }
                    setState(() {
                      uploadActivity[purpose] = true;
                      suspendedPreviewPurposes.add(purpose);
                      canceledPreviewIds.add(assetId);
                    });
                  },
                  onActivityChanged: (active) {
                    if (!mounted ||
                        requestScope != current ||
                        repository.identity() != actor ||
                        uploadActivity[purpose] == active) {
                      return;
                    }
                    setState(() => uploadActivity[purpose] = active);
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
                  onReady: (_) => refreshPolicy(),
                ),
              ),
              if (widget.publicationThanks && purpose == 'thanks') ...[
                const SizedBox(height: 2),
                Center(
                  child: TextButton(
                    key: const ValueKey('publication-thanks-video-help'),
                    onPressed: showThanksHelp,
                    style: TextButton.styleFrom(
                      foregroundColor: DopmiTokens.purple,
                      minimumSize: const Size(0, 40),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text('¿Por qué debo subir este video?'),
                        Icon(Icons.info_outline, size: 14),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'Hasta 60 segundos. Revisa el video antes de subirlo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: Color(0xff616174),
                  ),
                ),
              ],
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
