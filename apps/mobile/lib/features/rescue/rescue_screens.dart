import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/ui.dart';
import '../../core/measurement.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../community/content_actions.dart';
import '../payments/payment_repository.dart';
import 'rescue_fields.dart';
import 'case_update_screens.dart';
import 'rescue_repository.dart';
import 'support_home.dart';
import 'case_detail_layout.dart';
import 'public_expense_card.dart';

class RescueHomeScreen extends ConsumerWidget {
  const RescueHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => CommunityFrame(
    index: 2,
    back: false,
    children: [
      const Heading('Hola', 'Tu panel de rescate'),
      LiveSection<Json>(
        tables: const [
          'dopmi_rescue_records',
          'dopmi_donations',
          'dopmi_notifications',
        ],
        load: () => ref.read(rescueRepositoryProvider).dashboard(),
        builder: (data, refresh) => _RescuerDashboard(data, refresh),
      ),
    ],
  );
}

class _RescuerDashboard extends StatelessWidget {
  const _RescuerDashboard(this.data, this.refresh);
  final Json data;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final verification =
        data['verification_status'] as String? ?? 'not_started';
    final counts = Json.from(data['case_counts'] as Map? ?? {});
    final financial = Json.from(data['financial'] as Map? ?? {});
    final pending = (data['pending'] as List? ?? [])
        .map((item) => Json.from(item))
        .toList();
    final activity = (data['recent_activity'] as List? ?? [])
        .map((item) => Json.from(item))
        .toList();
    final unread = data['unread_messages'] as int? ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (verification != 'approved')
          Card(
            color: const Color(0xffeee7fc),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: purple,
                    size: 34,
                  ),
                  Text(
                    _verificationTitle(verification),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'La verificación protege a donantes y mascotas. Tus documentos no son públicos.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await context.push('/rescue/new?kind=verification');
                      refresh();
                    },
                    child: Text(
                      verification == 'not_started'
                          ? 'Verificarme'
                          : 'Ver estado',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (verification == 'approved')
          Card(
            color: purple,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Resumen comprobado',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 14,
                    children: [
                      _DashboardAmount(
                        'Asignado',
                        financial['assigned_cents'] as int? ?? 0,
                      ),
                      _DashboardAmount(
                        'Transferido',
                        financial['transferred_cents'] as int? ?? 0,
                      ),
                      _DashboardAmount(
                        'En revisión',
                        financial['in_review_cents'] as int? ?? 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${counts['active'] ?? 0} casos activos',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Acciones pendientes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (pending.isNotEmpty || unread > 0)
              Chip(label: Text('${pending.length + (unread > 0 ? 1 : 0)}')),
          ],
        ),
        if (unread > 0)
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Responde mensajes pendientes'),
              subtitle: Text('$unread sin leer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/messages'),
            ),
          ),
        for (final item in pending)
          Card(
            child: ListTile(
              leading: Icon(
                item['status'] == 'draft'
                    ? Icons.edit_note
                    : Icons.error_outline,
                color: purple,
              ),
              title: Text(item['title'] as String),
              subtitle: Text(
                '${rescueStatuses[item['status']] ?? item['status']}${(item['feedback'] as String? ?? '').isEmpty ? '' : ' · ${item['feedback']}'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/rescue/${item['id']}'),
            ),
          ),
        if (pending.isEmpty && unread == 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Icon(Icons.favorite_outline, color: purple, size: 34),
                  Text(
                    'No tienes acciones pendientes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Los borradores, correcciones, mensajes y evidencias aparecerán aquí.',
                  ),
                  TextButton(
                    onPressed: () => context.go('/publish'),
                    child: const Text('Publicar caso'),
                  ),
                ],
              ),
            ),
          ),
        if (activity.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Actividad reciente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final item in activity)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.south_west)),
              title: Text('${pesos(item['allocated_cents'] as int)} asignados'),
              subtitle: Text(item['expense_title'] as String),
            ),
        ],
      ],
    );
  }
}

String _verificationTitle(String status) => switch (status) {
  'submitted' => 'Verificación en proceso',
  'changes_requested' || 'rejected' => 'Corrige tu información',
  'draft' => 'Continúa tu verificación',
  _ => 'Verifícate para recibir aportaciones',
};

class _DashboardAmount extends StatelessWidget {
  const _DashboardAmount(this.label, this.cents);
  final String label;
  final int cents;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pesos(cents),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    ),
  );
}

