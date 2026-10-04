import 'package:flutter/material.dart';

import '../adoption/community_repository.dart';
import 'rescue_fields.dart';
import 'rescue_repository.dart';

class ExpenseReview extends StatelessWidget {
  const ExpenseReview({
    super.key,
    required this.values,
    required this.files,
    required this.onOpen,
    this.onEditInformation,
    this.onEditPrivateInformation,
    this.onEditFiles,
    this.readOnly = false,
  });
  final bool readOnly;
  final Map<String, String> values;
  final List<Json> files;
  final ValueChanged<int> onOpen;
  final VoidCallback? onEditInformation, onEditPrivateInformation, onEditFiles;

  Widget heading(String text, VoidCallback? onEdit) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xff15110d),
          ),
        ),
      ),
      if (onEdit != null)
        Tooltip(
          message: 'Editar $text',
          child: TextButton(
            onPressed: onEdit,
            child: const Text(
              'Editar',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        readOnly ? 'Datos del gasto' : 'Revisa antes de enviar',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: Color(0xff15110d),
        ),
      ),
      const SizedBox(height: 16),
      for (final private in [false, true]) ...[
        heading(
          private
              ? 'Solo para revisión privada'
              : 'Información para publicación',
          private ? onEditPrivateInformation : onEditInformation,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x80f0eff8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final field in rescueFields['expense']!.where(
                (f) => f.private == private,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.55,
                          color: Color(0xff554e48),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.options?[values[field.key]] ??
                            ((values[field.key] ?? '').isEmpty
                                ? 'Sin capturar'
                                : values[field.key]!),
                        key: ValueKey('expense-review-${field.key}'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.55,
                          color: Color(0xff15110d),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      heading('Comprobantes y fotos', onEditFiles),
      if (files.isEmpty)
        const Text(
          'Sin archivos adjuntos',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xff554e48),
          ),
        ),
      for (var i = 0; i < files.length; i++)
        TextButton.icon(
          onPressed: () => onOpen(i),
          icon: const Icon(Icons.description_outlined, size: 20),
          label: Text(
            '${evidenceRoles[files[i]['role']] ?? 'Archivo'} ${i + 1} · ${files[i]['role'] == 'public' ? 'Pública después de aprobación' : 'Privado'}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        'El equipo revisará la información pública, los comprobantes privados y la evidencia antes de aprobar el gasto.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.55,
          color: Color(0xff554e48),
        ),
      ),
    ],
  );
}
