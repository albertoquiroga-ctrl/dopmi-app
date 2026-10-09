import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/media/remote_photo.dart';
import '../../core/ui.dart';
import '../rescue/rescue_repository.dart';
import '../rescue/rescue_public_photo.dart';
import 'community_repository.dart';
import 'community_ui.dart';

class PublicProfileAdoptionGrid extends StatelessWidget {
  const PublicProfileAdoptionGrid({
    super.key,
    required this.adoptions,
    required this.filters,
    this.species,
    this.interactive = true,
  });
  final List<Adoption> adoptions;
  final Json filters;
  final String? species;
  final bool interactive;
  @override
  Widget build(BuildContext context) {
    final traits = (filters['personality'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final visible = adoptions.where((post) {
      if (species != null && post.data['species'] != species) return false;
      if (filters['sex'] != null && post.data['sex'] != filters['sex']) {
        return false;
      }
      if (filters['size'] != null && post.data['size'] != filters['size']) {
        return false;
      }
      final actual = (post.data['personality'] as List? ?? const [])
          .whereType<String>();
      return traits.isEmpty || traits.any(actual.contains);
    }).toList();
    if (visible.isEmpty) {
      return const Notice('No hay mascotas con este filtro.');
    }
    return _PublicMediaGrid(
      children: [
        for (final post in visible)
          Semantics(
            button: true,
            enabled: interactive,
            label: 'Ver a ${post.name}',
            child: InkWell(
              key: ValueKey('public-adoption-${post.id}'),
              onTap: interactive
                  ? () => context.push('/adoptions/${post.id}')
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: post.photos.isEmpty
                    ? const ColoredBox(
                        color: Color(0xffeeeeee),
                        child: Icon(Icons.pets_outlined),
                      )
                    : AdoptionPhoto(post.photos.first, radius: 16),
              ),
            ),
          ),
      ],
    );
  }
}

class PublicProfileCaseGrid extends ConsumerWidget {
  const PublicProfileCaseGrid({
    super.key,
    required this.cases,
    this.interactive = true,
  });
  final List<Json> cases;
  final bool interactive;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cases.isEmpty) {
      return const Notice('No hay casos en apoyo activos por ahora.');
    }
    return _PublicMediaGrid(
      children: [
        for (final item in cases)
          Builder(
            builder: (context) {
              final data = Json.from(item['public_data'] as Map? ?? {});
              final photos = (data['photos'] as List? ?? const [])
                  .whereType<String>()
                  .where((p) => p.isNotEmpty)
                  .toList();
              return Semantics(
                button: true,
                enabled: interactive,
                label:
                    'Ver caso de ${data['pet_name'] ?? data['title'] ?? 'mascota'}',
                child: InkWell(
                  key: ValueKey('public-case-${item['id']}'),
                  onTap: interactive
                      ? () => context.push('/rescue-cases/${item['id']}')
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: photos.isEmpty
                        ? const ColoredBox(
                            color: Color(0xffeeeeee),
                            child: Icon(Icons.pets_outlined),
                          )
                        : RemotePhoto(
                            source: rescuePhotoSource(
                              ref.read(rescueRepositoryProvider),
                              photos.first,
                            ),
                            loading: const ColoredBox(color: Color(0xffeeeeee)),
                            unavailable: (retry) => IconButton(
                              onPressed: retry,
                              tooltip: 'Reintentar foto pública',
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _PublicMediaGrid extends StatelessWidget {
  const _PublicMediaGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: children,
  );
}