class RescueList extends ConsumerStatefulWidget {
  const RescueList({super.key, required this.kind, this.parent});
  final String kind;
  final String? parent;
  @override
  ConsumerState<RescueList> createState() => _RescueListState();
}

class _RescueListState extends ConsumerState<RescueList> {
  int page = 1;
  @override
  Widget build(BuildContext context) => LiveSection<DataPage<RescueRecord>>(
    key: ValueKey('${widget.kind}:${widget.parent}:$page'),
    tables: const ['dopmi_rescue_records'],
    load: () => ref
        .read(rescueRepositoryProvider)
        .mine(widget.kind, page, parent: widget.parent),
    builder: (data, refresh) => Column(
      children: [
        if (data.items.isEmpty)
          const Notice(
            'Aquí aparecerán tus borradores y las respuestas del equipo.',
          ),
        for (final r in data.items)
          _OwnedRescueCard(record: r, refresh: refresh),
        if (data.total > 20)
          PageControls(
            page: page,
            total: data.total,
            size: 20,
            change: (p) => setState(() => page = p),
          ),
      ],
    ),
  );
}

class _OwnedRescueCard extends ConsumerWidget {
  const _OwnedRescueCard({required this.record, required this.refresh});
  final RescueRecord record;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsAction = [
      'draft',
      'changes_requested',
      'rejected',
    ].contains(record.status);
    final action = switch (record.status) {
      'draft' => 'Continuar publicación',
      'changes_requested' || 'rejected' => 'Corregir publicación',
      'submitted' => 'Ver envío',
      'approved' => 'Administrar caso',
      'closed' => 'Ver caso cerrado',
      _ => 'Ver caso',
    };
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: needsAction
                      ? const Color(0xffffe9e7)
                      : const Color(0xffeee7fc),
                  child: Icon(
                    needsAction ? Icons.edit_note : Icons.pets_outlined,
                    color: needsAction ? Colors.red : purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title.isEmpty
                            ? 'Borrador sin título'
                            : record.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(rescueStatuses[record.status] ?? record.status),
                    ],
                  ),
                ),
                if (record.data['urgent'] == true)
                  const Chip(label: Text('Urgente')),
              ],
            ),
            if ((record.data['feedback'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Notice(record.data['feedback'] as String, isError: needsAction),
            ],
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () async {
                await context.push('/rescue/${record.id}');
                refresh();
              },
              child: Text(action),
            ),
            if (record.kind == 'case' && record.status == 'approved')
              TextButton.icon(
                onPressed: () async {
                  final linked = await ref
                      .read(communityRepositoryProvider)
                      .ownForCase(record.id);
                  if (!context.mounted) return;
                  await context.push(
                    linked == null
                        ? '/my-adoptions/new?case=${record.id}'
                        : '/my-adoptions/${linked.id}',
                  );
                  refresh();
                },
                icon: const Icon(Icons.home_outlined),
                label: const Text('Preparar publicación para adopción'),
              ),
          ],
        ),
      ),
    );
  }
}

class RescueEditorScreen extends ConsumerStatefulWidget {
  const RescueEditorScreen(
    this.id, {
    super.key,
    this.kind = 'case',
    this.parent,
  });
  final String id, kind;
  final String? parent;
  @override
  ConsumerState<RescueEditorScreen> createState() => _RescueEditorState();
}

