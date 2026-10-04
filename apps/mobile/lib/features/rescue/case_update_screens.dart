import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../payments/contribution_layout.dart';
import 'case_update_repository.dart';
import 'owned_case_history.dart';
import 'rescue_repository.dart';

class PublicCaseUpdates extends StatelessWidget {
  const PublicCaseUpdates(this.caseId, {super.key});
  final String caseId;
  @override
  Widget build(BuildContext context) => OwnedCaseHistory(caseId);
}

class CaseUpdatesManageScreen extends ConsumerWidget {
  const CaseUpdatesManageScreen(this.caseId, {super.key});
  final String caseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ContributionFrame(
    title: 'Avances del caso',
    rescuer: true,
    back: () =>
        context.canPop() ? context.pop() : context.go('/rescue/$caseId'),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          'Comparte cambios reales. Cada avance se revisa antes de aparecer públicamente.',
          style: TextStyle(fontSize: 14, height: 1.45, color: muted),
        ),
        const SizedBox(height: 20),
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
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      item.body.isEmpty ? 'Avance sin terminar' : item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(rescueStatuses[item.status] ?? item.status),
                    trailing:
                        [
                          'draft',
                          'changes_requested',
                          'rejected',
                        ].contains(item.status)
                        ? const Icon(Icons.chevron_right)
                        : null,
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
    ),
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
  bool restoreFailed = false;
  String? error;
  bool get canEdit =>
      !loading &&
      !restoreFailed &&
      (update == null ||
          ['draft', 'changes_requested', 'rejected'].contains(update!.status));

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    setState(() {
      loading = true;
      restoreFailed = false;
      error = null;
    });
    if (widget.updateId != null) {
      try {
        final items = await ref
            .read(caseUpdateRepositoryProvider)
            .mine(widget.caseId);
        if (!mounted) return;
        update = items.where((item) => item.id == widget.updateId).firstOrNull;
        if (update == null) {
          throw const FormatException('Avance no disponible.');
        }
        body.text = update!.body;
      } catch (cause) {
        if (!mounted) return;
        restoreFailed = true;
        error = communityError(cause);
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pick() async {
    if (!canEdit || busy) return;
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
    if (busy || !canEdit) return;
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
  Widget build(BuildContext context) => ContributionFrame(
    title: 'Comparte un avance',
    rescuer: true,
    back: () => context.canPop()
        ? context.pop()
        : context.go('/rescue-cases/${widget.caseId}/updates'),
    child: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          'Cuenta qué cambió y añade sólo fotos que puedan mostrarse públicamente.',
          style: TextStyle(fontSize: 14, height: 1.45, color: muted),
        ),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (error != null) Notice(error!, isError: true),
          if (restoreFailed)
            TextButton(
              onPressed: restore,
              child: const Text('Volver a intentar'),
            ),
          if (!restoreFailed && !canEdit)
            const Notice(
              'Este avance ya está en revisión o aprobado y no se puede editar.',
            ),
          TextField(
            enabled: canEdit && !busy,
            controller: body,
            minLines: 5,
            maxLines: 10,
            maxLength: 2000,
            decoration: const InputDecoration(
              label: Text('¿Cómo sigue el rescate?', maxLines: 3),
            ),
          ),
          OutlinedButton.icon(
            onPressed:
                busy ||
                    !canEdit ||
                    (update?.photos.length ?? 0) + pendingPhotos.length >= 6
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
            onPressed: canEdit ? () => run(submit: false) : null,
          ),
          TextButton(
            onPressed: busy || !canEdit ? null : () => run(submit: true),
            child: const Text('Enviar a revisión'),
          ),
        ],
      ],
    ),
  );
}
