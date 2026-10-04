import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui.dart';
import '../../core/reference_focus_outline.dart';
import '../../core/media/media_store.dart';
import 'support_repository.dart';

Future<void> showHelpSupportDialog(
  BuildContext context, {
  required List<String> topics,
  required int initialTopic,
  SupportRepository? repository,
  Future<Uint8List?> Function()? pickImage,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Cerrar contacto a soporte',
  barrierColor: const Color(0xff15110d).withValues(alpha: .48),
  transitionDuration: Duration.zero,
  pageBuilder: (_, _, _) => HelpSupportDialog(
    topics: topics,
    initialTopic: initialTopic,
    repository: repository,
    pickImage: pickImage,
  ),
);

class HelpSupportDialog extends StatefulWidget {
  const HelpSupportDialog({
    super.key,
    required this.topics,
    required this.initialTopic,
    this.openMail,
    this.repository,
    this.pickImage,
  });
  final List<String> topics;
  final int initialTopic;
  final Future<bool> Function(Uri)? openMail;
  final SupportRepository? repository;
  final Future<Uint8List?> Function()? pickImage;

  @override
  State<HelpSupportDialog> createState() => _HelpSupportDialogState();
}

class _HelpSupportDialogState extends State<HelpSupportDialog> {
  late int topic = widget.initialTopic;
  final caseName = TextEditingController(), message = TextEditingController();
  bool busy = false;
  bool sending = false;
  bool picking = false;
  Uint8List? attachment;
  int attachmentRevision = 0;
  String? attachmentPath;
  String? notice;
  bool received = false;
  bool mailFallbackAvailable = false;
  String? requestId, requestContent;
  static const topicIds = [
    'support_rules',
    'contribute',
    'guardian',
    'adopt',
    'verification',
    'publish_cases',
    'funds_evidence',
    'account',
    'trust_safety',
  ];

  Future<void> chooseImage() async {
    if (busy || received) return;
    setState(() {
      busy = true;
      picking = true;
      notice = null;
    });
    try {
      final Uint8List? bytes;
      if (widget.pickImage != null) {
        bytes = await widget.pickImage!();
      } else {
        final selected = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          requestFullMetadata: false,
        );
        bytes = await selected?.readAsBytes();
      }
      if (bytes == null || !mounted) return;
      final prepared = await compute(prepareMedia, (
        MediaPurpose.supportAttachment,
        bytes,
      ));
      if (!mounted) return;
      setState(() {
        attachment = prepared.bytes;
        attachmentRevision++;
        attachmentPath = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'No pudimos abrir esa imagen. Elige una foto de hasta 5 MB.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          picking = false;
        });
      }
    }
  }

  Future<void> send() async {
    if (busy || received || message.text.trim().isEmpty) return;
    final content = jsonEncode([
      topic,
      caseName.text.trim(),
      message.text.trim(),
      attachmentRevision,
    ]);
    if (requestContent != content) {
      requestContent = content;
      requestId = const Uuid().v4();
      attachmentPath = null;
    }
    setState(() {
      busy = true;
      sending = true;
      notice = null;
    });
    try {
      final repository = widget.repository ?? SupportRepository.supabase();
      if (attachment != null && attachmentPath == null) {
        attachmentPath = await repository.uploadAttachment(
          requestId!,
          attachment!,
        );
        if (!mounted) return;
      }
      await repository.submit(
        requestId: requestId!,
        topic: topicIds[topic],
        caseName: caseName.text,
        message: message.text,
        attachmentPath: attachmentPath,
      );
      if (mounted) setState(() => received = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          mailFallbackAvailable = true;
          notice = 'No pudimos confirmar la recepción. Tu mensaje sigue aquí; vuelve a intentar.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    caseName.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> continueInMail() async {
    if (busy || message.text.trim().isEmpty || attachment != null) return;
    setState(() {
      busy = true;
      notice = null;
    });
    final body =
        'Tema: ${widget.topics[topic]}\n'
        '${caseName.text.trim().isEmpty ? '' : 'Caso relacionado: ${caseName.text.trim()}\n'}\n'
        '${message.text.trim()}';
    try {
      final opened = await (widget.openMail ?? (uri) => launchUrl(uri))(
        Uri(
          scheme: 'mailto',
          path: 'soporte@dopmi.org',
          query:
              'subject=${Uri.encodeComponent('Ayuda con Dopmi: ${widget.topics[topic]}')}'
              '&body=${Uri.encodeComponent(body)}',
        ),
      );
      if (mounted) {
        setState(
          () => notice = opened
              ? 'Completa el envío desde tu aplicación de correo.'
              : 'No pudimos abrir tu correo. Tu mensaje sigue aquí; puedes escribir a soporte@dopmi.org.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice = 'No pudimos abrir tu correo. Tu mensaje sigue aquí; puedes escribir a soporte@dopmi.org.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 16 / 13,
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffe6e2dd)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffe6e2dd)),
        ),
      ),
      textTheme: Theme.of(context).textTheme.copyWith(
        bodyLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ink,
          height: 1.25,
        ),
      ),
    ),
    child: PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          key: const ValueKey('help-support-card'),
          constraints: const BoxConstraints(maxWidth: 361),
          child: Stack(
            children: [
              SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: MediaQuery.textScalerOf(context).scale(22) > 22
                            ? 0
                            : 24,
                      ),
                      child: Text(
                        received
                            ? 'Recibimos tu mensaje.'
                            : 'Contactar a soporte',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (received) ...[
                      const Text(
                        'Tu solicitud quedó registrada para el equipo de soporte. Podemos responder al correo de tu cuenta.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: yellow,
                          foregroundColor: const Color(0xff0d0d0d),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Entendido'),
                      ),
                    ] else ...[
                      field(
                        'Tema',
                        DropdownButtonFormField<int>(
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: ink,
                            height: 1.25,
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10.5,
                            ),
                          ),
                          initialValue: topic,
                          itemHeight: null,
                          isExpanded: true,
                          items: [
                            for (var i = 0; i < widget.topics.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(widget.topics[i], softWrap: true),
                              ),
                          ],
                          selectedItemBuilder: (_) => widget.topics
                              .map((item) => Text(item, softWrap: true))
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) =>
                                    setState(() => topic = value ?? topic),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Caso relacionado',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ink,
                              height: 16 / 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '(opcional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: muted,
                              height: 16 / 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ReferenceFocusOutline(
                            radius: 14,
                            showForTouchFocus: true,
                            child: TextField(
                              controller: caseName,
                              enabled: !busy,
                              decoration: const InputDecoration(
                                hintText: 'Ej. Rocky, Luna…',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      field(
                        'Mensaje',
                        ReferenceFocusOutline(
                          radius: 14,
                          showForTouchFocus: true,
                          child: TextField(
                            controller: message,
                            enabled: !busy,
                            minLines: 4,
                            maxLines: null,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Cuéntanos qué necesitas',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (notice != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            notice!,
                            style: const TextStyle(fontSize: 14, color: muted),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ink,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xffe6e2dd)),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: busy ? null : chooseImage,
                        child: Text(
                          attachment == null
                              ? 'Adjuntar imagen (opcional)'
                              : 'Cambiar imagen',
                        ),
                      ),
                      if (attachment != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xffe6e2dd)),
                          ),
                          child: Image.memory(
                            attachment!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel: 'Adjunto seleccionado',
                          ),
                        ),
                        if (mailFallbackAvailable)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    attachment = null;
                                    attachmentPath = null;
                                    attachmentRevision++;
                                  }),
                            child: const Text('Quitar imagen'),
                          ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: Colors.transparent,
                          animationDuration: Duration.zero,
                          backgroundColor: yellow,
                          foregroundColor: const Color(0xff0d0d0d),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          minimumSize: const Size(0, 48),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: busy || message.text.trim().isEmpty
                            ? null
                            : send,
                        child: busy
                            ? Semantics(
                                label: picking
                                    ? 'Abriendo galería'
                                    : sending
                                    ? 'Enviando mensaje'
                                    : 'Abriendo correo',
                                child: const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Text('Enviar mensaje'),
                      ),
                      if (mailFallbackAvailable && attachment == null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            minimumSize: const Size(0, 48),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed:
                              busy ||
                                  message.text.trim().isEmpty ||
                                  attachment != null
                              ? null
                              : continueInMail,
                          child: const Text(
                            'Continuar en correo',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 5.28125,
                child: IconButton(
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(overlayColor: Colors.transparent),
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                  icon: const ExcludeSemantics(
                    child: Text(
                      '×',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