class _RescueEditorState extends ConsumerState<RescueEditorScreen> {
  final controllers = <String, TextEditingController>{};
  RescueRecord? record;
  List<Json> files = [], history = [];
  int step = 0;
  bool loading = true, busy = false, dirty = false, loadFailed = false;
  String? error, message;
  String get kind => record?.kind ?? widget.kind;
  bool get editable => record?.editable ?? true;
  RescueRepository get repository => ref.read(rescueRepositoryProvider);
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void fields(RescueRecord? r) {
    for (final f in rescueFields[kind]!) {
      var value =
          (f.private ? r?.privateData : r?.publicData)?[f.key] as String? ??
          f.initial;
      if (f.key == 'amount_cents' && int.tryParse(value) != null) {
        final cents = int.parse(value);
        value = '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
      }
      (controllers[f.key] ??= TextEditingController()).text = value;
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      if (widget.id != 'new' || record != null) {
        final data = await repository.detail(record?.id ?? widget.id);
        if (!mounted) return;
        record = RescueRecord(Json.from(data['record']));
        history = (data['history'] as List).map((e) => Json.from(e)).toList();
        files = record!.files;
        if (!record!.editable) step = 2;
      }
      fields(record);
      dirty = false;
      error = null;
      loadFailed = false;
    } catch (cause) {
      if (mounted) {
        error = rescueError(cause);
        loadFailed = true;
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
      await action();
    } catch (cause) {
      if (mounted) {
        setState(() {
          error = rescueError(cause);
          if (cause is PostgrestException && cause.code == '42501') {
            loadFailed = true;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    final pub = <String, dynamic>{}, priv = <String, dynamic>{};
    for (final f in rescueFields[kind]!) {
      var value = controllers[f.key]!.text.trim();
      if (f.key == 'amount_cents' && value.isNotEmpty) {
        final cents = parsePesos(value);
        if (cents == null) {
          throw const FormatException(
            'Escribe el importe en pesos con hasta dos decimales, por ejemplo 250.50.',
          );
        }
        value = cents.toString();
      }
      (f.private ? priv : pub)[f.key] = value;
    }
    final saved = await repository.save(
      kind,
      pub,
      priv,
      files,
      record: record,
      parent: widget.parent,
    );
    if (!mounted) return;
    setState(() {
      record = saved;
      dirty = false;
      message = 'Borrador guardado.';
    });
  }

  Future<void> attach(String role) async {
    await save();
    if (!mounted) return;
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
    if (file == null || !mounted) return;
    if (await file.length() > 5242880) {
      throw const FormatException('El archivo debe pesar hasta 5 MB.');
    }
    final pdf = file.name.toLowerCase().endsWith('.pdf');
    if (role == 'public' && pdf) {
      throw const FormatException('Para publicación elige una foto.');
    }
    final path = await repository.upload(
      record!.id,
      await file.readAsBytes(),
      pdf: pdf,
    );
    if (!mounted) return;
    setState(() {
      files = [
        ...files,
        {'role': role, 'path': path},
      ];
      dirty = true;
    });
    await save();
  }

  Future<void> transition(String action) async {
    if (action == 'submit') {
      await save();
      if (!mounted) return;
    }
    final result = await repository.transition(record!, action);
    if (action == 'submit') {
      await ref
          .read(measurementControllerProvider)
          ?.event('publication_submitted');
    }
    if (!mounted) return;
    setState(() {
      record = result;
      message = action == 'submit'
          ? 'Solicitud enviada. Te avisaremos cuando el equipo responda.'
          : action == 'close'
          ? 'Caso cerrado.'
          : 'Retiramos la solicitud a borrador.';
    });
    await load();
  }

  Future<bool> confirmLeave() async {
    if (!dirty || !editable) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hay cambios sin guardar'),
            content: const Text(
              'Guarda el borrador antes de salir para conservarlos.',
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty || !editable,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await confirmLeave() && context.mounted) {
        setState(() => dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.pop();
        });
      }
    },
    child: CommunityFrame(
      children: [
        Heading(
          kind == 'verification'
              ? 'Tu labor merece\nconfianza.'
              : kind == 'case'
              ? 'Cuéntanos su historia.'
              : 'Documenta el gasto.',
          kind == 'verification'
              ? 'El equipo revisará tus documentos y el enlace social.'
              : kind == 'case'
              ? 'Describe el rescate y la necesidad. El equipo revisa todo antes de publicarlo.'
              : 'Presenta un gasto ya pagado. Cada ronda de comida necesita su propia solicitud y revisión.',
          eyebrow: rescueKinds[kind]!.toUpperCase(),
        ),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (loadFailed || (record == null && widget.id != 'new')) ...[
          Notice(error ?? 'Solicitud no disponible', isError: true),
          TextButton(onPressed: load, child: const Text('Volver a intentar')),
        ] else ...[
          if (record != null)
            Notice(
              '${rescueStatuses[record!.status]} · Versión ${record!.version}',
            ),
          if ((record?.data['feedback'] as String? ?? '').isNotEmpty)
            Notice('Respuesta del equipo: ${record!.data['feedback']}'),
          if (!editable)
            const Notice(
              'Los datos enviados están protegidos. Puedes consultar el estado actualizado al recargar.',
            ),
          _RescueSteps(step: step),
          if (busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Guardando o subiendo archivos',
            ),
          for (final private in [false, true]) ...[
            if (step == 1 &&
                rescueFields[kind]!.any((f) => f.private == private)) ...[
              const SizedBox(height: 20),
              Text(
                private
                    ? 'Solo para revisión privada'
                    : 'Información para publicación',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!private)
                const Text(
                  'No incluyas domicilios particulares, teléfonos ni datos de tus comprobantes.',
                ),
              const SizedBox(height: 16),
              for (final f in rescueFields[kind]!.where(
                (f) => f.private == private,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: f.options == null
                      ? TextField(
                          controller: controllers[f.key],
                          enabled: editable && !busy,
                          maxLength: f.max,
                          maxLines: f.lines,
                          keyboardType: f.key == 'amount_cents'
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                )
                              : null,
                          decoration: InputDecoration(
                            labelText: f.label,
                            alignLabelWithHint: f.lines > 1,
                          ),
                          onChanged: (_) => setState(() => dirty = true),
                        )
                      : DropdownButtonFormField<String>(
                          key: ValueKey('${f.key}:${controllers[f.key]!.text}'),
                          initialValue:
                              f.options!.containsKey(controllers[f.key]!.text)
                              ? controllers[f.key]!.text
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: f.label),
                          items: f.options!.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: !editable || busy
                              ? null
                              : (v) => setState(() {
                                  controllers[f.key]!.text = v!;
                                  dirty = true;
                                }),
                        ),
                ),
            ],
          ],
          if (step == 0) ...[
            Text(
              'Documentos y evidencia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Hasta 12 archivos de 5 MB. JPG, PNG, WebP o PDF; para publicar, solo fotos.',
            ),
            for (final role
                in kind == 'verification'
                    ? ['identity', 'address']
                    : kind == 'case'
                    ? ['public']
                    : ['receipt', 'proof', 'public'])
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${evidenceRoles[role]} · ${role == 'public' ? 'Pública después de aprobación' : 'Privada'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final file in files.where((f) => f['role'] == role))
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.description_outlined),
                                label: Text(
                                  'Ver archivo ${files.indexOf(file) + 1}',
                                ),
                                onPressed: () => context.push(
                                  '/rescue-file',
                                  extra: file['path'],
                                ),
                              ),
                            ),
                            if (editable)
                              IconButton(
                                tooltip:
                                    'Quitar archivo ${files.indexOf(file) + 1}',
                                icon: const Icon(Icons.close),
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        files.remove(file);
                                        dirty = true;
                                      }),
                              ),
                          ],
                        ),
                      if (editable)
                        OutlinedButton.icon(
                          onPressed: busy || files.length >= 12
                              ? null
                              : () => run(() => attach(role)),
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            'Adjuntar ${evidenceRoles[role]!.toLowerCase()}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (step == 2) ...[
            Text(
              'Revisa antes de enviar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _RescueReviewRow('Tipo', rescueKinds[kind] ?? kind),
            _RescueReviewRow(
              'Nombre',
              controllers[rescueFields[kind]!.first.key]?.text.trim() ?? '',
            ),
            _RescueReviewRow('Archivos', '${files.length} adjuntos'),
            const Notice(
              'El equipo revisará por separado la información pública, los documentos privados y la evidencia antes de aprobar.',
            ),
          ],
          if (record?.kind == 'expense' && record!.status == 'approved')
            LiveSection<Json>(
              key: ValueKey('funding:${record!.id}'),
              tables: const ['dopmi_donations'],
              errorMessage: paymentError,
              load: () =>
                  ref.read(paymentRepositoryProvider).funding(record!.id),
              builder: (funding, refresh) => Column(
                children: [
                  Notice(
                    'Monto reembolsable: ${pesos(funding['reimbursable_cents'] as int)}${record!.data['urgent'] == true ? ' · Urgencia aprobada' : ''}. Neto asignado: ${pesos(funding['funded_cents'] as int)}. Transferido a Stripe: ${pesos(funding['transferred_cents'] as int? ?? 0)}. Disponible: ${pesos(funding['available_cents'] as int)}.',
                  ),
                  TextButton(
                    onPressed: refresh,
                    child: const Text('Actualizar aportaciones'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (editable) ...[
            if (error != null) Notice(error!, isError: true),
            if (message != null) Notice(message!),
            if (step < 2)
              ActionButton(
                'Guardar y continuar',
                busy: busy,
                onPressed: () => run(() async {
                  await save();
                  if (mounted) setState(() => step++);
                }),
              )
            else ...[
              ActionButton(
                'Enviar a revisión',
                busy: busy,
                onPressed: () => run(() => transition('submit')),
              ),
              TextButton(
                onPressed: busy ? null : () => run(save),
                child: const Text('Guardar borrador'),
              ),
            ],
            if (step > 0)
              TextButton(
                onPressed: busy ? null : () => setState(() => step--),
                child: const Text('Regresar al paso anterior'),
              ),
          ],
          if (!editable && error != null) Notice(error!, isError: true),
          if (!editable && message != null) Notice(message!),
          if (record?.status == 'submitted')
            OutlinedButton(
              onPressed: busy ? null : () => run(() => transition('withdraw')),
              child: const Text('Retirar a borrador'),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (await confirmLeave()) {
                      await load();
                    }
                  },
            child: const Text('Recargar estado'),
          ),
          if (record?.kind == 'case') ...[
            const SizedBox(height: 24),
            Text(
              'Gastos de este caso',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (record!.status != 'closed')
              ActionButton(
                'Registrar gasto realizado',
                sunny: true,
                onPressed: busy
                    ? null
                    : () => context.push(
                        '/rescue/new?kind=expense&case=${record!.id}',
                      ),
              ),
            RescueList(kind: 'expense', parent: record!.id),
            if (record!.status == 'approved')
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final close = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('¿Cerrar este caso?'),
                            content: const Text(
                              'Ya no podrás agregar gastos. El seguimiento aprobado seguirá disponible.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Continuar caso'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Cerrar caso'),
                              ),
                            ],
                          ),
                        );
                        if (close == true) await transition('close');
                      }),
                child: const Text('Cerrar caso'),
              ),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Historial', style: Theme.of(context).textTheme.titleLarge),
            for (final item in history)
              ListTile(
                title: Text(
                  rescueStatuses[item['action']] ??
                      {
                        'submit': 'Enviado',
                        'withdraw': 'Retirado a borrador',
                        'close': 'Caso cerrado',
                      }[item['action']] ??
                      'Actualización',
                ),
                subtitle: Text(
                  '${localDate(item['created_at'] as String)} · Versión ${item['version']}\n${item['feedback']}',
                ),
              ),
          ],
        ],
      ],
    ),
  );
}

