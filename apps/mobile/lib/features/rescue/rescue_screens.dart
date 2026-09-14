import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import 'rescue_fields.dart';
import 'rescue_repository.dart';

class RescueHomeScreen extends ConsumerWidget {
  const RescueHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => CommunityFrame(
    index: 2,
    children: [
      const Heading(
        'Cada rescate\ncuenta.',
        'Verifica tu identidad, comparte tus casos y documenta los gastos que ya realizaste.',
        eyebrow: 'ESPACIO RESCATISTA',
      ),
      Card(
        color: const Color(0xffeee7fc),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_user_outlined, color: purple, size: 36),
              const SizedBox(height: 12),
              Text(
                'Tu verificación',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Identificación y domicilio solo los revisa el equipo. No se publican.',
              ),
              LiveSection<DataPage<RescueRecord>>(
                tables: const ['dopmi_rescue_records'],
                load: () =>
                    ref.read(rescueRepositoryProvider).mine('verification', 1),
                builder: (data, refresh) => Column(
                  children: [
                    if (data.items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(rescueStatuses[data.items.first.status]!),
                      ),
                    ActionButton(
                      data.items.isEmpty
                          ? 'Comenzar verificación'
                          : 'Ver mi verificación',
                      onPressed: () async {
                        await context.push(
                          data.items.isEmpty
                              ? '/rescue/new?kind=verification'
                              : '/rescue/${data.items.first.id}',
                        );
                        refresh();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      ActionButton(
        'Nuevo caso',
        sunny: true,
        onPressed: () => context.push('/rescue/new?kind=case'),
      ),
      TextButton(
        onPressed: () => context.push('/rescue-cases'),
        child: const Text('Ver casos aprobados'),
      ),
      const SizedBox(height: 16),
      Text('Mis casos', style: Theme.of(context).textTheme.titleLarge),
      const RescueList(kind: 'case'),
    ],
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
          Card(
            color: Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(r.title.isEmpty ? 'Borrador sin título' : r.title),
              subtitle: Text(rescueStatuses[r.status]!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await context.push('/rescue/${r.id}');
                refresh();
              },
            ),
          ),
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
          for (final private in [false, true]) ...[
            if (rescueFields[kind]!.any((f) => f.private == private)) ...[
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
          if (record?.kind == 'expense' && record!.status == 'approved')
            Notice(
              'Monto reembolsable: ${pesos(record!.data['reimbursable_cents'] as int)}${record!.data['urgent'] == true ? ' · Urgencia aprobada' : ''}. Aún no se reciben aportaciones.',
            ),
          const SizedBox(height: 24),
          if (editable) ...[
            if (error != null) Notice(error!, isError: true),
            if (message != null) Notice(message!),
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
  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      Heading(
        widget.caseId == null
            ? 'Historias que\nnos unen.'
            : 'Seguimiento del caso.',
        'Conoce el trabajo y los gastos revisados por el equipo Dopmi.',
        eyebrow: 'RESCATES',
      ),
      const Notice(
        'Las aportaciones se habilitarán en una siguiente etapa. No se ha cobrado dinero desde estas solicitudes.',
      ),
      LiveSection<DataPage<RescueRecord>>(
        key: ValueKey('${widget.caseId}:$page'),
        load: () => ref
            .read(rescueRepositoryProvider)
            .catalog(page, caseId: widget.caseId),
        builder: (data, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.items.isEmpty)
              const Notice('Todavía no hay contenido aprobado disponible.'),
            for (final r in data.items)
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final path
                          in (r.publicData['photos'] as List? ?? []))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RescuePublicPhoto(path as String),
                        ),
                      Text(
                        r.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${r.data['rescuer_name']} · ${r.status == 'closed'
                            ? 'Caso cerrado'
                            : r.kind == 'case'
                            ? 'Caso aprobado'
                            : 'Gasto aprobado'}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (r.publicData['story'] ??
                                r.publicData['description'] ??
                                '')
                            as String,
                      ),
                      if (r.kind == 'case')
                        Text(
                          '${r.publicData['city']}, ${r.publicData['state']}\nNecesidad: ${r.publicData['need']}',
                        ),
                      if (r.kind == 'expense')
                        Text(
                          'Monto reembolsable: ${pesos(r.data['reimbursable_cents'] as int)}${r.data['urgent'] == true ? ' · Urgencia aprobada' : ''}',
                        ),
                      if (widget.caseId == null)
                        TextButton(
                          onPressed: () =>
                              context.push('/rescue-cases/${r.id}'),
                          child: const Text('Ver seguimiento'),
                        ),
                    ],
                  ),
                ),
              ),
            PageControls(
              page: page,
              total: data.total,
              size: 20,
              change: (p) => setState(() => page = p),
            ),
          ],
        ),
      ),
    ],
  );
}

class RescuePublicPhoto extends ConsumerWidget {
  const RescuePublicPhoto(this.path, {super.key});
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<String>(
    future: ref.read(rescueRepositoryProvider).fileUrl(path),
    builder: (_, snapshot) => ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: snapshot.hasData
          ? Image.network(
              snapshot.data!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 80,
                child: Center(child: Text('Foto no disponible')),
              ),
            )
          : SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  snapshot.hasError ? 'Foto no disponible' : 'Cargando foto…',
                ),
              ),
            ),
    ),
  );
}
