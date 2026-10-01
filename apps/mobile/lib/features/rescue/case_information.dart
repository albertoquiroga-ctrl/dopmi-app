import 'package:flutter/material.dart';

import '../adoption/publication_frame.dart';
import 'rescue_fields.dart';

class CaseInformation extends StatelessWidget {
  const CaseInformation({
    super.key,
    required this.controllers,
    required this.enabled,
    required this.onChanged,
  });
  final Map<String, TextEditingController> controllers;
  final bool enabled;
  final VoidCallback onChanged;

  void choose(String key, String value) {
    controllers[key]!.text = value;
    onChanged();
  }

  Widget field(RescueField field) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          field.label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: Color(0xff151423),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: field.label,
          child: TextField(
            key: ValueKey('case-field-${field.key}'),
            controller: controllers[field.key],
            enabled: enabled,
            maxLength: field.max,
            maxLines: field.lines,
            keyboardType: field.lines > 1
                ? TextInputType.multiline
                : TextInputType.text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 1.55,
              color: Color(0xff151423),
            ),
            decoration: InputDecoration(
              hintText: field.key == 'age' ? 'ej. 3 meses' : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xffeaeaf3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xffeaeaf3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xff7841f2)),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        if (field.key == 'age')
          const Text(
            'Puede ser aproximada.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.55,
              color: Color(0xff616174),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Información básica',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w600,
          color: Color(0xff151423),
        ),
      ),
      const SizedBox(height: 16),
      field(rescueFields['case']!.first),
      PublicationChoiceRow(
        label: 'Sexo',
        options: const {'male': 'Macho', 'female': 'Hembra'},
        value: controllers['sex']!.text,
        onChanged: enabled ? (value) => choose('sex', value) : null,
      ),
      Semantics(
        selected: controllers['sex']!.text == 'unknown',
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? () => choose('sex', 'unknown') : null,
            icon: Icon(
              controllers['sex']!.text == 'unknown'
                  ? Icons.check
                  : Icons.help_outline,
              size: 16,
            ),
            label: const Text(
              'Por determinar',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      PublicationChoiceRow(
        label: 'Especie',
        options: const {'dog': 'Perro', 'cat': 'Gato'},
        value: controllers['species']!.text,
        onChanged: enabled ? (value) => choose('species', value) : null,
      ),
      const SizedBox(height: 16),
      for (final entry in rescueFields['case']!.where(
        (f) => !['pet_name', 'sex', 'species', 'need'].contains(f.key),
      ))
        field(entry),
      const Text(
        'Publica sólo ciudad y estado. No incluyas domicilios particulares ni teléfonos en la historia.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.55,
          color: Color(0xff616174),
        ),
      ),
    ],
  );
}