class _RescueSteps extends StatelessWidget {
  const _RescueSteps({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paso ${step + 1} de 3',
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          for (final entry in [
            'Archivos',
            'Información',
            'Revisión',
          ].indexed) ...[
            Expanded(
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: entry.$1 <= step ? 1 : 0,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(5),
                    backgroundColor: const Color(0xffe7e2da),
                    color: purple,
                  ),
                  const SizedBox(height: 5),
                  Text(entry.$2, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (entry.$1 < 2) const SizedBox(width: 8),
          ],
        ],
      ),
    ),
  );
}

class _RescueReviewRow extends StatelessWidget {
  const _RescueReviewRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value.isEmpty ? 'Falta completar' : value),
  );
}

class RescueFileScreen extends ConsumerStatefulWidget {
  const RescueFileScreen(this.path, {super.key});
  final String path;
  @override
  ConsumerState<RescueFileScreen> createState() => _RescueFileState();
}

class _RescueFileState extends ConsumerState<RescueFileScreen> {
  late Future<String> url = ref
      .read(rescueRepositoryProvider)
      .fileUrl(widget.path);
  String? error;
  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      const Heading(
        'Archivo adjunto',
        'El acceso se comprueba al abrir cada archivo.',
      ),
      if (error != null) Notice(error!, isError: true),
      FutureBuilder<String>(
        future: url,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Notice(rescueError(snapshot.error!), isError: true);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (widget.path.endsWith('.pdf')) {
            return ActionButton(
              'Abrir PDF',
              onPressed: () async {
                try {
                  final fresh = await ref
                      .read(rescueRepositoryProvider)
                      .fileUrl(widget.path);
                  if (!mounted) return;
                  if (!await launchUrl(
                    Uri.parse(fresh),
                    mode: LaunchMode.externalApplication,
                  )) {
                    throw const FormatException('No pudimos abrir el PDF.');
                  }
                } catch (cause) {
                  if (mounted) setState(() => error = rescueError(cause));
                }
              },
            );
          }
          return Image.network(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Notice(
              'No pudimos cargar la imagen. Recarga el archivo.',
              isError: true,
            ),
          );
        },
      ),
      TextButton(
        onPressed: () => setState(
          () => url = ref.read(rescueRepositoryProvider).fileUrl(widget.path),
        ),
        child: const Text('Recargar archivo'),
      ),
    ],
  );
}

