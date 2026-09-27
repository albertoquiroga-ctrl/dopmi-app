import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import 'location_service.dart';

const personalityLabels = <String, String>{
  'affectionate': 'Cariñoso',
  'playful': 'Juguetón',
  'calm': 'Tranquilo',
  'active': 'Activo',
  'sociable': 'Sociable',
  'independent': 'Independiente',
};

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final cards = <Adoption>[];
  final support = <SupportOpportunity>[];
  Json filters = {'species': 'dog'};
  int index = 0, page = 1, total = 0;
  double dragX = 0;
  bool loading = true, acting = false, exhausted = false;
  String? error;

  List<Object> get deck {
    final result = <Object>[];
    var supportIndex = 0;
    for (var petIndex = 0; petIndex < cards.length; petIndex++) {
      result.add(cards[petIndex]);
      if ((petIndex + 1) % 2 == 0 && supportIndex < support.length) {
        result.add(support[supportIndex++]);
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({required bool reset}) async {
    if (loading && !reset && cards.isNotEmpty) return;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        cards.clear();
        support.clear();
        index = 0;
        page = 1;
        exhausted = false;
      }
    });
    try {
      final result = await ref
          .read(communityRepositoryProvider)
          .discovery(filters, page);
      if (reset) {
        support.addAll(
          await ref.read(communityRepositoryProvider).discoverySupport(),
        );
      }
      if (!mounted) return;
      final known = cards.map((item) => item.id).toSet();
      cards.addAll(result.items.where((item) => known.add(item.id)));
      total = result.total;
      exhausted = cards.length >= total || result.items.isEmpty;
    } catch (cause) {
      if (mounted) error = communityError(cause);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> advance({required bool save}) async {
    final items = deck;
    if (acting || index >= items.length) return;
    final card = items[index];
    setState(() => acting = true);
    try {
      if (card is SupportOpportunity && save) {
        if (mounted) {
          setState(() => index++);
          context.push('/contribute/${card.expenseId}');
        }
        return;
      }
      if (card is Adoption && save && !card.saved) {
        await ref.read(communityRepositoryProvider).favorite(card.id, true);
        final position = cards.indexWhere((item) => item.id == card.id);
        if (position >= 0) {
          cards[position] = Adoption({...card.data, 'saved': true});
        }
      }
      if (!mounted) return;
      setState(() {
        index++;
        dragX = 0;
      });
      if (!exhausted && deck.length - index <= 2) {
        page++;
        await load(reset: false);
      }
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> contact(Adoption card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Iniciamos el proceso?'),
        content: Text('Abriremos una conversación sobre ${card.name}.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Contactar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => acting = true);
    try {
      final thread = await ref
          .read(communityRepositoryProvider)
          .startThread(card.id);
      if (mounted) context.push('/messages/$thread');
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> openFilters() async {
    final result = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DiscoveryFilters(filters),
    );
    if (result != null && mounted) {
      filters.removeWhere(
        (key, _) => ['sex', 'size', 'personality'].contains(key),
      );
      filters.addAll(result);
      await load(reset: true);
    }
  }

  Future<void> openLocation() async {
    final result = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DiscoveryLocation(filters),
    );
    if (result != null && mounted) {
      filters.removeWhere(
        (key, _) => [
          'city',
          'region',
          'latitude',
          'longitude',
          'radius_km',
        ].contains(key),
      );
      filters.addAll(result);
      await load(reset: true);
    }
  }

  void chooseSpecies(String species) {
    if (filters['species'] == species) return;
    filters['species'] = species;
    load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final items = deck;
    final current = index < items.length ? items[index] : null;
    return CommunityFrame(
      index: 0,
      back: false,
      showNotifications: false,
      showAppBar: false,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              child: Icon(Icons.pets),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: openLocation,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(filters['city'] as String? ?? 'Elegir ubicación'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              ),
            ),
            IconButton(
              tooltip: 'Mis match',
              onPressed: () => context.push('/messages'),
              icon: const Icon(Icons.favorite_border),
            ),
            IconButton(
              tooltip: 'Notificaciones',
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'dog', label: Text('Perros')),
                  ButtonSegment(value: 'cat', label: Text('Gatos')),
                ],
                selected: {filters['species'] as String},
                onSelectionChanged: (value) => chooseSpecies(value.first),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Filtros',
              onPressed: openFilters,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (error != null) ...[
          Notice(error!, isError: true),
          TextButton(
            onPressed: () => load(reset: cards.isEmpty),
            child: const Text('Volver a intentar'),
          ),
        ],
        if (loading && cards.isEmpty)
          const SizedBox(
            height: 420,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (current == null)
          _DeckEnd(
            filtered: filters.keys.any((key) => key != 'species'),
            restart: () => setState(() => index = 0),
            filters: openFilters,
          )
        else if (current is Adoption)
          _SwipeCard(
            current,
            dragX: dragX,
            busy: acting,
            onDrag: (value) => setState(() => dragX = value),
            onEnd: () {
              if (dragX.abs() < 95) {
                setState(() => dragX = 0);
              } else {
                advance(save: dragX > 0);
              }
            },
            pass: () => advance(save: false),
            like: () => advance(save: true),
            contact: () => contact(current),
            open: () async {
              await context.push('/adoptions/${current.id}');
              if (mounted) await load(reset: true);
            },
          )
        else
          _SupportCard(
            current as SupportOpportunity,
            busy: acting,
            pass: () => advance(save: false),
            support: () => advance(save: true),
            open: () => context.push('/rescue-cases/${current.id}'),
          ),
      ],
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard(
    this.item, {
    required this.busy,
    required this.pass,
    required this.support,
    required this.open,
  });
  final SupportOpportunity item;
  final bool busy;
  final VoidCallback pass, support, open;
  @override
  Widget build(BuildContext context) {
    final progress = item.reimbursable == 0
        ? 0.0
        : (item.funded / item.reimbursable).clamp(0, 1).toDouble();
    return Card(
      color: const Color(0xfffff6cf),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.volunteer_activism, size: 54, color: purple),
            const SizedBox(height: 18),
            const Text('También puedes cambiar su historia apoyando'),
            const SizedBox(height: 8),
            Text(item.name, style: Theme.of(context).textTheme.headlineMedium),
            Text(item.text('expense_title')),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text('${(progress * 100).round()} % cubierto'),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: busy ? null : open,
              child: const Text('Ver caso'),
            ),
            FilledButton(
              onPressed: busy ? null : support,
              child: const Text('Apoyar este gasto'),
            ),
            TextButton(
              onPressed: busy ? null : pass,
              child: const Text('Seguir descubriendo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard(
    this.post, {
    required this.dragX,
    required this.busy,
    required this.onDrag,
    required this.onEnd,
    required this.pass,
    required this.like,
    required this.contact,
    required this.open,
  });
  final Adoption post;
  final double dragX;
  final bool busy;
  final ValueChanged<double> onDrag;
  final VoidCallback onEnd, pass, like, contact, open;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    transform: Matrix4.identity()
      ..translateByDouble(dragX, 0, 0, 1)
      ..rotateZ(dragX / 900),
    transformAlignment: Alignment.bottomCenter,
    child: GestureDetector(
      onHorizontalDragUpdate: busy
          ? null
          : (event) => onDrag((dragX + event.delta.dx).clamp(-180, 180)),
      onHorizontalDragEnd: busy ? null : (_) => onEnd(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: open,
              child: SizedBox(
                height: 390,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (post.photos.isEmpty)
                      const ColoredBox(
                        color: Color(0xffeeeae5),
                        child: Icon(Icons.pets, size: 80),
                      )
                    else
                      AdoptionPhoto(post.photos.first),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xcc17131c)],
                          stops: [0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          Text(
                            '${post.text('city')}, ${post.text('region')}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (post.data['distance_km'] != null)
                            Text(
                              '${post.data['distance_km']} km aprox.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            post.text('story'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              post.text('sex') == 'female' ? 'Hembra' : 'Macho',
                              {
                                    'small': 'Chico',
                                    'medium': 'Mediano',
                                    'large': 'Grande',
                                  }[post.text('size')] ??
                                  '',
                            ].map((label) => Chip(label: Text(label))).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Pasar',
                    onPressed: busy ? null : pass,
                    icon: const Icon(Icons.close),
                  ),
                  IconButton.filled(
                    tooltip: 'Contactar',
                    onPressed: busy ? null : contact,
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Me gusta',
                    onPressed: busy ? null : like,
                    icon: const Icon(Icons.favorite_border),
                  ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}

class _DeckEnd extends StatelessWidget {
  const _DeckEnd({
    required this.filtered,
    required this.restart,
    required this.filters,
  });
  final bool filtered;
  final VoidCallback restart, filters;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70),
    child: Column(
      children: [
        const Icon(Icons.pets, size: 72, color: purple),
        const SizedBox(height: 20),
        Text(
          'Nuestra manada llegó hasta aquí por ahora',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          filtered ? 'Ajusta los filtros para descubrir más historias.' : 'El catálogo se actualiza cuando Dopmi aprueba nuevas publicaciones.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: filtered ? filters : restart,
          child: Text(filtered ? 'Ajustar filtros' : 'Volver a descubrir'),
        ),
        TextButton(
          onPressed: () => context.push('/saved'),
          child: const Text('Ir a mis favoritos'),
        ),
      ],
    ),
  );
}

class DiscoveryFilters extends StatefulWidget {
  const DiscoveryFilters(this.current, {super.key});
  final Json current;
  @override
  State<DiscoveryFilters> createState() => _DiscoveryFiltersState();
}

class _DiscoveryFiltersState extends State<DiscoveryFilters> {
  late String? sex = widget.current['sex'] as String?;
  late String? size = widget.current['size'] as String?;
  late Set<String> traits = Set<String>.from(
    widget.current['personality'] as List? ?? const [],
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filtros', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          const Text('Género'),
          Wrap(
            spacing: 8,
            children: {'female': 'Hembra', 'male': 'Macho'}.entries
                .map(
                  (entry) => FilterChip(
                    label: Text(entry.value),
                    selected: sex == entry.key,
                    onSelected: (_) => setState(
                      () => sex = sex == entry.key ? null : entry.key,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Tamaño'),
          Wrap(
            spacing: 8,
            children: {'small': 'Chico', 'medium': 'Mediano', 'large': 'Grande'}
                .entries
                .map(
                  (entry) => FilterChip(
                    label: Text(entry.value),
                    selected: size == entry.key,
                    onSelected: (_) => setState(
                      () => size = size == entry.key ? null : entry.key,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Personalidad'),
          Wrap(
            spacing: 8,
            children: personalityLabels.entries
                .map(
                  (entry) => FilterChip(
                    label: Text(entry.value),
                    selected: traits.contains(entry.key),
                    onSelected: (selected) => setState(
                      () => selected
                          ? traits.add(entry.key)
                          : traits.remove(entry.key),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(<String, dynamic>{
              if (sex != null) 'sex': sex,
              if (size != null) 'size': size,
              if (traits.isNotEmpty) 'personality': traits.toList(),
            }),
            child: const Text('Aplicar filtros'),
          ),
          TextButton(
            onPressed: () => context.pop(<String, dynamic>{}),
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    ),
  );
}

class DiscoveryLocation extends ConsumerStatefulWidget {
  const DiscoveryLocation(this.current, {super.key});
  final Json current;
  @override
  ConsumerState<DiscoveryLocation> createState() => _DiscoveryLocationState();
}

class _DiscoveryLocationState extends ConsumerState<DiscoveryLocation> {
  late final city = TextEditingController(
    text: widget.current['city'] as String? ?? '',
  );
  late double radius = (widget.current['radius_km'] as num?)?.toDouble() ?? 10;
  ApproximateLocation? location;
  String? error;
  bool busy = false;
  @override
  void dispose() {
    city.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      location = await ref.read(locationServiceProvider).current();
    } catch (cause) {
      error = cause is LocationException
          ? cause.message
          : 'No pudimos obtener tu ubicación. Escribe tu ciudad.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
        children: [
          Text('Ubicación', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: city,
            decoration: const InputDecoration(labelText: 'Ciudad o zona'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : locate,
            icon: const Icon(Icons.my_location),
            label: const Text('Usar mi ubicación aproximada'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (location != null)
            const Text(
              'Ubicación aproximada lista. No publicaremos tus coordenadas.',
            ),
          if (error != null) Notice(error!, isError: true),
          const SizedBox(height: 16),
          Text('Radio aproximado: ${radius.round()} km'),
          Slider(
            value: radius,
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: location == null
                ? null
                : (value) => setState(() => radius = value),
          ),
          FilledButton(
            onPressed: () => context.pop(<String, dynamic>{
              if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
              if (location != null) ...{
                'latitude': location!.roundedLatitude,
                'longitude': location!.roundedLongitude,
                'radius_km': radius.round(),
              },
            }),
            child: const Text('Aplicar cambios'),
          ),
          TextButton(
            onPressed: () => context.pop(<String, dynamic>{}),
            child: const Text('Buscar sin ubicación'),
          ),
        ],
      ),
    ),
  );
}
