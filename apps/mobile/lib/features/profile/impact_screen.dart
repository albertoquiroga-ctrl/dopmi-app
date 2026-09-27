import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../rescue/rescue_repository.dart';

class ImpactScreen extends ConsumerWidget {
  const ImpactScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => CommunityFrame(
    children: [
      const Heading(
        'Tu impacto.',
        'Avances públicos de los casos a los que tus aportaciones sí fueron asignadas.',
        eyebrow: 'APORTACIONES',
      ),
      LiveSection<List<Json>>(
        load: () => ref.read(communityRepositoryProvider).personalImpact(),
        builder: (items, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              const Notice(
                'Cuando una aportación confirmada se asigne a un gasto, sus avances públicos aparecerán aquí.',
              ),
            for (final item in items) _ImpactCase(item),
          ],
        ),
      ),
    ],
  );
}

class _ImpactCase extends StatelessWidget {
  const _ImpactCase(this.item);
  final Json item;
  @override
  Widget build(BuildContext context) {
    final publicData = Json.from(item['public_data'] as Map? ?? {});
    final updates = (item['updates'] as List? ?? [])
        .map((value) => Json.from(value as Map))
        .toList();
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              publicData['pet_name'] as String? ?? 'Caso de rescate',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${pesos(item['allocated_cents'] as int? ?? 0)} asignados de tus aportaciones',
            ),
            const SizedBox(height: 12),
            if (updates.isEmpty)
              const Text('Este caso todavía no tiene avances públicos.')
            else
              for (final update in updates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: Text(update['body'] as String? ?? 'Avance'),
                  subtitle: Text(
                    localDate(update['published_at'] as String? ?? ''),
                  ),
                ),
            TextButton(
              onPressed: () => context.push('/rescue-cases/${item['case_id']}'),
              child: const Text('Ver caso'),
            ),
          ],
        ),
      ),
    );
  }
}
