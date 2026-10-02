import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui.dart';

class HelpSupportDialog extends StatefulWidget {
  const HelpSupportDialog({
    super.key,
    required this.topics,
    required this.initialTopic,
    this.openMail,
  });
  final List<String> topics;
  final int initialTopic;
  final Future<bool> Function(Uri)? openMail;

  @override
  State<HelpSupportDialog> createState() => _HelpSupportDialogState();
}

class _HelpSupportDialogState extends State<HelpSupportDialog> {
  late int topic = widget.initialTopic;
  final caseName = TextEditingController(), message = TextEditingController();
  bool busy = false;
  String? notice;

  @override
  void dispose() {
    caseName.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> continueInMail() async {
    if (busy || message.text.trim().isEmpty) return;
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
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 361),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Contactar a soporte',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            field(
              'Tema',
              DropdownButtonFormField<int>(
                initialValue: topic,
                isExpanded: true,
                items: [
                  for (var i = 0; i < widget.topics.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(widget.topics[i], softWrap: true),
                    ),
                ],
                selectedItemBuilder: (_) => widget.topics
                    .map((item) => Text(item, overflow: TextOverflow.ellipsis))
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => setState(() => topic = value ?? topic),
              ),
            ),
            const SizedBox(height: 12),
            field(
              'Caso relacionado (opcional)',
              TextField(
                controller: caseName,
                enabled: !busy,
                decoration: const InputDecoration(hintText: 'Ej. Rocky, Luna…'),
              ),
            ),
            const SizedBox(height: 12),
            field(
              'Mensaje',
              TextField(
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
            const SizedBox(height: 12),
            if (notice != null) ...[
              Text(notice!, style: const TextStyle(fontSize: 14, color: muted)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              style: FilledButton.styleFrom(
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
                  : continueInMail,
              child: const Text(
                'Continuar en correo',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
