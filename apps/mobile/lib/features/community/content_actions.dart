import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui.dart';

Future<void> copyForSharing(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Información copiada para compartir.')),
    );
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
