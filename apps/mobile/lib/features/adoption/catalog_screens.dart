import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import '../../core/content_links.dart';
import '../../core/measurement.dart';
import '../community/content_actions.dart';
import '../profile/rescuer_profile_repository.dart';
import 'adopt_start_dialog.dart';
import 'adoption_detail_layout.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import 'photo_recovery.dart';
import 'public_profile_layout.dart';
import 'public_profile_body.dart';

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
  const AdoptionDetailScreen(this.id, {super.key, this.distanceKm});
  final num? distanceKm;
  final String id;
  @override
  ConsumerState<AdoptionDetailScreen> createState() => _AdoptionDetailState();
}

class _AdoptionDetailState extends ConsumerState<AdoptionDetailScreen> {
  bool busy = false;
  bool? savedOverride;
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

  Future<void> toggleFavorite(
    CommunityRepository repo,
    Adoption post,
    VoidCallback refresh,
  ) async {
    if (busy) return;
    final previous = savedOverride ?? post.saved;
    final next = !previous;
    setState(() {
      busy = true;
      error = null;
      savedOverride = next;
    });
    try {
      await repo.favorite(post.id, next);
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

  Future<void> share(Adoption post) async {
    await shareContent(
      context,
      'Conoce la historia de ${post.name} en Dopmi. ${publicContentLink(PublicContent.adoption, post.id)}',
    );
  }

  Future<void> report(CommunityRepository repo, Adoption post) async {
    await perform(() async {
      final sent = await reportPublicContent(
        context,
        repo,
        type: 'adoption',
        id: post.id,
        title: 'Reportar publicación',
      );
      if (sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recibimos tu reporte para revisión.')),
        );
      }
    });
  }

  Future<void> contact(CommunityRepository repo, Adoption post) async {
    final confirmed = await confirmAdoptionContact(
      context,
      petName: post.name,
      rescuerName: post.text('publisher_name'),
    );
    if (confirmed != true || !mounted) return;
    await perform(() async {
      final id = await repo.startThread(post.id);
      await ref.read(measurementControllerProvider)?.event('contact_started');
      if (mounted) context.push('/messages/$id');
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(communityRepositoryProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LiveSection<Adoption?>(
          load: () => repo.detail(widget.id),
          builder: (post, refresh) {
            if (post == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Notice(
                    'Esta publicación ya no está disponible. Puede estar en revisión, retirada o tener una adopción realizada.',
                  ),
                ),
              );
            }
            return AdoptionDetailLayout(
              key: ValueKey(post.id),
              post: Adoption({
                ...post.data,
                if (widget.distanceKm?.isFinite == true &&
                    widget.distanceKm! >= 0)
                  'distance_km': widget.distanceKm,
              }),
              saved: savedOverride ?? post.saved,
              busy: busy,
              owner: repo.userId == post.owner,
              error: error,
              share: () => share(post),
              report: () {
                if (repo.userId == null) {
                  context.push('/login');
                } else {
                  report(repo, post);
                }
              },
              favorite: () {
                if (repo.userId == null) {
                  context.push('/login');
                } else {
                  toggleFavorite(repo, post, refresh);
                }
              },
              contact: () {
                if (repo.userId == post.owner) {
                  context.push('/my-adoptions/${post.id}');
                } else if (repo.userId == null) {
                  context.push('/login');
                } else {
                  contact(repo, post);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileState();
}

class _PublicProfileState extends ConsumerState<PublicProfileScreen> {
  String? lastAvatarPath;
  @override
  void didUpdateWidget(PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      lastAvatarPath = null;
      savedOverride = null;
      busy = false;
      error = null;
    }
  }

  Future<Json?> loadPublicProfile() async {
    final requestedId = widget.id;
    final repo = ref.read(communityRepositoryProvider);
    final actor = repo.userId;
    final profile = await repo.publicProfile(requestedId);
    if (!mounted || widget.id != requestedId || repo.userId != actor) {
      return null;
    }
    if (mounted && widget.id == requestedId) {
      final path = profile?['avatar_path'] as String?;
      final previous = lastAvatarPath;
      if (previous != null && previous != path) {
        ref
            .read(photoRuntimeProvider)
            .invalidate(
              PhotoRef(
                path: previous,
                purpose: MediaPurpose.rescuerAvatar,
                persistence: PhotoPersistence.ordinary,
                sign: () => ref
                    .read(rescuerProfileRepositoryProvider)
                    .avatarUrl(previous),
              ),
              removeDisk: true,
            )
            .ignore();
      }
      lastAvatarPath = path;
    }
    return profile;
  }

  bool busy = false;
  bool? savedOverride;
  String? error;

  Future<void> toggle(Json profile, VoidCallback refresh) async {
    if (busy) return;
    final repo = ref.read(communityRepositoryProvider);
    final actor = repo.userId;
    final id = widget.id;
    bool current() => mounted && widget.id == id && repo.userId == actor;
    final previous = savedOverride ?? profile['saved'] == true;
    setState(() {
      busy = true;
      error = null;
      savedOverride = !previous;
    });
    try {
      await repo.favoriteRescuer(id, !previous);
      if (current()) refresh();
    } catch (cause) {
      if (current()) {
        setState(() {
          savedOverride = previous;
          error = communityError(cause);
        });
      }
    } finally {
      if (current()) setState(() => busy = false);
    }
  }

  Future<void> reportProfile() async {
    if (busy) return;
    final repo = ref.read(communityRepositoryProvider);
    final actor = repo.userId;
    final id = widget.id;
    bool current() => mounted && widget.id == id && repo.userId == actor;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final sent = await reportPublicContent(
        context,
        repo,
        type: 'rescuer',
        id: id,
        title: 'Reportar rescatista',
      );
      if (sent && current() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recibimos tu reporte para revisión.')),
        );
      }
    } catch (cause) {
      if (current()) {
        setState(() => error = communityError(cause));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error!)));
        }
      }
    } finally {
      if (current()) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PublicProfileFrame(
    share: () => shareContent(
      context,
      'Conoce este perfil en Dopmi. ${publicContentLink(PublicContent.profile, widget.id)}',
    ),
    child: LiveSection<Json?>(
      key: ValueKey(
        '${widget.id}:${ref.read(communityRepositoryProvider).userId}',
      ),
      load: loadPublicProfile,
      builder: (profile, refresh) {
        if (profile == null) {
          return const Notice('Este perfil público no está disponible.');
        }
        final saved = savedOverride ?? profile['saved'] == true;
        final adoptions = (profile['adoptions'] as List? ?? [])
            .map((value) => Adoption(Json.from(value as Map)))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PublicProfileBody(
              key: ValueKey(
                '${widget.id}:${ref.read(communityRepositoryProvider).userId}',
              ),
              profile: profile,
              avatar: _PublicRescuerAvatar(
                profile['avatar_path'] as String?,
                profile['name'] as String,
              ),
              report:
                  busy || ref.read(communityRepositoryProvider).userId == null
                  ? null
                  : reportProfile,
            ),
            if (error != null) Notice(error!, isError: true),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        busy ||
                            ref.read(communityRepositoryProvider).userId ==
                                widget.id
                        ? null
                        : () => toggle(profile, refresh),
                    icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
                    label: Text(saved ? 'Guardado' : 'Guardar'),
                  ),
                ),
              ],
            ),
            if (adoptions.isNotEmpty)
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final repo = ref.read(communityRepositoryProvider);
                        final actor = repo.userId;
                        final profileId = widget.id;
                        bool current() =>
                            mounted &&
                            widget.id == profileId &&
                            repo.userId == actor;
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('¿Enviar mensaje?'),
                            content: Text(
                              'Abriremos una conversación sobre ${adoptions.first.data['pet_name']}.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Ahora no'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Continuar'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !current()) return;
                        setState(() => busy = true);
                        try {
                          final thread = await repo.startThread(
                            adoptions.first.id,
                          );
                          if (!current()) return;
                          await ref
                              .read(measurementControllerProvider)
                              ?.event('contact_started');
                          if (current() && context.mounted) {
                            context.push('/messages/$thread');
                          }
                        } catch (cause) {
                          if (current()) {
                            setState(() => error = communityError(cause));
                          }
                        } finally {
                          if (current()) setState(() => busy = false);
                        }
                      },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Enviar mensaje'),
              ),
          ],
        );
      },
    ),
  );
}

class _PublicRescuerAvatar extends ConsumerWidget {
  const _PublicRescuerAvatar(this.path, this.name);
  final String? path;
  final String name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Center(
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Color(0xff6b5000),
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 88,
        height: 88,
        child: ColoredBox(
          color: const Color(0xfffff2b8),
          child: path == null || path!.isEmpty
              ? fallback
              : RemotePhoto(
                  source: PhotoRef(
                    path: path!,
                    purpose: MediaPurpose.rescuerAvatar,
                    persistence: PhotoPersistence.ordinary,
                    sign: () => ref
                        .read(rescuerProfileRepositoryProvider)
                        .avatarUrl(path!),
                  ),
                  width: 88,
                  height: 88,
                  loading: fallback,
                  unavailable: (retry) => Tooltip(
                    message: 'Reintentar foto de perfil',
                    child: Semantics(
                      button: true,
                      label: 'Reintentar foto de perfil',
                      child: InkWell(onTap: retry, child: fallback),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
