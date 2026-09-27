import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import 'case_update_repository.dart';
import 'rescue_repository.dart';

class PublicCaseUpdates extends ConsumerWidget {
  const PublicCaseUpdates(this.caseId, {super.key});
  final String caseId;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => LiveSection<List<CaseUpdate>>(
    tables: const ['dopmi_case_updates'],
    load: () => ref.read(caseUpdateRepositoryProvider).publicFor(caseId),
    builder: (items, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'Historia hasta ahora',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Notice('Los avances aprobados del rescate aparecerán aquí.'),
        for (final item in items)
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    localDate(item.publishedAt ?? ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(item.body, style: Theme.of(context).textTheme.bodyLarge),
                  for (final photo in item.photos) ...[
                    const SizedBox(height: 12),
                    _UpdatePhoto(photo),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _UpdatePhoto extends ConsumerWidget {
  const _UpdatePhoto(this.path);
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<String>(
    future: ref.read(caseUpdateRepositoryProvider).photoUrl(path),
    builder: (_, value) => value.hasData
        ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(value.data!, height: 220, fit: BoxFit.cover),
          )
        : const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
  );
}

class CaseUpdatesManageScreen extends ConsumerWidget {
  const CaseUpdatesManageScreen(this.caseId, {super.key});
  final String caseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => CommunityFrame(
    children: [
      const Heading(
        'Avances del caso',
        'Comparte cambios reales. Cada avance se revisa antes de aparecer públicamente.',
        eyebrow: 'HISTORIA DEL RESCATE',
      ),
      ActionButton(
        'Crear avance',
        onPressed: () => context.push('/rescue-cases/$caseId/updates/new'),
      ),
      const SizedBox(height: 20),
      LiveSection<List<CaseUpdate>>(
        tables: const ['dopmi_case_updates'],
        load: () => ref.read(caseUpdateRepositoryProvider).mine(caseId),
        builder: (items, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              const Notice('Todavía no has creado avances para este caso.'),
            for (final item in items)
              Card(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    item.body.isEmpty ? 'Avance sin terminar' : item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(rescueStatuses[item.status] ?? item.status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      [
                        'draft',
                        'changes_requested',
                        'rejected',
                      ].contains(item.status)
                      ? () => context.push(
                          '/rescue-cases/$caseId/updates/${item.id}',
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class CaseUpdateEditorScreen extends ConsumerStatefulWidget {
  const CaseUpdateEditorScreen(this.caseId, {super.key, this.updateId});
  final String caseId;
  final String? updateId;
  @override
  ConsumerState<CaseUpdateEditorScreen> createState() =>
      _CaseUpdateEditorState();
}

class _CaseUpdateEditorState extends ConsumerState<CaseUpdateEditorScreen> {
  final body = TextEditingController();
  CaseUpdate? update;
  final pendingPhotos = <Uint8List>[];
  bool loading = true, busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    if (widget.updateId != null) {
      try {
        final items = await ref
            .read(caseUpdateRepositoryProvider)
            .mine(widget.caseId);
        update = items.where((item) => item.id == widget.updateId).firstOrNull;
        if (update == null) {
          throw const FormatException('Avance no disponible.');
        }
        body.text = update!.body;
      } catch (cause) {
        error = communityError(cause);
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pick() async {
    final selected = await ImagePicker().pickMultiImage(
      imageQuality: 90,
      limit: 6 - (update?.photos.length ?? 0) - pendingPhotos.length,
    );
    if (!mounted) return;
    for (final file in selected) {
      pendingPhotos.add(await file.readAsBytes());
    }
    setState(() {});
  }

  Future<CaseUpdate?> save() async {
    final repo = ref.read(caseUpdateRepositoryProvider);
    var saved = await repo.save(
      widget.caseId,
      body.text,
      update?.photos ?? [],
      update: update,
    );
    final paths = [...saved.photos];
    for (final bytes in pendingPhotos) {
      paths.add(await repo.upload(saved.id, bytes));
    }
    if (pendingPhotos.isNotEmpty) {
      saved = await repo.save(widget.caseId, body.text, paths, update: saved);
    }
    if (mounted) {
      setState(() {
        update = saved;
        pendingPhotos.clear();
      });
    }
    return saved;
  }

  Future<void> run({required bool submit}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await save();
      if (submit && saved != null) {
        update = await ref
            .read(caseUpdateRepositoryProvider)
            .transition(saved, 'submit');
      }
      if (!mounted) return;
      if (submit) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Borrador guardado.')));
      }
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      const Heading(
        'Comparte un avance',
        'Cuenta qué cambió y añade sólo fotos que puedan mostrarse públicamente.',
        eyebrow: 'CASO',
      ),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else ...[
        if (error != null) Notice(error!, isError: true),
        TextField(
          controller: body,
          minLines: 5,
          maxLines: 10,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: '¿Cómo sigue el rescate?',
          ),
        ),
        OutlinedButton.icon(
          onPressed:
              busy || (update?.photos.length ?? 0) + pendingPhotos.length >= 6
              ? null
              : pick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            'Añadir fotos (${(update?.photos.length ?? 0) + pendingPhotos.length}/6)',
          ),
        ),
        const SizedBox(height: 12),
        ActionButton(
          'Guardar borrador',
          busy: busy,
          onPressed: () => run(submit: false),
        ),
        TextButton(
          onPressed: busy ? null : () => run(submit: true),
          child: const Text('Enviar a revisión'),
        ),
      ],
    ],
  );
}
