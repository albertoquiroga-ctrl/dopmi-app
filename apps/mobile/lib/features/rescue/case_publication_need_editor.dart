import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import 'expense_evidence_card.dart';
import 'rescue_public_photo.dart';
import 'rescue_repository.dart';

/// Every attachment belongs to a real private expense draft. Nothing here submits,
/// publishes or sets reimbursable capacity before independent moderation.
class CasePublicationNeedEditor extends ConsumerStatefulWidget {
  const CasePublicationNeedEditor({
    super.key,
    required this.caseId,
    required this.type,
    this.record,
  });
  final String caseId, type;
  final RescueRecord? record;
  @override
  ConsumerState<CasePublicationNeedEditor> createState() =>
      _CasePublicationNeedEditorState();
}

class _CasePublicationNeedEditorState
    extends ConsumerState<CasePublicationNeedEditor> {
  final fields = <String, TextEditingController>{};
  RescueRecord? draft;
  List<Json> files = [];
  bool busy = false, urgent = false;
  String? error;
  RescueRepository get repo => ref.read(rescueRepositoryProvider);
  @override
  void initState() {
    super.initState();
    draft = widget.record;
    files = [...?draft?.files];
    for (final key in [
      'title',
      'description',
      'amount',
      'paid_on',
      'vendor',
      'receipt_reference',
      'round_label',
      'urgency_reason',
    ]) {
      final value = ['title', 'description', 'round_label'].contains(key)
          ? draft?.publicData[key]
          : draft?.privateData[key];
      fields[key] = TextEditingController(text: value?.toString() ?? '');
    }
    final cents = int.tryParse(
      draft?.privateData['amount_cents']?.toString() ?? '',
    );
    if (cents != null) {
      fields['amount']!.text =
          '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
    }
    urgent = fields['urgency_reason']!.text.isNotEmpty;
  }

  @override
  void dispose() {
    for (final value in fields.values) {
      value.dispose();
    }
    super.dispose();
  }

  bool get complete =>
      fields['title']!.text.trim().length >= 2 &&
      fields['description']!.text.trim().length >= 2 &&
      parsePesos(fields['amount']!.text) != null &&
      fields['paid_on']!.text.trim().isNotEmpty &&
      fields['vendor']!.text.trim().isNotEmpty &&
      fields['receipt_reference']!.text.trim().isNotEmpty &&
      (widget.type != 'food' ||
          fields['round_label']!.text.trim().isNotEmpty) &&
      (!urgent || fields['urgency_reason']!.text.trim().length >= 5) &&
      files.any((f) => f['role'] == 'receipt') &&
      files.any((f) => f['role'] == 'proof');

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (cause) {
      if (mounted) setState(() => error = rescueError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final raw = fields['amount']!.text.trim();
    final cents = raw.isEmpty ? null : parsePesos(raw);
    if (raw.isNotEmpty && cents == null) {
      throw const FormatException(
        'Escribe un importe en pesos con hasta dos decimales.',
      );
    }
    final value = await repo.save(
      'expense',
      {
        'category': widget.type,
        'title': fields['title']!.text.trim(),
        'description': fields['description']!.text.trim(),
        'round_label': fields['round_label']!.text.trim(),
      },
      {
        'paid_on': fields['paid_on']!.text.trim(),
        'vendor': fields['vendor']!.text.trim(),
        'receipt_reference': fields['receipt_reference']!.text.trim(),
        'amount_cents': cents?.toString() ?? '',
        'urgency_reason': urgent ? fields['urgency_reason']!.text.trim() : '',
      },
      files,
      record: draft,
      parent: widget.caseId,
    );
    if (mounted) setState(() => draft = value);
  }

  Future<void> attach(String role) async {
    final actor = ref.read(communityRepositoryProvider).userId;
    if (actor == null) throw const FormatException('Vuelve a iniciar sesión.');
    await save();
    if (!mounted) return;
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Fotos y PDF',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          uniformTypeIdentifiers: ['public.image', 'com.adobe.pdf'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    if (ref.read(communityRepositoryProvider).userId != actor) {
      throw const FormatException(
        'La sesión cambió. Retoma el borrador con su cuenta.',
      );
    }
    if (await file.length() > 5242880) {
      throw const FormatException('El archivo debe pesar hasta 5 MB.');
    }
    final path = await repo.upload(
      draft!.id,
      await file.readAsBytes(),
      pdf: file.name.toLowerCase().endsWith('.pdf'),
    );
    if (!mounted) return;
    setState(() {
      files.removeWhere((f) => f['role'] == role);
      files.add({'role': role, 'path': path});
    });
    await save();
  }

  Widget field(
    String key,
    String label, {
    int lines = 1,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label${required ? ' *' : ''}',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: ValueKey('publication-need-$key'),
          controller: fields[key],
          enabled: !busy,
          maxLines: lines,
          maxLength: key == 'description'
              ? 4000
              : key == 'urgency_reason'
              ? 1000
              : 150,
          keyboardType: key == 'amount'
              ? const TextInputType.numberWithOptions(decimal: true)
              : lines > 1
              ? TextInputType.multiline
              : TextInputType.text,
          decoration: InputDecoration(
            counterText: '',
            hintText: key == 'amount'
                ? '0.00'
                : key == 'paid_on'
                ? 'AAAA-MM-DD'
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
  );

  Widget evidence(String role, String title) {
    final indexes = [
      for (var i = 0; i < files.length; i++)
        if (files[i]['role'] == role) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (indexes.isNotEmpty &&
            !(files[indexes.first]['path'] as String).endsWith('.pdf'))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: RescuePublicPhoto(
                files[indexes.first]['path'] as String,
                height: 140,
                radius: 14,
                compact: true,
              ),
            ),
          ),
        ExpenseEvidenceCard(
          title: title,
          public: false,
          fileIndexes: indexes,
          onOpen: (index) =>
              context.push('/rescue-file', extra: files[index]['path']),
          onRemove: busy
              ? null
              : (index) => setState(() => files.removeAt(index)),
          onAttach: busy || files.length >= 12
              ? null
              : () => run(() => attach(role)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    '${draft == null ? 'Agregar' : 'Editar'} ${const {'food': 'alimento', 'medicine': 'medicina', 'veterinary': 'servicio veterinario'}[widget.type] ?? 'gasto'}',
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const Text(
              'Documenta un gasto que ya cubriste para que Dopmi pueda revisarlo.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xff616174),
              ),
            ),
            field(
              'title',
              widget.type == 'medicine'
                  ? 'Nombre de la medicina'
                  : widget.type == 'food'
                  ? 'Alimento comprado'
                  : 'Descripción del servicio',
            ),
            field('amount', 'Monto pagado en MXN'),
            field(
              'description',
              widget.type == 'medicine'
                  ? 'Tratamiento relacionado'
                  : 'Cómo ayudó a la mascota',
              lines: 3,
            ),
            if (widget.type == 'food')
              field('round_label', 'Ronda de alimento'),
            evidence('receipt', 'Foto de Recibo *'),
            evidence('proof', 'Foto de Evidencia *'),
            field('paid_on', 'Fecha en que pagaste'),
            field('vendor', 'Proveedor'),
            field('receipt_reference', 'Folio o referencia del comprobante'),
            if (widget.type != 'food') ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: urgent,
                onChanged: busy
                    ? null
                    : (value) => setState(() => urgent = value),
                title: const Text('Marcar como urgente'),
                subtitle: const Text('Pasará por revisión de DopMi'),
              ),
              if (urgent)
                field('urgency_reason', 'Motivo de urgencia', lines: 2),
            ],
            if (error != null) Notice(error!, isError: true),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy || !complete
                  ? null
                  : () => run(() async {
                      await save();
                      if (context.mounted) Navigator.pop(context, draft);
                    }),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff7841f2),
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                busy
                    ? 'Guardando...'
                    : 'Guardar ${const {'food': 'alimento', 'medicine': 'medicina', 'veterinary': 'servicio'}[widget.type] ?? 'gasto'}',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
