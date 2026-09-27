import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'community_repository.dart';
import 'community_ui.dart';

enum SavedKind { adoption, donation, rescuer }

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key, this.initialKind = SavedKind.adoption});
  final SavedKind initialKind;
  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  late SavedKind kind;
  int page = 1, revision = 0;

  @override
  void initState() {
    super.initState();
    kind = widget.initialKind;
  }

  Future<DataPage<SavedEntry>> load() {
    final repo = ref.read(communityRepositoryProvider);
    return switch (kind) {
      SavedKind.adoption => repo.savedAdoptions(page),
      SavedKind.donation => repo.savedCases(page),
      SavedKind.rescuer => repo.savedRescuers(page),
    };
  }

  Future<void> remove(SavedEntry item) async {
    final repo = ref.read(communityRepositoryProvider);
    switch (kind) {
      case SavedKind.adoption:
        await repo.favorite(item.id, false);
      case SavedKind.donation:
        await repo.favoriteCase(item.id, false);
      case SavedKind.rescuer:
        await repo.favoriteRescuer(item.id, false);
    }
    if (mounted) setState(() => revision++);
  }

  void select(SavedKind value) => setState(() {
    kind = value;
    page = 1;
  });

  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      const Heading(
        'Tus guardados.',
        'Mascotas, casos y rescatistas que quieres volver a consultar.',
        eyebrow: 'MIS MATCH',
      ),
      SegmentedButton<SavedKind>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: SavedKind.adoption, label: Text('Adopción')),
          ButtonSegment(value: SavedKind.donation, label: Text('Donación')),
          ButtonSegment(value: SavedKind.rescuer, label: Text('Rescatistas')),
        ],
        selected: {kind},
        onSelectionChanged: (values) => select(values.first),
      ),
      const SizedBox(height: 20),
      LiveSection<DataPage<SavedEntry>>(
        key: ValueKey('$kind:$page:$revision'),
        tables: const [
          'dopmi_favorites',
          'dopmi_saved_cases',
          'dopmi_saved_rescuers',
        ],
        load: load,
        builder: (result, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${result.total} guardados'),
            const SizedBox(height: 12),
            if (result.items.isEmpty)
              Notice(switch (kind) {
                SavedKind.adoption => 'Cuando marques Me gusta o guardes una adopción aparecerá aquí.',
                SavedKind.donation =>
                  'Guarda un caso desde Apoyar para encontrarlo aquí.',
                SavedKind.rescuer =>
                  'Guarda un perfil público para seguir su trabajo.',
              }),
            for (final item in result.items)
              _SavedCard(item, kind: kind, remove: () => remove(item)),
            PageControls(
              page: page,
              total: result.total,
              size: 20,
              change: (value) => setState(() => page = value),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SavedCard extends StatelessWidget {
  const _SavedCard(this.item, {required this.kind, required this.remove});
  final SavedEntry item;
  final SavedKind kind;
  final Future<void> Function() remove;

  String get title {
    if (!item.available) return 'Contenido no disponible';
    return switch (kind) {
      SavedKind.adoption => item.text('pet_name'),
      SavedKind.donation =>
        item.publicData['pet_name'] as String? ??
            item.publicData['title'] as String? ??
            'Caso de rescate',
      SavedKind.rescuer =>
        item.text('name').isEmpty ? 'Perfil de rescatista' : item.text('name'),
    };
  }

  String get subtitle {
    if (!item.available) {
      return 'Se retiró o volvió a revisión. No mostramos su contenido privado.';
    }
    return switch (kind) {
      SavedKind.adoption => '${item.text('city')}, ${item.text('region')}',
      SavedKind.donation =>
        item.publicData['story'] as String? ??
            'Conoce su historia y gastos aprobados.',
      SavedKind.rescuer => '${item.text('city')}, ${item.text('region')}',
    };
  }

  String get route => switch (kind) {
    SavedKind.adoption => '/adoptions/${item.id}',
    SavedKind.donation => '/rescue-cases/${item.id}',
    SavedKind.rescuer => '/people/${item.id}',
  };

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: item.available
            ? const Color(0xffffe16b)
            : const Color(0xffeeeae5),
        child: Icon(
          item.available ? Icons.favorite : Icons.visibility_off_outlined,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: item.available ? () => context.push(route) : null,
      trailing: IconButton(
        tooltip: 'Quitar de guardados',
        onPressed: remove,
        icon: const Icon(Icons.close),
      ),
    ),
  );
}