class RescueCatalogScreen extends ConsumerStatefulWidget {
  const RescueCatalogScreen({super.key, this.caseId});
  final String? caseId;
  @override
  ConsumerState<RescueCatalogScreen> createState() => _RescueCatalogState();
}

class _RescueCatalogState extends ConsumerState<RescueCatalogScreen> {
  int page = 1;
  bool busy = false;
  bool? savedOverride;
  String? error;

  Future<void> toggleCase(RescueRecord record, VoidCallback refresh) async {
    final repo = ref.read(communityRepositoryProvider);
    if (repo.userId == null) {
      context.push('/login');
      return;
    }
    final previous = savedOverride ?? record.saved;
    setState(() {
      busy = true;
      error = null;
      savedOverride = !previous;
    });
    try {
      await repo.favoriteCase(record.id, !previous);
      refresh();
    } catch (cause) {
      if (mounted) {
        setState(() {
          savedOverride = previous;
          error = communityError(cause);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reportCase(RescueRecord record) async {
    final repo = ref.read(communityRepositoryProvider);
    if (repo.userId == null) {
      context.push('/login');
      return;
    }
    final result = await showContentReportSheet(context);
    if (result == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.report('case', record.id, result.$1, result.$2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recibimos tu reporte para revisión.')),
        );
      }
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = LiveSection<DataPage<RescueRecord>>(
      key: ValueKey('${widget.caseId}:$page'),
      statusFrame: widget.caseId == null
          ? null
          : (child) => CaseStatusFrame(child),
      load: () => ref
          .read(rescueRepositoryProvider)
          .catalog(page, caseId: widget.caseId),
      builder: (data, refresh) => widget.caseId == null
          ? SupportHomePage(
              data: data,
              page: page,
              error: error,
              changePage: (value) => setState(() => page = value),
            )
          : _PublicCaseDetail(
              records: data.items,
              busy: busy,
              error: error,
              savedOverride: savedOverride,
              toggle: (record) => toggleCase(record, refresh),
              report: reportCase,
            ),
    );
    if (widget.caseId == null) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        bottomNavigationBar: const CommunityNav(1),
        body: content,
      );
    }
    return Scaffold(backgroundColor: Colors.white, body: content);
  }
}

class _PublicCaseDetail extends StatelessWidget {
  const _PublicCaseDetail({
    required this.records,
    required this.busy,
    required this.error,
    required this.savedOverride,
    required this.toggle,
    required this.report,
  });
  final List<RescueRecord> records;
  final bool busy;
  final String? error;
  final bool? savedOverride;
  final ValueChanged<RescueRecord> toggle, report;
  @override
  Widget build(BuildContext context) {
    final cases = records.where((item) => item.kind == 'case').toList();
    if (cases.isEmpty) {
      return const CaseStatusFrame(Notice('Este caso ya no está disponible.'));
    }
    final record = cases.first;
    final expenses = records.where((item) => item.kind == 'expense').toList();
    return CaseDetailLayout(
      record: record,
      expenses: expenses,
      busy: busy,
      error: error,
      saved: savedOverride ?? record.saved,
      favorite: () => toggle(record),
      report: () => report(record),
      share: () => copyForSharing(
        context,
        'Conoce el caso ${record.title} en Dopmi. Caso ${record.id}',
      ),
      needs: Column(
        children: [
          if (expenses.isEmpty)
            const Notice('Este caso no tiene gastos disponibles para aportar.'),
          for (var i = 0; i < expenses.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            PublicExpenseCard(
              expenses[i],
              key: ValueKey(expenses[i].id),
              initiallyOpen:
                  i ==
                  expenses.indexWhere(
                    (e) =>
                        record.status == 'approved' &&
                        e.status == 'approved' &&
                        e.targetCents > e.fundedCents,
                  ),
              canContribute:
                  record.status == 'approved' &&
                  expenses[i].status == 'approved',
            ),
          ],
        ],
      ),
      updates: record.data['owner_id'] != null
          ? PublicCaseUpdates(record.id)
          : null,
    );
  }
}

class MyRescueCasesScreen extends StatelessWidget {
  const MyRescueCasesScreen({super.key});
  @override
  Widget build(BuildContext context) => CommunityFrame(
    index: 2,
    back: false,
    children: [
      Row(
        children: [
          Expanded(
            child: Heading(
              'Mis casos',
              'Da seguimiento a borradores, revisiones, correcciones y casos publicados.',
            ),
          ),
          IconButton.filled(
            tooltip: 'Nuevo caso',
            onPressed: () => context.push('/rescue/new?kind=case'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const RescueList(kind: 'case'),
    ],
  );
}
