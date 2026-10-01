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

  @override
  Widget build(BuildContext context) {
    final noun = const {
      'food': 'comida',
      'medicine': 'medicina',
      'veterinary': 'atención veterinaria',
    }[widget.type]!;
    final fields = CaseInformation(
      controllers: controllers,
      enabled: true,
      onChanged: () {},
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 393,
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                onPressed: () {
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
                child: const Text('Agregar necesidad'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
