import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../adoption/location_map_picker.dart';
import '../adoption/location_selection.dart';
import '../identity/identity_controller.dart' show configProvider;
import 'case_information.dart';
import 'case_revision.dart';
import 'case_review.dart';
import 'expense_evidence_card.dart';
import 'expense_field.dart';
import 'rescue_fields.dart';
import 'rescue_repository.dart';
import 'rescue_videos.dart';

class CaseRevisionScreen extends ConsumerStatefulWidget {
  const CaseRevisionScreen(this.caseId, {super.key});
  final String caseId;
  @override
  ConsumerState<CaseRevisionScreen> createState() => _CaseRevisionScreenState();
}

class _CaseRevisionScreenState extends ConsumerState<CaseRevisionScreen> {
  final reason = TextEditingController();
  final startRequest = const Uuid().v4();
  late final String? actor = ref.read(communityRepositoryProvider).userId;
  late final RescueRepository source = ref.read(rescueRepositoryProvider);
  CaseRevisionPacket? packet;
  _RevisionFields? caseFields;
  List<_RevisionFields> expenses = [];
  List<_PlannedRevisionFields> planned = [];
  SelectedLocation? location;
  _RevisionAttempt? attempt;
  bool loading = true, busy = false, dirty = false, reviewing = false;
  String? error, message;
  bool get sameSession =>
      actor != null &&
      ref.read(communityRepositoryProvider).userId == actor &&
      identical(source, ref.read(rescueRepositoryProvider)) &&
      (packet == null || packet!.revision['owner_id'] == actor);
  bool get editable => packet?.editable == true && !busy && attempt == null;
  bool get validReason =>
      reason.text.trim().runes.length >= 5 &&
      reason.text.trim().runes.length <= 2000;
  bool get canManageThanks =>
      packet?.editable == true &&
      packet!.caseUnit['revision_recovery'] == true &&
      packet!.caseUnit['can_start_revision'] == true &&
      packet!.caseUnit['case_status'] == 'changes_requested' &&
      packet!.caseUnit['case_version'] == packet!.baseRecord.version &&
      packet!.baseRecord.status == 'changes_requested' &&
      packet!.baseRecord.data['owner_id'] == actor &&
      sameSession;
  String get publicationExplanation => switch (packet?.publicVersionVisible) {
    true => 'La versión aprobada permanece publicada mientras el equipo revisa tu edición completa. Sólo cambia al aprobarse.',
    false => 'La publicación está retirada. Tus correcciones permanecen privadas y deben aprobarse como un caso completo antes de volver a publicarse.',
    null =>
      'Guarda en privado tus correcciones y envía el caso completo a revisión.',
  };
  String publicationState(CaseRevisionPacket current) =>
      switch (current.publicVersionVisible) {
        true => 'La versión aprobada sigue publicada.',
        false => 'La publicación permanece retirada.',
        null => 'Consulta el estado actualizado del caso.',
      };

  @override
  void initState() {
    super.initState();
    load();
  }

  void disposeFields() {
    caseFields?.dispose();
    for (final expense in expenses) {
      expense.dispose();
    }
    for (final need in planned) {
      need.dispose();
    }
  }

  @override
  void dispose() {
    reason.dispose();
    disposeFields();
    super.dispose();
  }

  void requireSession() {
    if (!sameSession) {
      throw const FormatException(
        'La sesión cambió. Retoma la edición con su cuenta.',
      );
    }
  }

