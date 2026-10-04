import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui.dart';
import '../../core/dialog_close.dart';
import '../adoption/community_repository.dart';

bool _sharing = false;

Future<void> shareContent(BuildContext context, String text) async {
  if (_sharing) return;
  _sharing = true;
  try {
    final box = context.findRenderObject();
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos abrir las opciones para compartir. Intenta de nuevo.',
          ),
        ),
      );
    }
  } finally {
    _sharing = false;
  }
}

Future<void> openPublicSocialUrl(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  try {
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const FormatException('Unavailable link');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir esta red social. Intenta de nuevo.'),
        ),
      );
    }
  }
}

class _ReportSessionChanged extends FormatException {
  const _ReportSessionChanged()
    : super('Tu sesión cambió. Cierra este reporte y vuelve a abrirlo.');
}

Future<bool> reportPublicContent(
  BuildContext context,
  CommunityRepository repository, {
  required String type,
  required String id,
  required String title,
}) async {
  final actor = repository.userId;
  if (actor == null) return false;
  final result = await showContentReportSheet(
    context,
    title: title,
    onSubmit: (reason, details) async {
      if (repository.userId != actor) throw const _ReportSessionChanged();
      late final String receipt;
      try {
        receipt = await repository.report(type, id, reason, details);
      } catch (_) {
        if (repository.userId != actor) throw const _ReportSessionChanged();
        rethrow;
      }
      if (repository.userId != actor) throw const _ReportSessionChanged();
      if (!RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(receipt)) {
        throw const FormatException(
          'No pudimos confirmar el reporte. Intenta de nuevo.',
        );
      }
    },
  );
  return result != null && context.mounted && repository.userId == actor;
}

Future<(String, String)?> showContentReportSheet(
  BuildContext context, {
  String title = 'Reportar contenido',
  Future<void> Function(String reason, String details)? onSubmit,
}) => showDialog<(String, String)>(
  context: context,
  barrierColor: const Color(0x7a15110d),
  animationStyle: AnimationStyle.noAnimation,
  builder: (_) => _ContentReportSheet(title: title, onSubmit: onSubmit),
);

class _ContentReportSheet extends StatefulWidget {
  const _ContentReportSheet({required this.title, this.onSubmit});
  final String title;
  final Future<void> Function(String reason, String details)? onSubmit;
  @override
  State<_ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<_ContentReportSheet> {
  final details = TextEditingController();
  bool motiveFocused = false;
  bool busy = false;
  bool sessionChanged = false;
  String? error;
  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || sessionChanged || details.text.trim().isEmpty) return;
    final result = ('other', details.text.trim());
    if (widget.onSubmit == null) {
      Navigator.pop(context, result);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit!(result.$1, result.$2);
      if (!mounted) return;
      setState(() => busy = false);
      Navigator.pop(context, result);
    } catch (cause) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = communityError(cause);
        if (cause is _ReportSessionChanged) {
          sessionChanged = true;
          details.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 361,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cuéntanos por qué quieres reportar este perfil. Revisaremos la información para mantener segura a la manada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Motivo del reporte',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onFocusChange: (value) =>
                          setState(() => motiveFocused = value),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: motiveFocused
                              ? const [
                                  BoxShadow(
                                    color: Color(0x4d7841f2),
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: Colors.white,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: SizedBox(
                          height:
                              (MediaQuery.textScalerOf(context).scale(14) *
                                          3 *
                                          1.2 +
                                      26)
                                  .clamp(112.0, double.infinity),
                          child: TextField(
                            controller: details,
                            readOnly: busy || sessionChanged,
                            textAlignVertical: TextAlignVertical.top,
                            maxLength: 1000,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              color: ink,
                              fontWeight: FontWeight.w500,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              isDense: true,
                              hintStyle: const TextStyle(color: muted),
                              hintText: 'Describe el motivo del reporte',
                              counterText: '',
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xffe6e2dd),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xffe6e2dd),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (error != null) Notice(error!, isError: true),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: Colors.transparent,
                        animationDuration: Duration.zero,
                        backgroundColor: yellow,
                        disabledBackgroundColor: yellow.withValues(alpha: .5),
                        disabledForegroundColor: ink.withValues(alpha: .5),
                        foregroundColor: ink,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed:
                          busy || sessionChanged || details.text.trim().isEmpty
                          ? null
                          : send,
                      child: Semantics(
                        liveRegion: busy,
                        label: busy ? 'Enviando reporte' : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: busy ? 0 : 1,
                              child: const Text(
                                'Enviar reporte',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (busy)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: ink,
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: Colors.transparent,
                        animationDuration: Duration.zero,
                        foregroundColor: ink,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Color(0xffe6e2dd)),
                      ),
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DopmiDialogClose(
                onPressed: busy ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
