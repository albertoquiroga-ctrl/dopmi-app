import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import 'photo_recovery.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.saved = false, this.owner});
  final bool saved;
  final String? owner;
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  Json filters = {};
  int page = 1, revision = 0;
  @override
  Widget build(BuildContext context) {
    final repo = ref.read(communityRepositoryProvider);
    return CommunityFrame(
      index: widget.saved ? 1 : 0,
      back: false,
      children: [
        const PhotoRecoveryNotice(),
        Heading(
          widget.saved ? 'Tus favoritos.' : 'Una familia\nlo cambia todo.',
          widget.saved
              ? 'Publicaciones guardadas que siguen disponibles para adopción.'
              : 'Conoce a quienes están esperando un hogar.',
          eyebrow: widget.saved ? 'GUARDADOS' : 'ADOPTA CON DOPMI',
        ),
        if (widget.owner != null)
          TextButton(
            onPressed: () => context.go('/adoptions'),
            child: const Text('Ver toda la comunidad'),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tune),
                label: Text(
                  filters.isEmpty
                      ? 'Filtrar adopciones'
                      : 'Filtros activos (${filters.length})',
                ),
                onPressed: () async {
                  final result = await showModalBottomSheet<Json>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => CatalogFilters(filters),
                  );
                  if (mounted && result != null) {
                    setState(() {
                      filters = result;
                      page = 1;
                      revision++;
                    });
                  }
                },
              ),
            ),
            IconButton(
              tooltip: 'Actualizar catálogo',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => revision++),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LiveSection<DataPage<Adoption>>(
          key: ValueKey('$page:$revision:${widget.owner}:${widget.saved}'),
          load: () => repo.catalog({
            ...filters,
            if (widget.saved) 'saved': true,
            if (widget.owner != null) 'owner_id': widget.owner,
          }, page),
          builder: (result, refresh) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${result.total} ${result.total == 1 ? 'historia por descubrir' : 'historias por descubrir'}',
              ),
              const SizedBox(height: 12),
              if (result.items.isEmpty)
                Notice(
                  widget.saved
                      ? 'Guarda una publicación desde su detalle para encontrarla aquí. Las retiradas o adoptadas dejan de aparecer.'
                      : filters.isEmpty
                      ? 'Las primeras publicaciones aparecerán aquí cuando el equipo Dopmi las apruebe.'
                      : 'No encontramos coincidencias. Prueba con menos filtros.',
                ),
              for (final post in result.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AdoptionCard(
                    post,
                    open: () async {
                      await context.push('/adoptions/${post.id}');
                      refresh();
                    },
                  ),
                ),
              PageControls(
                page: page,
                total: result.total,
                size: 12,
                change: (value) => setState(() => page = value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdoptionCard extends StatelessWidget {
  const AdoptionCard(this.post, {super.key, required this.open});
  final Adoption post;
  final VoidCallback open;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.photos.isNotEmpty) AdoptionPhoto(post.photos.first),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    if (post.saved)
                      const Icon(
                        Icons.favorite,
                        color: purple,
                        semanticLabel: 'Guardada',
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${post.text('sex') == 'female' ? 'Hembra' : 'Macho'} · ${post.age}',
                ),
                Text('${post.text('city')}, ${post.text('region')}'),
                const SizedBox(height: 14),
                const Text(
                  'Conocer su historia →',
                  style: TextStyle(color: purple, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CatalogFilters extends StatefulWidget {
  const CatalogFilters(this.current, {super.key});
  final Json current;
  @override
  State<CatalogFilters> createState() => _CatalogFiltersState();
}

class _CatalogFiltersState extends State<CatalogFilters> {
  late Json selected = {...widget.current};
  late final city = TextEditingController(
    text: selected['city'] as String? ?? '',
  );
  late final region = TextEditingController(
    text: selected['region'] as String? ?? '',
  );
  late final query = TextEditingController(
    text: selected['query'] as String? ?? '',
  );
  @override
  void dispose() {
    city.dispose();
    region.dispose();
    query.dispose();
    super.dispose();
  }

  Widget choice(String label, String key, Map<String, String> values) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: selected[key] as String? ?? '',
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: values.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (value) => selected[key] = value,
        ),
      );
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Encuentra a tu compañero',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          choice('Especie', 'species', {
            '': 'Todas',
            'dog': 'Perros',
            'cat': 'Gatos',
          }),
          choice('Sexo', 'sex', {
            '': 'Todos',
            'female': 'Hembra',
            'male': 'Macho',
          }),
          choice('Tamaño', 'size', {
            '': 'Todos',
            'small': 'Pequeño',
            'medium': 'Mediano',
            'large': 'Grande',
          }),
          DropdownButtonFormField<String>(
            initialValue: selected['max_age'] == 11
                ? 'baby'
                : selected['min_age'] == 96
                ? 'senior'
                : selected['min_age'] == 12
                ? 'adult'
                : '',
            decoration: const InputDecoration(labelText: 'Edad'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Todas las edades')),
              DropdownMenuItem(value: 'baby', child: Text('Menos de un año')),
              DropdownMenuItem(value: 'adult', child: Text('1 a 7 años')),
              DropdownMenuItem(value: 'senior', child: Text('8 años o más')),
            ],
            onChanged: (value) {
              selected.remove('min_age');
              selected.remove('max_age');
              if (value == 'baby') selected['max_age'] = 11;
              if (value == 'adult') {
                selected['min_age'] = 12;
                selected['max_age'] = 95;
              }
              if (value == 'senior') selected['min_age'] = 96;
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: city,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Ciudad',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: region,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Estado',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: query,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Nombre o palabra en su historia',
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          ActionButton(
            'Aplicar filtros',
            onPressed: () {
              selected.addAll({
                'city': city.text.trim(),
                'region': region.text.trim(),
                'query': query.text.trim(),
              });
              selected.removeWhere(
                (key, value) => value == '' || value == null,
              );
              Navigator.pop(context, selected);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, <String, dynamic>{}),
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    ),
  );
}

class AdoptionDetailScreen extends ConsumerStatefulWidget {
  const AdoptionDetailScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<AdoptionDetailScreen> createState() => _AdoptionDetailState();
}

class _AdoptionDetailState extends ConsumerState<AdoptionDetailScreen> {
  bool busy = false;
  String? error;
  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(communityRepositoryProvider);
    return CommunityFrame(
      children: [
        LiveSection<Adoption?>(
          load: () => repo.detail(widget.id),
          builder: (post, refresh) {
            if (post == null) {
              return const Notice(
                'Esta publicación ya no está disponible. Puede estar en revisión, retirada o tener una adopción realizada.',
              );
            }
            final labels = {
              'vaccinated': 'Vacunas al día',
              'sterilized': 'Esterilización',
              'social_dogs': 'Convive con perros',
              'social_cats': 'Convive con gatos',
              'social_children': 'Convive con niñas y niños',
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final path in post.photos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AdoptionPhoto(path),
                  ),
                const SizedBox(height: 12),
                Heading(
                  post.name,
                  '${post.text('city')}, ${post.text('region')}',
                  eyebrow: 'EN ADOPCIÓN',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    post.text('species') == 'dog' ? 'Perro' : 'Gato',
                    post.text('sex') == 'female' ? 'Hembra' : 'Macho',
                    post.age,
                    {
                          'small': 'Pequeño',
                          'medium': 'Mediano',
                          'large': 'Grande',
                        }[post.text('size')] ??
                        '',
                    if (post.text('breed').isNotEmpty) post.text('breed'),
                  ].map((s) => Chip(label: Text(s))).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Mi historia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  post.text('story'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                for (final entry in labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${entry.value}: ${post.data[entry.key] == null
                          ? 'Por confirmar'
                          : post.data[entry.key] == true
                          ? 'Sí'
                          : 'No'}',
                    ),
                  ),
                if (post.text('special_care').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cuidados especiales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(post.text('special_care')),
                ],
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(post.text('publisher_name')),
                  subtitle: const Text('Conocer su perfil público'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/people/${post.owner}'),
                ),
                if (error != null) Notice(error!, isError: true),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          if (repo.userId == null) {
                            context.push('/login');
                            return;
                          }
                          perform(() async {
                            await repo.favorite(post.id, !post.saved);
                            refresh();
                          });
                        },
                  icon: Icon(
                    post.saved ? Icons.favorite : Icons.favorite_border,
                  ),
                  label: Text(
                    post.saved ? 'Quitar de guardados' : 'Guardar publicación',
                  ),
                ),
                const SizedBox(height: 12),
                if (repo.userId == post.owner)
                  ActionButton(
                    'Administrar mi publicación',
                    onPressed: () => context.push('/my-adoptions/${post.id}'),
                  )
                else
                  ActionButton(
                    'Quiero conocerle',
                    busy: busy,
                    sunny: true,
                    onPressed: () {
                      if (repo.userId == null) {
                        context.push('/login');
                        return;
                      }
                      perform(() async {
                        final id = await repo.startThread(post.id);
                        if (context.mounted) context.push('/messages/$id');
                      });
                    },
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Conversa sobre sus necesidades y acuerda una visita. Evita compartir tu dirección o datos sensibles antes de conocer a la otra persona.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => CommunityFrame(
    children: [
      LiveSection<Json?>(
        load: () => ref.read(communityRepositoryProvider).publicProfile(id),
        builder: (profile, _) {
          if (profile == null) {
            return const Notice('Este perfil público no está disponible.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: yellow,
                child: Icon(Icons.person_outline, size: 48, color: ink),
              ),
              const SizedBox(height: 24),
              Heading(
                profile['name'] as String,
                '${profile['city']}, ${profile['region']}',
                eyebrow: 'COMUNIDAD DOPMI',
              ),
              Text(
                profile['bio'] as String,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Notice(
                '${profile['adopted_count']} adopciones marcadas como realizadas por esta cuenta.',
              ),
              ActionButton(
                'Ver sus publicaciones disponibles',
                onPressed: () => context.push('/adoptions?owner=$id'),
              ),
            ],
          );
        },
      ),
    ],
  );
}
