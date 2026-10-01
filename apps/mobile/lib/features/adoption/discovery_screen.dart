import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/measurement.dart';
import '../../core/ui.dart';
import 'adopt_start_dialog.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import 'location_service.dart';
import 'discovery_filters.dart';

double discoveryMediaHeight(BuildContext context) => math.max(
  (MediaQuery.sizeOf(context).height - 220).clamp(340, 560) - 128,
  MediaQuery.textScalerOf(context).scale(200),
);

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
  int loadVersion = 0;
  double dragX = 0;
  bool dragging = false;
  int exiting = 0;
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
    final version = ++loadVersion;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        cards.clear();
        support.clear();
        index = 0;
        page = 1;
        exhausted = false;
        dragX = 0;
        dragging = false;
        exiting = 0;
      }
    });
    try {
      final result = await ref
          .read(communityRepositoryProvider)
          .discovery(Map<String, dynamic>.from(filters), page);
      if (!mounted || version != loadVersion) return;
      if (reset) {
        final opportunities = await ref
            .read(communityRepositoryProvider)
            .discoverySupport();
        if (!mounted || version != loadVersion) return;
        support.addAll(opportunities);
      }
      if (!mounted) return;
      final known = cards.map((item) => item.id).toSet();
      cards.addAll(result.items.where((item) => known.add(item.id)));
      total = result.total;
      exhausted = cards.length >= total || result.items.isEmpty;
    } catch (cause) {
      if (mounted && version == loadVersion) error = communityError(cause);
    } finally {
      if (mounted && version == loadVersion) setState(() => loading = false);
    }
  }

  Future<void> advance({required bool save, int? direction}) async {
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
        dragging = false;
        exiting = direction ?? (save ? 1 : -1);
      });
      if (!MediaQuery.disableAnimationsOf(context)) {
        await Future<void>.delayed(const Duration(milliseconds: 280));
      }
      if (!mounted) return;
      setState(() {
        index++;
        dragX = 0;
        exiting = 0;
      });
      if (!exhausted && deck.length - index <= 2) {
        page++;
        await load(reset: false);
      }
    } catch (cause) {
      if (mounted) {
        setState(() {
          error = communityError(cause);
          dragX = 0;
          dragging = false;
          exiting = 0;
        });
      }
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> contact(Adoption card) async {
    if (acting) return;
    final confirm = await confirmAdoptionContact(context);
    if (confirm != true || !mounted) return;
    setState(() => acting = true);
    try {
      final thread = await ref
          .read(communityRepositoryProvider)
          .startThread(card.id);
      await ref.read(measurementControllerProvider)?.event('contact_started');
      if (mounted) context.push('/messages/$thread');
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> refreshCard(String id) async {
    try {
      final current = await ref.read(communityRepositoryProvider).detail(id);
      if (!mounted) return;
      final position = cards.indexWhere((item) => item.id == id);
      if (position < 0) return;
      setState(() {
        if (current == null) {
          cards.removeAt(position);
          if (index >= deck.length && index > 0) index--;
        } else {
          cards[position] = current;
        }
      });
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    }
  }

  Future<void> openFilters() async {
    final result = await showDialog<Json>(
      context: context,
      barrierColor: ink.withValues(alpha: .48),
      animationStyle: AnimationStyle.noAnimation,
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
    if (acting) return;
    if (filters['species'] == species) return;
    filters['species'] = species;
    load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final items = deck;
    final current = index < items.length ? items[index] : null;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(0),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/profile/logo-paw.svg',
                  width: 40,
                  height: 40,
                  semanticsLabel: 'Dopmi',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: acting ? null : openLocation,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: ink,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            filters['city'] as String? ?? 'Elegir ubicación',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () => context.push('/notifications'),
                  icon: SvgPicture.asset(
                    'assets/profile/icon-bell.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 18,
                    children: [
                      for (final species in const [
                        ('dog', 'Perros'),
                        ('cat', 'Gatos'),
                      ])
                        TextButton(
                          onPressed: acting
                              ? null
                              : () => chooseSpecies(species.$1),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            foregroundColor: filters['species'] == species.$1
                                ? ink
                                : const Color(0xff9a9289),
                            textStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: filters['species'] == species.$1
                                  ? 28
                                  : 22,
                              fontWeight: filters['species'] == species.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                          child: Text(species.$2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Filtros',
                  onPressed: acting ? null : openFilters,
                  icon: SvgPicture.string(
                    discoveryFilterSvg,
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      filters.keys.any(
                            (key) =>
                                ['sex', 'size', 'personality'].contains(key),
                          )
                          ? ink
                          : const Color(0xff9a9289),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
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
              DiscoveryStack(
                next: index + 1 < items.length && items[index + 1] is Adoption
                    ? items[index + 1] as Adoption
                    : null,
                child: _SwipeCard(
                  current,
                  dragX: dragX,
                  dragging: dragging,
                  exiting: exiting,
                  busy: acting,
                  onDrag: (value) => setState(() => dragX = value),
                  onStart: () => setState(() => dragging = true),
                  onCancel: () => setState(() {
                    dragging = false;
                    dragX = 0;
                  }),
                  onEnd: () {
                    if (dragX.abs() <= 110) {
                      setState(() {
                        dragging = false;
                        dragX = 0;
                      });
                    } else {
                      advance(save: dragX > 0);
                    }
                  },
                  pass: () => advance(save: false),
                  like: () => advance(save: true),
                  contact: () => contact(current),
                  open: () async {
                    await context.push(
                      '/adoptions/${current.id}',
                      extra: current.data['distance_km'],
                    );
                    if (mounted) await refreshCard(current.id);
                  },
                ),
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
        ),
      ),
    );
  }
}

class DiscoveryStack extends StatelessWidget {
  const DiscoveryStack({super.key, required this.child, this.next});
  final Widget child;
  final Adoption? next;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: discoveryMediaHeight(context) + 128,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        for (final far in [true, false])
          Positioned(
            top: far ? 14 : 7,
            left: far ? 22 : 11,
            right: far ? 22 : 11,
            bottom: far ? 0 : 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2415110d),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
        if (next != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 16,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: next!.photos.isEmpty
                        ? const ColoredBox(color: Color(0xffcfc9c0))
                        : AdoptionPhoto(next!.photos.first),
                  ),
                ),
              ),
            ),
          ),
        Positioned(top: 0, left: 0, right: 0, bottom: 16, child: child),
      ],
    ),
  );
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
    required this.dragging,
    required this.exiting,
    required this.busy,
    required this.onDrag,
    required this.onStart,
    required this.onCancel,
    required this.onEnd,
    required this.pass,
    required this.like,
    required this.contact,
    required this.open,
  });
  final Adoption post;
  final double dragX;
  final bool dragging;
  final int exiting;
  final bool busy;
  final ValueChanged<double> onDrag;
  final VoidCallback onStart, onCancel, onEnd, pass, like, contact, open;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    key: ValueKey('discovery-motion-${post.id}'),
    duration: MediaQuery.disableAnimationsOf(context) || dragging
        ? Duration.zero
        : Duration(milliseconds: exiting == 0 ? 250 : 280),
    curve: const Cubic(.22, 1, .36, 1),
    transform: Matrix4.identity()
      ..translateByDouble(exiting == 0 ? dragX : exiting * 420, 0, 0, 1)
      ..rotateZ((exiting == 0 ? dragX / 28 : exiting * 18) * math.pi / 180),
    transformAlignment: Alignment.center,
    child: AnimatedOpacity(
      opacity: exiting == 0 ? 1 : .35,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.ease,
      child: GestureDetector(
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: busy ? null : (_) => onStart(),
        onHorizontalDragUpdate: busy
            ? null
            : (event) => onDrag(dragX + event.delta.dx),
        onHorizontalDragEnd: busy ? null : (_) => onEnd(),
        onHorizontalDragCancel: busy ? null : onCancel,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0f15110d),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
              BoxShadow(
                color: Color(0x2415110d),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
              BoxShadow(
                color: Color(0x1f15110d),
                blurRadius: 56,
                offset: Offset(0, 28),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Material(
              color: Colors.white,
              child: Column(
                children: [
                  InkWell(
                    onTap: busy ? null : open,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: discoveryMediaHeight(context),
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
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Color(0x8c15110d),
                                      Color(0xe015110d),
                                      Color(0xf015110d),
                                    ],
                                    stops: [0, .36, .63, .86, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 14,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.name,
                                      style: const TextStyle(
                                        fontFamily: 'Fraunces',
                                        fontSize: 28,
                                        height: 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${post.text('city')}, ${post.text('region')}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    if (post.data['distance_km'] != null)
                                      Text(
                                        '${post.data['distance_km']} km aprox.',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      post.text('story'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children:
                                          [
                                                post.text('sex') == 'female'
                                                    ? 'Hembra'
                                                    : 'Macho',
                                                {
                                                      'small': 'Chico',
                                                      'medium': 'Mediano',
                                                      'large': 'Grande',
                                                    }[post.text('size')] ??
                                                    '',
                                              ]
                                              .map(
                                                (label) => Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0x7315110d,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0x2effffff,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    label,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                      letterSpacing: 0,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DiscoveryControl(
                          label: 'Pasar',
                          icon: Icons.close,
                          hot: dragX < -12 || exiting < 0,
                          pass: true,
                          onPressed: busy ? null : pass,
                        ),
                        const SizedBox(width: 18),
                        DiscoveryControl(
                          label: 'Contactar',
                          icon: Icons.chat_bubble_outline,
                          message: true,
                          onPressed: busy ? null : contact,
                        ),
                        const SizedBox(width: 18),
                        DiscoveryControl(
                          label: 'Me gusta',
                          icon: Icons.favorite_border,
                          hot: dragX > 12 || exiting > 0,
                          onPressed: busy ? null : like,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class DiscoveryControl extends StatelessWidget {
  const DiscoveryControl({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.hot = false,
    this.pass = false,
    this.message = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool hot, pass, message;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final fill = message
        ? ink
        : hot
        ? (pass ? const Color(0xffd92d20) : yellow)
        : Colors.white;
    final foreground = message || (hot && pass)
        ? Colors.white
        : pass
        ? const Color(0xff8a837c)
        : ink;
    return AnimatedScale(
      scale: hot ? 1.14 : 1,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: const Cubic(.22, 1, .36, 1),
      child: AnimatedContainer(
        width: message ? 64 : 58,
        height: message ? 64 : 58,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.ease,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            width: 1.5,
            color: hot || message
                ? Colors.transparent
                : const Color(0xffe4e0d9),
          ),
          boxShadow: [
            BoxShadow(
              color: hot
                  ? fill.withValues(alpha: .35)
                  : ink.withValues(alpha: message ? .28 : .08),
              blurRadius: hot
                  ? 24
                  : message
                  ? 20
                  : 12,
              offset: Offset(
                0,
                hot
                    ? 10
                    : message
                    ? 8
                    : 4,
              ),
            ),
          ],
        ),
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: SvgPicture.asset(
            'assets/profile/${message
                ? 'discovery-message.svg'
                : pass
                ? 'icon-x-muted.svg'
                : 'icon-heart.svg'}',
            width: message ? 24 : 26,
            height: message ? 24 : 26,
            colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
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
