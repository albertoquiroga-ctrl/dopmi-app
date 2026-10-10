import 'package:flutter/material.dart';

import 'rescue_fields.dart';

/// Presentation only: the editor retains controllers, privacy and persistence.
class ExpenseField extends StatelessWidget {
  const ExpenseField({
    super.key,
    required this.field,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final RescueField field;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 17 / 14,
      color: Color(0xff151423),
    );
    final decoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            field.key == 'description' ? 'Describe la evidencia' : field.label,
            style: style.copyWith(fontWeight: FontWeight.w500),
          ),
          if (field.key == 'description') ...[
            const SizedBox(height: 6),
            const Text(
              'Esta información será pública para donantes y para la comunidad después de la aprobación.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 16 / 12,
                color: Color(0xff4f4e5c),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Semantics(
            label: field.label,
            child: field.options == null
                ? TextField(
                    key: ValueKey('expense-field-${field.key}'),
                    controller: controller,
                    enabled: enabled,
                    maxLength: field.max,
                    maxLines: field.lines,
                    style: field.lines > 1
                        ? style.copyWith(height: 1.4)
                        : style,
                    keyboardType: field.key == 'amount_cents'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : field.lines > 1
                        ? TextInputType.multiline
                        : TextInputType.text,
                    decoration: field.key == 'description'
                        ? decoration.copyWith(
                            hintText: 'Ej.: La mascota recibió el apoyo gracias a quienes la ayudaron.',
                            hintStyle: style.copyWith(
                              color: const Color(0xff4f4e5c),
                            ),
                          )
                        : decoration,
                    onChanged: (_) => onChanged(),
                  )
                : DropdownButtonFormField<String>(
                    key: ValueKey(
                      'expense-choice-${field.key}:${controller.text}',
                    ),
                    initialValue: field.options!.containsKey(controller.text)
                        ? controller.text
                        : null,
                    isExpanded: true,
                    style: style,
                    decoration: decoration,
                    items: field.options!.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: enabled
                        ? (value) {
                            if (value == null) return;
                            controller.text = value;
                            onChanged();
                          }
                        : null,
                  ),
          ),
          if (field.key == 'description') ...[
            const SizedBox(height: 6),
            const Text(
              'El reembolso requiere evidencia revisada y aprobada por Dopmi.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 16 / 12,
                color: Color(0xff4f4e5c),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
