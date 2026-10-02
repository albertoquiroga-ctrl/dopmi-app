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

Future<(String, String)?> showContentReportSheet(BuildContext context) =>
    showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ContentReportSheet(),
    );

class _ContentReportSheet extends StatefulWidget {
  const _ContentReportSheet();
  @override
  State<_ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<_ContentReportSheet> {
  String reason = 'incorrect';
  final details = TextEditingController();
  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reportar contenido',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: reason,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Motivo'),
          items:
              const {
                    'incorrect': 'Información incorrecta',
                    'unsafe': 'Riesgo o maltrato',
                    'fraud': 'Posible fraude',
                    'privacy': 'Datos personales expuestos',
                    'other': 'Otro',
                  }.entries
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => reason = value ?? reason),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: details,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Cuéntanos qué sucede'),
        ),
        ActionButton(
          'Enviar reporte',
          onPressed: () =>
              Navigator.pop(context, (reason, details.text.trim())),
        ),
      ],
    ),
  );
}
