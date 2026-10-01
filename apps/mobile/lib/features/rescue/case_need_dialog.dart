import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../adoption/community_repository.dart';
import 'case_information.dart';
import 'rescue_fields.dart';
import 'rescue_repository.dart';

Future<Json?> addCaseNeed(BuildContext context, String type) =>
    showDialog<Json>(
      context: context,
      builder: (_) => CaseNeedDialog(type: type),
    );

class CaseNeedDialog extends StatefulWidget {
  const CaseNeedDialog({super.key, required this.type});
  final String type;
  @override
  State<CaseNeedDialog> createState() => _CaseNeedDialogState();
}

class _CaseNeedDialogState extends State<CaseNeedDialog> {
  final controllers = {
    for (final key in ['title', 'amount', 'detail'])
      key: TextEditingController(),
  };
  bool urgent = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget medicineField(
    String key,
    String label,
    String hint, {
    int lines = 1,
    bool money = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
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
        label: label,
        child: TextField(
          key: ValueKey('case-field-$key'),
          controller: controllers[key],
          maxLength: money
              ? 11
              : key == 'title'
              ? 150
              : 1000,
          maxLines: lines,
          onChanged: (_) => setState(() => error = null),
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : lines > 1
              ? TextInputType.multiline
              : TextInputType.text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.55,
            color: Color(0xff151423),
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: money
                ? const Padding(
                    padding: EdgeInsets.only(left: 12, right: 4),
                    child: Text(
                      '\$',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        height: 1.55,
                        color: Color(0xff616174),
                      ),
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 0,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffeaeaf3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xff7841f2)),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      if (money) ...[
        const SizedBox(height: 4),
        const Text(
          'Monto en MXN',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.55,
            color: Color(0xff616174),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final clinical = widget.type != 'food';
    final noun = const {
      'food': 'comida',
      'medicine': 'medicina',
      'veterinary': 'atención veterinaria',
    }[widget.type]!;
    final fields = CaseInformation(
      controllers: controllers,
      enabled: true,
      onChanged: () => setState(() {}),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 393,
          maxHeight:
              MediaQuery.sizeOf(context).height *
              (widget.type == 'veterinary' ? .94 : .92),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (clinical) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            widget.type == 'medicine'
                                ? 'Agregar medicina'
                                : 'Agregar servicio veterinario',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff151423),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.type == 'medicine'
                                ? 'Agrega los detalles de la medicina que necesita la mascota.'
                                : 'Agrega los detalles del servicio veterinario que necesita la mascota.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              height: 20 / 14,
                              color: Color(0xff616174),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -12,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                medicineField(
                  'title',
                  widget.type == 'medicine'
                      ? 'Nombre de la medicina'
                      : 'Motivo de consulta *',
                  widget.type == 'medicine'
                      ? 'ej. Amoxicilina'
                      : 'ej. Vacunación, revisión general',
                ),
                const SizedBox(height: 14),
                medicineField(
                  'amount',
                  widget.type == 'medicine'
                      ? 'Costo a cubrir'
                      : 'Monto de la consulta *',
                  '0.00',
                  money: true,
                ),
                const SizedBox(height: 14),
                if (widget.type == 'medicine')
                  medicineField(
                    'detail',
                    '¿Para qué tratamiento es?',
                    'ej. Infección respiratoria',
                    lines: 2,
                  ),
                if (widget.type == 'medicine') const SizedBox(height: 14),
                Semantics(
                  label:
                      'Marcar como urgente. Se requiere evidencia de urgencia.',
                  checked: urgent,
                  onTap: () => setState(() => urgent = !urgent),
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: () => setState(() => urgent = !urgent),
                      splashFactory: NoSplash.splashFactory,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                activeColor: const Color(0xff7841f2),
                                value: urgent,
                                onChanged: (v) => setState(() => urgent = v!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Marcar como urgente',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      height: 1.55,
                                      color: Color(0xff151423),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Se requiere evidencia de urgencia.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      height: 1.55,
                                      color: Color(0xff616174),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Agregar $noun',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                fields.field(
                  RescueField(
                    'title',
                    widget.type == 'medicine'
                        ? 'Nombre de la medicina'
                        : widget.type == 'food'
                        ? 'Alimento que necesita'
                        : 'Motivo de consulta o tratamiento',
                    max: 150,
                  ),
                ),
                fields.field(
                  const RescueField('amount', 'Costo a cubrir (MXN)', max: 11),
                ),
                fields.field(
                  const RescueField(
                    'detail',
                    'Detalles de la necesidad',
                    lines: 2,
                    max: 1000,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Urgente'),
                  value: urgent,
                  onChanged: (v) => setState(() => urgent = v!),
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff7841f2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed:
                    clinical &&
                        (controllers['title']!.text.trim().isEmpty ||
                            (parsePesos(controllers['amount']!.text) ?? 0) <
                                1 ||
                            (parsePesos(controllers['amount']!.text) ?? 0) >
                                100000000)
                    ? null
                    : () {
                        final cents = parsePesos(controllers['amount']!.text);
                        if (controllers['title']!.text.trim().isEmpty ||
                            cents == null ||
                            cents < 1 ||
                            cents > 100000000) {
                          setState(
                            () => error = 'Escribe un nombre y un costo válido en pesos con hasta dos decimales.',
                          );
                          return;
                        }
                        Navigator.pop(context, <String, dynamic>{
                          'id': const Uuid().v4(),
                          'type': widget.type,
                          'title': controllers['title']!.text.trim(),
                          'amount_cents': cents,
                          'detail': controllers['detail']!.text.trim(),
                          'urgent': urgent,
                        });
                      },
                child: Text(
                  widget.type == 'medicine'
                      ? 'Guardar medicina'
                      : widget.type == 'veterinary'
                      ? 'Guardar consulta'
                      : 'Agregar necesidad',
                ),
              ),
              if (clinical) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff151423),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
