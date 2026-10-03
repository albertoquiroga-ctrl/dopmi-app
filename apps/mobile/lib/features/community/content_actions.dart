import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui.dart';

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

Future<(String, String)?> showContentReportSheet(
  BuildContext context, {
  String title = 'Reportar contenido',
}) => showDialog<(String, String)>(
  context: context,
  barrierColor: const Color(0x7a15110d),
  animationStyle: AnimationStyle.noAnimation,
  builder: (_) => _ContentReportSheet(title: title),
);

class _ContentReportSheet extends StatefulWidget {
  const _ContentReportSheet({required this.title});
  final String title;
  @override
  State<_ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<_ContentReportSheet> {
  final details = TextEditingController();
  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 361,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cuéntanos por qué quieres reportar este perfil. Revisaremos la información para mantener segura a la manada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.55, color: muted),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Motivo del reporte',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: details,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Describe el motivo del reporte',
                    counterText: '',
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xffe6e2dd)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: ink,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: details.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, (
                          'other',
                          details.text.trim(),
                        )),
                  child: const Text(
                    'Enviar reporte',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Color(0xffe6e2dd)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 0,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 22, color: muted),
            ),
          ),
        ],
      ),
    ),
  );
}