  void install(CaseRevisionPacket next) {
    if (next.record.id != widget.caseId || next.revision['owner_id'] != actor) {
      throw const FormatException(
        'Esta edición no está disponible para tu cuenta.',
      );
    }
    disposeFields();
    packet = next;
    reason.text = next.reason;
    caseFields = _RevisionFields(next.record);
    expenses = next.expenses.map(_RevisionFields.new).toList();
    planned = (next.record.publicData['need_items'] as List? ?? [])
        .map((item) => _PlannedRevisionFields(Json.from(item as Map)))
        .toList();
    location = SelectedLocation.fromData(
      next.record.data,
      city: caseFields!.controllers['city']!.text,
      region: caseFields!.controllers['state']!.text,
    );
    dirty = false;
    attempt = null;
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      requireSession();
      var next = await source.caseRevision(widget.caseId);
      requireSession();
      if (next == null) {
        final detail = await source.detail(widget.caseId);
        requireSession();
        final base = RescueRecord(Json.from(detail['record'] as Map));
        next = await source.startCaseRevision(base, startRequest);
      }
      requireSession();
      if (!mounted) return;
      setState(() {
        install(next!);
        reviewing = !next.editable;
      });
    } catch (cause) {
      if (mounted) {
        setState(() {
          error = rescueError(cause);
          packet = null;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      requireSession();
      await action();
      requireSession();
    } catch (cause) {
      if (!mounted) return;
      setState(() {
        error = rescueError(cause);
        if (cause is PostgrestException &&
            [
              '22023',
              '23514',
              '42501',
              '40001',
              'PT409',
            ].contains(cause.code)) {
          attempt = null;
          if (cause.code == '42501') packet = null;
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> startAnother() async {
    final detail = await source.detail(widget.caseId);
    requireSession();
    final base = RescueRecord(Json.from(detail['record'] as Map));
    final next = await source.startCaseRevision(base, const Uuid().v4());
    requireSession();
    if (!mounted) return;
    setState(() {
      install(next);
      reviewing = false;
    });
  }

  Future<void> manageThanks() async {
    try {
      requireSession();
      if (!canManageThanks || busy || attempt != null) return;
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RevisionThanksDialog(
          record: packet!.baseRecord,
          authorized: () => mounted && canManageThanks,
        ),
      );
      requireSession();
      if (!mounted || changed != true) return;
      setState(
        () => message = 'El video cambió. Vuelve a enviar la edición completa para que el expediente incluya su estado actual.',
      );
    } catch (cause) {
      if (mounted) setState(() => error = rescueError(cause));
    }
  }

  Widget thanksBlocker() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Notice(
        'Esta edición aún no acredita un video de agradecimiento aprobado. Consulta el video existente; si ya fue aprobado, consérvalo. Si el video o su revisión cambió después del envío, retira la edición a borrador y vuelve a enviarla completa.',
      ),
      if (packet!.status == 'submitted')
        OutlinedButton(
          onPressed: busy ? null : () => run(() => transition('withdraw')),
          child: const Text('Retirar edición para gestionar video'),
        )
      else if (canManageThanks)
        OutlinedButton(
          onPressed: busy || attempt != null ? null : manageThanks,
          child: const Text('Gestionar video de agradecimiento'),
        ),
    ],
  );

  void changed() => setState(() {
    dirty = true;
    message = null;
  });

  Future<void> save() async {
    requireSession();
    if (attempt != null && attempt!.action != 'save') return;
    if (attempt == null) {
      if (!validReason) {
        throw const FormatException(
          'Explica el motivo de la edición con entre 5 y 2000 caracteres.',
        );
      }
      final fields = caseFields!.payload();
      final pub = Json.from(fields['public_data'] as Map);
      if (location != null) pub.addAll(location!.payload);
      if (pub.containsKey('need_items')) {
        pub['need_items'] = planned.map((need) => need.payload()).toList();
      }
      fields['public_data'] = pub;
      attempt = _RevisionAttempt(
        'save',
        packet!,
        reason: reason.text.trim(),
        caseFields: fields,
        expenseFields: expenses
            .map((expense) => {'id': expense.record.id, ...expense.payload()})
            .toList(),
      );
    }
    final pending = attempt!;
    final next = await source.saveCaseRevision(
      id: pending.packet.id,
      version: pending.packet.version,
      reason: pending.reason!,
      caseFields: pending.caseFields!,
      expenseFields: pending.expenseFields!,
      requestId: pending.requestId,
    );
    requireSession();
    if (!mounted) return;
    setState(() {
      install(next);
      message = 'Edición guardada en privado.';
    });
  }

  Future<void> transition(String action) async {
    requireSession();
    if (attempt?.action == 'save') await save();
    if (action == 'submit' && dirty) await save();
    if (!mounted) return;
    if (attempt != null && attempt!.action != action) return;
    attempt ??= _RevisionAttempt(action, packet!);
    final pending = attempt!;
    final next = await source.transitionCaseRevision(
      pending.packet,
      action,
      pending.requestId,
    );
    requireSession();
    if (!mounted) return;
    setState(() {
      install(next);
      reviewing = !next.editable;
      message = action == 'submit'
          ? 'Edición completa enviada a revisión. ${publicationState(next)}'
          : 'Edición retirada a borrador privado. ${publicationState(next)}';
    });
  }

  Future<bool> confirmLeave() async {
    if ((!dirty && attempt == null) || !sameSession) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hay cambios sin guardar'),
            content: const Text(
              'Tu edición se guarda por separado. Puedes seguir editando o salir y consultar después el último borrador guardado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir sin guardar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> attach(_RevisionFields fields, String role) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: role == 'public' ? 'Fotos' : 'Fotos y PDF',
          extensions: role == 'public'
              ? ['jpg', 'jpeg', 'png', 'webp']
              : ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          uniformTypeIdentifiers: role == 'public'
              ? ['public.image']
              : ['public.image', 'com.adobe.pdf'],
        ),
      ],
    );
    requireSession();
    if (file == null || !mounted) return;
    if (await file.length() > 5242880) {
      throw const FormatException('El archivo debe pesar hasta 5 MB.');
    }
    final path = await source.uploadCaseRevision(
      packet: packet!,
      recordId: fields.record.id,
      role: role,
      bytes: await file.readAsBytes(),
      pdf: file.name.toLowerCase().endsWith('.pdf'),
      requestId: const Uuid().v4(),
    );
    requireSession();
    if (!mounted) return;
    setState(() {
      fields.files.add({'role': role, 'path': path});
      dirty = true;
    });
  }

  Future<void> chooseLocation() async {
    final selected = await chooseLocationOnMap(
      context,
      initial: location,
      city: caseFields!.controllers['city']!.text,
      region: caseFields!.controllers['state']!.text,
    );
    requireSession();
    if (!mounted || selected == null) return;
    setState(() {
      location = selected;
      caseFields!.controllers['city']!.text = selected.city;
      caseFields!.controllers['state']!.text = selected.region;
      dirty = true;
    });
  }

  Widget evidence(_RevisionFields fields, String role) => ExpenseEvidenceCard(
    title: evidenceRoles[role] ?? role,
    public: role == 'public',
    fileIndexes: [
      for (var i = 0; i < fields.files.length; i++)
        if (fields.files[i]['role'] == role) i,
    ],
    onOpen: (i) => context.push('/rescue-file', extra: fields.files[i]['path']),
    onRemove: editable && !fields.locked('files')
        ? (i) => setState(() {
            fields.files.removeAt(i);
            dirty = true;
          })
        : null,
    onAttach: editable && !fields.locked('files') && fields.files.length < 12
        ? () => run(() => attach(fields, role))
        : null,
  );

  Widget editor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CaseInformation(
        controllers: caseFields!.controllers,
        enabled: editable,
        onChanged: changed,
        locationField: ref.read(configProvider).mapsEnabled
            ? PublicationLocationField(
                city: caseFields!.controllers['city']!.text,
                region: caseFields!.controllers['state']!.text,
                selection: location,
                onChoose: editable ? () => run(chooseLocation) : null,
              )
            : null,
      ),
      CaseInformation(
        controllers: caseFields!.controllers,
        enabled: editable,
        onChanged: changed,
      ).field(rescueFields['case']!.firstWhere((field) => field.key == 'need')),
      evidence(caseFields!, 'public'),
      const SizedBox(height: 24),
      const Text(
        'Necesidades del caso',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Puedes corregir las necesidades de este caso. Si surge otra necesidad, publica un nuevo caso, aunque sea para la misma mascota.',
      ),
      for (final expense in expenses) ...[
        const SizedBox(height: 16),
        ExpansionTile(
          key: ValueKey('revision-need-${expense.record.id}'),
          title: Text(expense.controllers['title']!.text),
          subtitle: expense.record.data['financial_inactive'] == true
              ? const Text(
                  'Necesidad retirada previamente; sin importe disponible',
                )
              : null,
          childrenPadding: const EdgeInsets.all(12),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expense.amountLocked)
              const Notice(
                'El importe y sus comprobantes están protegidos porque esta necesidad tiene aportaciones o reservas.',
              ),
            for (final field in rescueFields['expense']!)
              ExpenseField(
                field: field,
                controller: expense.controllers[field.key]!,
                enabled: editable && !expense.locked(field.key),
                onChanged: changed,
              ),
            for (final role in ['receipt', 'proof', 'public'])
              evidence(expense, role),
          ],
        ),
      ],
      for (final need in planned) ...[
        const SizedBox(height: 16),
        ExpansionTile(
          key: ValueKey('revision-planned-${need.original['id']}'),
          title: Text(need.controllers['title']!.text),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          childrenPadding: const EdgeInsets.all(12),
          children: [
            for (final field in const [
              RescueField('title', 'Necesidad', max: 150),
              RescueField('amount_cents', 'Importe en pesos MXN', max: 11),
              RescueField('detail', 'Descripción', lines: 3, max: 1000),
            ])
              ExpenseField(
                field: field,
                controller: need.controllers[field.key]!,
                enabled: editable,
                onChanged: changed,
              ),
            SwitchListTile(
              title: const Text('Solicitar revisión de urgencia'),
              value: need.urgent,
              onChanged: editable
                  ? (value) => setState(() {
                      need.urgent = value;
                      dirty = true;
                    })
                  : null,
            ),
          ],
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(communityRepositoryProvider);
    if (!sameSession) {
      return const CommunityFrame(
        children: [
          Notice('La sesión cambió. Retoma la edición con su cuenta.'),
        ],
      );
    }
    return PopScope(
      canPop: !busy && !dirty && attempt == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && !busy && await confirmLeave() && context.mounted) {
          setState(() {
            dirty = false;
            attempt = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
        }
      },
      child: CommunityFrame(
        children: [
          Heading('Editar caso', publicationExplanation),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (packet == null) ...[
            Notice(error ?? 'No se pudo cargar la edición.', isError: true),
            TextButton(onPressed: load, child: const Text('Volver a intentar')),
          ] else ...[
            Notice(
              'Edición: ${const {'draft': 'Borrador privado', 'submitted': 'En revisión', 'changes_requested': 'Necesita correcciones', 'rejected': 'No aprobada', 'approved': 'Aprobada', 'invalidated': 'Requiere actualizarse'}[packet!.status] ?? 'No disponible'}',
            ),
            if ((packet!.revision['feedback'] as String? ?? '')
                .trim()
                .isNotEmpty)
              Notice('Respuesta del equipo: ${packet!.revision['feedback']}'),
            for (final comment in packet!.comments)
              Notice(
                '${comment['target_title'] ?? 'Necesidad'}:\n${comment['body'] ?? ''}',
              ),
            if (packet!.publicationBlockers.contains(
              'approved_thanks_required',
            ))
              thanksBlocker(),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('case-revision-reason'),
              controller: reason,
              enabled: editable,
              maxLength: 2000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Motivo de la edición',
                helperText: 'Explica qué corregiste y por qué (de 5 a 2000 caracteres).',
                helperMaxLines: 3,
              ),
              onChanged: (_) => changed(),
            ),
            if (reviewing)
              CaseReview(
                values: caseFields!.values,
                files: caseFields!.files,
                expenseDrafts: expenses
                    .map((expense) => expense.preview())
                    .toList(),
                items: planned.map((need) => need.preview()).toList(),
                onOpen: (path) => context.push('/rescue-file', extra: path),
              )
            else
              editor(),
            const SizedBox(height: 24),
            if (busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Guardando la edición del caso',
              ),
            if (error != null) Notice(error!, isError: true),
            if (message != null) Notice(message!),
            if (packet!.editable) ...[
              if (attempt?.action == 'submit')
                ActionButton(
                  'Reintentar el mismo envío',
                  busy: busy,
                  onPressed: () => run(() => transition('submit')),
                )
              else ...[
                ActionButton(
                  attempt?.action == 'save'
                      ? 'Reintentar el mismo guardado'
                      : 'Guardar borrador privado',
                  busy: busy,
                  onPressed: !validReason ? null : () => run(save),
                ),
                const SizedBox(height: 8),
                if (reviewing)
                  ActionButton(
                    'Enviar edición completa',
                    busy: busy,
                    onPressed: !validReason || attempt != null
                        ? null
                        : () => run(() => transition('submit')),
                  )
                else
                  OutlinedButton(
                    onPressed: !editable || !validReason
                        ? null
                        : () => run(() async {
                            await save();
                            if (mounted) setState(() => reviewing = true);
                          }),
                    child: const Text('Revisar edición completa'),
                  ),
                if (reviewing)
                  TextButton(
                    onPressed: !editable
                        ? null
                        : () => setState(() => reviewing = false),
                    child: const Text('Volver a editar'),
                  ),
              ],
            ],
            if (packet!.status == 'submitted')
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() => transition('withdraw')),
                child: Text(
                  attempt?.action == 'withdraw'
                      ? 'Reintentar el mismo retiro'
                      : 'Retirar edición a borrador',
                ),
              ),
            if (['approved', 'invalidated'].contains(packet!.status) &&
                packet!.canStartRevision)
              OutlinedButton(
                onPressed: busy ? null : () => run(startAnother),
                child: const Text('Iniciar otra edición'),
              ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (await confirmLeave()) await load();
                    },
              child: const Text('Recargar edición'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RevisionThanksDialog extends StatefulWidget {
  const _RevisionThanksDialog({required this.record, required this.authorized});
  final RescueRecord record;
  final bool Function() authorized;
  @override
  State<_RevisionThanksDialog> createState() => _RevisionThanksDialogState();
}

class _RevisionThanksDialogState extends State<_RevisionThanksDialog> {
  bool active = false, changed = false;
  @override
  Widget build(BuildContext context) {
    final allowed = widget.authorized();
    return PopScope(
      canPop: !active || !allowed,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Video de agradecimiento del caso',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Gestiona el video del expediente original. La publicación permanece retirada. Después de un cambio de video o de su revisión, vuelve a enviar la edición completa para que se revise con ese estado.',
                      ),
                      if (!allowed)
                        const Notice(
                          'La sesión o el estado del caso cambió. Vuelve al expediente para recargarlo.',
                        )
                      else
                        RescueVideoSection(
                          record: widget.record,
                          purposes: const ['thanks'],
                          publicationThanks: true,
                          enabled: allowed,
                          onContinueChanged: (_) {},
                          onChanged: () {
                            if (mounted) setState(() => changed = true);
                          },
                          onActivityChanged: (value) {
                            if (mounted && active != value) {
                              setState(() => active = value);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: OutlinedButton(
                  onPressed: active && allowed
                      ? null
                      : () => Navigator.pop(context, changed),
                  child: const Text('Volver a la edición'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevisionAttempt {
  _RevisionAttempt(
    this.action,
    this.packet, {
    this.reason,
    this.caseFields,
    this.expenseFields,
  });
  final String action;
  final CaseRevisionPacket packet;
  final String requestId = const Uuid().v4();
  final String? reason;
  final Json? caseFields;
  final List<Json>? expenseFields;
}

class _RevisionFields {
  _RevisionFields(this.record) : files = record.files.map(Json.from).toList() {
    for (final field in rescueFields[record.kind]!) {
      final raw = (field.private
          ? record.privateData
          : record.publicData)[field.key];
      var text = raw?.toString() ?? '';
      if (field.key == 'amount_cents') text = _decimal(raw);
      controllers[field.key] = TextEditingController(text: text);
    }
  }
  final RescueRecord record;
  final List<Json> files;
  final controllers = <String, TextEditingController>{};
  bool get amountLocked =>
      record.data['financial_locked'] != false ||
      (record.data['locked_fields'] as List? ?? []).contains('amount_cents');
  bool locked(String key) =>
      (key == 'amount_cents' && amountLocked) ||
      (record.data['locked_fields'] as List? ?? []).contains(key);
  Map<String, String> get values => {
    for (final entry in controllers.entries) entry.key: entry.value.text.trim(),
  };
  Json payload() {
    final publicData = Json.from(record.publicData),
        privateData = Json.from(record.privateData);
    for (final field in rescueFields[record.kind]!) {
      if (locked(field.key)) continue;
      var value = controllers[field.key]!.text.trim();
      if (field.key == 'amount_cents') {
        final cents = parsePesos(value);
        if (cents == null) {
          throw const FormatException(
            'Escribe el importe completo pagado en pesos con hasta dos decimales.',
          );
        }
        value = cents.toString();
      }
      (field.private ? privateData : publicData)[field.key] = value;
    }
    if (publicData['urgency_photo_path'] != null &&
        !files.any(
          (file) => file['path'] == publicData['urgency_photo_path'],
        )) {
      publicData.remove('urgency_photo_path');
    }
    return {
      'public_data': publicData,
      'private_data': privateData,
      'files': (locked('files') ? record.files : files).map(Json.from).toList(),
    };
  }

  RescueRecord preview() {
    final fields = payload();
    return RescueRecord({...record.data, ...fields});
  }

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

class _PlannedRevisionFields {
  _PlannedRevisionFields(this.original) : urgent = original['urgent'] == true {
    for (final key in ['title', 'detail', 'amount_cents']) {
      controllers[key] = TextEditingController(
        text: key == 'amount_cents'
            ? _decimal(original[key])
            : original[key]?.toString() ?? '',
      );
    }
  }
  final Json original;
  final controllers = <String, TextEditingController>{};
  bool urgent;
  Json payload() {
    final cents = parsePesos(controllers['amount_cents']!.text);
    if (cents == null) {
      throw const FormatException('Revisa el importe de la necesidad.');
    }
    return {
      ...original,
      'title': controllers['title']!.text.trim(),
      'detail': controllers['detail']!.text.trim(),
      'amount_cents': cents,
      'urgent': urgent,
    };
  }

  Json preview() => payload();
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

String _decimal(Object? raw) {
  final cents = int.tryParse(raw?.toString() ?? '');
  return cents == null
      ? ''
      : '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}
