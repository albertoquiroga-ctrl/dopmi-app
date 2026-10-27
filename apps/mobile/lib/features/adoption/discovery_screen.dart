import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/measurement.dart';
import '../../core/adoption_view_day.dart';
import '../../core/media/photo_prefetch.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/donor_notification_button.dart';
import '../../core/ui.dart';
import '../../core/design_tokens.dart';
import '../../core/donor_canvas.dart';
import 'adopt_start_dialog.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import '../rescue/rescue_repository.dart';
import '../rescue/rescue_public_photo.dart';
import 'location_service.dart';
import 'discovery_filters.dart';
import 'discovery_empty.dart';
import 'discovery_card_motion.dart';
import 'discovery_drag_surface.dart';

double discoveryMediaHeight(BuildContext context) => math.max(
  (MediaQuery.sizeOf(context).height - 220).clamp(340, 560) - 128,
  MediaQuery.textScalerOf(context).scale(200),
);

String cardIdentity(Object item) => item is Adoption
    ? 'adoption:${item.id}'
    : 'support:${(item as SupportOpportunity).expenseId}';

double discoveryExitTranslation({
  required Size cardSize,
  required double viewportWidth,
  required double centerX,
  required double dragX,
  required int direction,
}) {
  const radians = 18 * math.pi / 180;
  final rotatedHalfWidth =
      (cardSize.width * math.cos(radians) +
          cardSize.height * math.sin(radians)) /
      2;
  final edgeDistance = direction > 0 ? viewportWidth - centerX : centerX;
  final distance = math.max(
    edgeDistance + rotatedHalfWidth + 16,
    dragX.abs() + 16,
  );
  return direction * distance;
}

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
  final deckKey = GlobalKey();
  int transitionSerial = 0;
  int hintRevision = 0;
  Object? outgoingSnapshot, nextSnapshot;
  double exitTranslation = 0;
  bool loading = true, acting = false, exhausted = false;
  bool allSpeciesEmpty = false;
  String? error;
  final pendingFavorites = <String>{};
  final failedFavorites = <String, Adoption>{};
  final reportedViews = <String>{};

  Future<void> reportFrontView(Adoption post) async {
    final items = deck;
    final front =
        outgoingSnapshot ?? (index < items.length ? items[index] : null);
    if (front is! Adoption || front.id != post.id) return;
    final measurement = ref.read(measurementControllerProvider);
    final repository = ref.read(communityRepositoryProvider);
    final actor = repository.userId;
    if (actor == null ||
        actor == post.data['owner_id'] ||
        measurement == null ||
        measurement.ownerId != actor ||
        !measurement.analyticsEnabled ||
        exiting != 0) {
      return;
    }
    final key = '$actor:${post.id}:${adoptionViewDay(DateTime.now())}';
    if (!reportedViews.add(key)) return;
    await measurement.consentReady;
    if (!mounted) {
      reportedViews.remove(key);
      return;
    }
    final currentItems = deck;
    final currentFront =
        outgoingSnapshot ??
        (index < currentItems.length ? currentItems[index] : null);
    if (repository.userId != actor ||
        !identical(ref.read(communityRepositoryProvider), repository) ||
        currentFront is! Adoption ||
        currentFront.id != post.id ||
        exiting != 0 ||
        measurement.ownerId != actor ||
        !measurement.analyticsEnabled) {
      reportedViews.remove(key);
      return;
    }
    try {
      await repository.recordAdoptionView(post.id, consent: true);
    } catch (_) {
      reportedViews.remove(key);
    }
  }

  Future<void> persistFavorite(Adoption card) async {
    if (!mounted || !pendingFavorites.add(card.id)) return;
    setState(() {});
    try {
      await ref.read(communityRepositoryProvider).favorite(card.id, true);
      if (!mounted) return;
      setState(() {
        failedFavorites.remove(card.id);
        final position = cards.indexWhere((item) => item.id == card.id);
        if (position >= 0) {
          cards[position] = Adoption({...cards[position].data, 'saved': true});
        }
      });
    } catch (cause) {
      if (mounted) setState(() => failedFavorites[card.id] = card);
    } finally {
      if (mounted) setState(() => pendingFavorites.remove(card.id));
    }
  }

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
        hintRevision++;
        allSpeciesEmpty = false;
        cards.clear();
        support.clear();
        index = 0;
        page = 1;
        exhausted = false;
        dragX = 0;
        dragging = false;
        exiting = 0;
        transitionSerial++;
        outgoingSnapshot = null;
        nextSnapshot = null;
        acting = false;
      }
    });
    try {
      final result = await ref
          .read(communityRepositoryProvider)
          .discovery(Map<String, dynamic>.from(filters), page);
      if (!mounted || version != loadVersion) return;
      if (reset && result.total == 0 && filters.length == 1) {
        try {
          final other = await ref.read(communityRepositoryProvider).discovery({
            'species': filters['species'] == 'dog' ? 'cat' : 'dog',
          }, 1);
          if (!mounted || version != loadVersion) return;
          allSpeciesEmpty = other.total == 0;
        } catch (_) {
          // A failed alternate-category lookup cannot prove the entire catalog empty.
        }
      }
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
    if (save &&
        card is Adoption &&
        ref.read(communityRepositoryProvider).userId == null) {
      setState(() {
        dragging = false;
        dragX = 0;
      });
      await context.push('/login');
      return;
    }
    final box = deckKey.currentContext?.findRenderObject() as RenderBox?;
    final size =
        box?.size ??
        Size(
          MediaQuery.sizeOf(context).width - 36,
          discoveryMediaHeight(context) + 128,
        );
    final center =
        box?.localToGlobal(Offset(size.width / 2, 0)).dx ??
        MediaQuery.sizeOf(context).width / 2;
    final side = direction ?? (save ? 1 : -1);
    setState(() {
      acting = true;
      dragging = false;
      exiting = side;
      transitionSerial++;
      outgoingSnapshot = card;
      nextSnapshot = index + 1 < items.length ? items[index + 1] : null;
      exitTranslation = discoveryExitTranslation(
        cardSize: Size(size.width, size.height - 16),
        viewportWidth: MediaQuery.sizeOf(context).width,
        centerX: center,
        dragX: dragX,
        direction: side,
      );
    });
    if (card is Adoption && save && !card.saved) {
      unawaited(persistFavorite(card));
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      finishExit(transitionSerial, cardIdentity(card));
    }
  }

  void finishExit(int serial, String identity) {
    if (!mounted ||
        serial != transitionSerial ||
        exiting == 0 ||
        outgoingSnapshot == null ||
        cardIdentity(outgoingSnapshot!) != identity) {
      return;
    }
    setState(() {
      index++;
      dragX = 0;
      exiting = 0;
      outgoingSnapshot = null;
      nextSnapshot = null;
      acting = false;
    });
    if (!loading && !exhausted && deck.length - index <= 2) {
      page++;
      unawaited(load(reset: false));
    }
  }

  void cancelDrag() => setState(() {
    dragging = false;
    dragX = 0;
  });

  Widget cardBody(Object item, {required bool preview}) {
    final serial = transitionSerial;
    final identity = cardIdentity(item);
    final busy = acting || preview;
    final onMotionEnd = !preview && exiting != 0
        ? () => finishExit(serial, identity)
        : null;
    if (item is Adoption) {
      return _SwipeCard(
        item,
        onDisplayed: preview ? null : () => unawaited(reportFrontView(item)),
        preview: preview,
        dragX: preview ? 0 : dragX,
        dragging: !preview && dragging,
        exiting: preview ? 0 : exiting,
        exitTranslation: exitTranslation,
        onMotionEnd: onMotionEnd,
        busy: busy,
        onDragDelta: (value) => setState(() => dragX += value),
        onStart: () => setState(() => dragging = true),
        onCancel: cancelDrag,
        onEnd: () {
          if (dragX.abs() <= 110) {
            cancelDrag();
          } else {
            advance(save: dragX > 0);
          }
        },
        pass: () => advance(save: false),
        like: () => advance(save: true),
        contact: () => contact(item),
        open: () async {
          await context.push(
            '/adoptions/${item.id}',
            extra: item.data['distance_km'],
          );
          if (mounted) await refreshCard(item.id);
        },
      );
    }
    final opportunity = item as SupportOpportunity;
    return _SupportCard(
      opportunity,
      preview: preview,
      busy: busy,
      dragX: preview ? 0 : dragX,
      dragging: !preview && dragging,
      exiting: preview ? 0 : exiting,
      exitTranslation: exitTranslation,
      onMotionEnd: onMotionEnd,
      onDragDelta: (value) => setState(() => dragX += value),
      onStart: () => setState(() => dragging = true),
      onCancel: cancelDrag,
      onEnd: () {
        if (dragX.abs() <= 110) {
          cancelDrag();
        } else {
          advance(save: false, direction: dragX > 0 ? 1 : -1);
        }
      },
      pass: () => advance(save: false),
      open: () => context.push('/rescue-cases/${opportunity.id}'),
    );
  }

  Future<void> contact(Adoption card) async {
    if (acting) return;
    if (ref.read(communityRepositoryProvider).userId == null) {
      await context.push('/login');
      return;
    }
    final confirm = await confirmAdoptionContact(
      context,
      petName: card.name,
      rescuerName: card.text('publisher_name'),
    );
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
      barrierColor: const Color(0x29000000),
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
    final current =
        outgoingSnapshot ?? (index < items.length ? items[index] : null);
    final next = outgoingSnapshot != null
        ? nextSnapshot
        : (index + 1 < items.length ? items[index + 1] : null);
    final repository = ref.read(communityRepositoryProvider);
    final upcoming = <PhotoRef>[];
    for (final item in items.skip(index + 1).take(2)) {
      final path = item is Adoption
          ? (item.photos.isEmpty ? '' : item.photos.first)
          : (item as SupportOpportunity).text('photo');
      if (path.isNotEmpty) {
        upcoming.add(
          item is Adoption
              ? adoptionPhotoSource(repository, path)
              : rescuePhotoSource(ref.read(rescueRepositoryProvider), path),
        );
      }
    }
    return PhotoPrefetch(
      sources: upcoming,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        bottomNavigationBar: const CommunityNav(0),
        body: DonorCanvas(
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
              children: [
                SizedBox(
                  height: 42,
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Elegir ubicación',
                        child: TextButton(
                          onPressed: acting ? null : openLocation,
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            foregroundColor: ink,
                            padding: EdgeInsets.zero,
                            overlayColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                          ),
                          child: Semantics(
                            label: filters['city'] == null
                                ? 'Dopmi. Elegir ubicación'
                                : 'Dopmi. Ubicación: ${filters['city']}. Cambiar ubicación',
                            child: ExcludeSemantics(
                              child: Image.asset(
                                'assets/dopmi-wordmark.png',
                                width: 108,
                                height: 36,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const DonorNotificationButton(),
                    ],
                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                foregroundColor:
                                    filters['species'] == species.$1
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
                                (key) => [
                                  'sex',
                                  'size',
                                  'personality',
                                ].contains(key),
                              )
                              ? ink
                              : const Color(0xff9a9289),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: current == null && !loading ? 20 : 36),
                for (final failed in failedFavorites.values) ...[
                  Notice(
                    'No pudimos guardar a ${failed.name}. Intenta de nuevo.',
                    isError: true,
                  ),
                  TextButton(
                    onPressed: pendingFavorites.contains(failed.id)
                        ? null
                        : () => persistFavorite(failed),
                    child: const Text('Volver a intentar'),
                  ),
                ],
                if (error != null) ...[
                  Notice(error!, isError: true),
                  TextButton(
                    onPressed: () => load(reset: cards.isEmpty),
                    child: const Text('Volver a intentar'),
                  ),
                ],
                if (loading && current == null)
                  const SizedBox(
                    height: 420,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (current == null)
                  cards.isEmpty
                      ? DiscoveryEmpty(
                          filtered: filters.keys.any((key) => key != 'species'),
                          global: allSpeciesEmpty,
                          species: filters['species'] as String,
                          clear: () {
                            filters.removeWhere((key, _) => key != 'species');
                            load(reset: true);
                          },
                          switchSpecies: () {
                            filters['species'] = filters['species'] == 'dog'
                                ? 'cat'
                                : 'dog';
                            load(reset: true);
                          },
                        )
                      : DiscoveryEnd(
                          restart: () => load(reset: true),
                          minimumHeight:
                              MediaQuery.textScalerOf(context).scale(28) > 40
                              ? 0
                              : math.max(
                                  0.0,
                                  MediaQuery.sizeOf(context).height -
                                      MediaQuery.paddingOf(context).vertical -
                                      240,
                                ),
                          photos: cards
                              .where((post) => post.photos.isNotEmpty)
                              .take(4)
                              .map((post) => post.photos.first)
                              .toList(),
                        )
                else
                  DiscoveryStack(
                    key: deckKey,
                    hintRevision: hintRevision,
                    hintEnabled: !acting && !dragging && exiting == 0,
                    currentIdentity: cardIdentity(current),
                    nextIdentity: next == null ? null : cardIdentity(next),
                    footerHeight:
                        (current is SupportOpportunity ||
                                next is SupportOpportunity) &&
                            MediaQuery.textScalerOf(context).scale(16) > 22
                        ? 256
                        : 128,
                    next: next == null ? null : cardBody(next, preview: true),
                    child: cardBody(current, preview: false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoveryStack extends StatelessWidget {
  const DiscoveryStack({
    super.key,
    required this.child,
    this.next,
    required this.currentIdentity,
    this.nextIdentity,
    this.footerHeight = 128,
    this.hintRevision = 0,
    this.hintEnabled = true,
  });
  final Widget child;
  final Widget? next;
  final String currentIdentity;
  final String? nextIdentity;
  final double footerHeight;
  final Object hintRevision;
  final bool hintEnabled;
  @override
  Widget build(BuildContext context) => DiscoverySwipeHint(
    resetKey: hintRevision,
    enabled: hintEnabled,
    builder: (context, hint) => hint.wrapStage(
      SizedBox(
        height:
            discoveryMediaHeight(context) +
            math.max(
              footerHeight,
              MediaQuery.textScalerOf(context).scale(64) + 64,
            ),
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
                    gradient: _discoveryStackGradient(far: far),
                    border: Border.all(color: const Color(0xc7ffffff)),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff46281d)
                            .withValues(alpha: far ? .05 : .06),
                        blurRadius: far ? 6 : 8,
                        spreadRadius: -3,
                        offset: Offset(0, far ? 2 : 3),
                      ),
                    ],
                  ),
                ),
              ),
            if (next != null)
              Positioned(
                key: ValueKey('discovery-layer-$nextIdentity'),
                top: 0,
                left: 0,
                right: 0,
                bottom: 16,
                child: ExcludeFocus(
                  excluding: true,
                  child: ExcludeSemantics(
                    excluding: true,
                    child: IgnorePointer(
                      ignoring: true,
                      child: hint.wrapNext(next!),
                    ),
                  ),
                ),
              ),
            Positioned(
              key: ValueKey('discovery-layer-$currentIdentity'),
              top: 0,
              left: 0,
              right: 0,
              bottom: 16,
              child: ExcludeFocus(
                excluding: false,
                child: ExcludeSemantics(
                  excluding: false,
                  child: IgnorePointer(
                    ignoring: false,
                    child: hint.wrapCurrent(child),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// CSS source-over: white .18 base + white .38/.72/.82 veil.
const _discoveryVeil = LinearGradient(
  begin: Alignment(-.259, -.966),
  end: Alignment(.259, .966),
  colors: [
    Color.from(alpha: 0.4916, red: 1, green: 1, blue: 1),
    Color.from(alpha: 0.7704, red: 1, green: 1, blue: 1),
    Color.from(alpha: 0.8524, red: 1, green: 1, blue: 1),
  ],
  stops: [0, .52, 1],
);
RadialGradient _discoveryStackGradient({required bool far}) => RadialGradient(
  center: far ? Alignment.bottomLeft : Alignment.bottomRight,
  radius: 1,
  transform: _DiscoveryStackEllipse(far),
  colors: far
      ? const [
          Color(0xffcbe8fa),
          Color(0xffb8885a),
          Color(0xfffff8f3),
          Colors.white,
          Colors.white,
        ]
      : const [
          Color(0xffeb6425),
          Color(0xfffcecc0),
          Color(0xfffffaf5),
          Colors.white,
          Colors.white,
        ],
  stops: const [0, .22, .38, .55, 1],
);

/// CSS radial-gradient(120% 95% at bottom left/right), not a circle.
class _DiscoveryStackEllipse extends GradientTransform {
  const _DiscoveryStackEllipse(this.far);
  final bool far;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final shortest = math.min(bounds.width, bounds.height);
    if (shortest <= 0) return Matrix4.identity();
    final sx = bounds.width * 1.2 / shortest;
    final sy = bounds.height * .95 / shortest;
    final center = far ? bounds.bottomLeft : bounds.bottomRight;
    return Matrix4.identity()
      ..setEntry(0, 0, sx)
      ..setEntry(1, 1, sy)
      ..setEntry(0, 3, center.dx * (1 - sx))
      ..setEntry(1, 3, center.dy * (1 - sy));
  }
}

/// b9f6d5f warm-trust card layers; gesture ownership stays in the card.
class _DiscoverySurface extends StatelessWidget {
  const _DiscoverySurface({
    required this.child,
    required this.preview,
    required this.support,
  });
  final Widget child;
  final bool preview, support;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      // Preview gradients are opaque; an extra paint color would multiply
      // their alpha. Active support has only its f693 sky .9 solid fill.
      color: support && !preview
          ? const Color.from(
              alpha: .9,
              red: 203 / 255,
              green: 232 / 255,
              blue: 250 / 255,
            )
          : null,
      gradient: preview
          ? _discoveryStackGradient(far: false)
          : support
          ? null
          : _discoveryVeil,
      border: Border.all(color: const Color(0xc7ffffff)),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff46281d).withValues(alpha: preview ? .07 : .08),
          offset: Offset(0, preview ? 4 : 5),
          blurRadius: preview ? 10 : 12,
          spreadRadius: -2,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: preview || support ? 0 : 22,
          sigmaY: preview || support ? 0 : 22,
        ),
        child: child,
      ),
    ),
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard(
    this.item, {
    required this.busy,
    required this.dragX,
    required this.dragging,
    required this.exiting,
    required this.preview,
    required this.exitTranslation,
    this.onMotionEnd,
    required this.onDragDelta,
    required this.onStart,
    required this.onCancel,
    required this.onEnd,
    required this.pass,
    required this.open,
  });
  final SupportOpportunity item;
  final bool busy, dragging;
  final double dragX;
  final int exiting;
  final bool preview;
  final double exitTranslation;
  final VoidCallback? onMotionEnd;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onStart, onCancel, onEnd, pass, open;
  String amount(int cents) =>
      (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
  @override
  Widget build(BuildContext context) => DiscoveryDragSurface(
    dragStartBehavior: DragStartBehavior.down,
    onHorizontalDragStart: busy ? null : (_) => onStart(),
    onHorizontalDragUpdate: busy
        ? null
        : (event) => onDragDelta(event.delta.dx),
    onHorizontalDragEnd: busy ? null : (_) => onEnd(),
    onHorizontalDragCancel: busy ? null : onCancel,
    child: DiscoveryCardMotion(
      key: ValueKey('discovery-motion-support-${item.expenseId}'),
      onEnd: onMotionEnd,
      duration: MediaQuery.disableAnimationsOf(context) || dragging
          ? Duration.zero
          : Duration(milliseconds: exiting == 0 ? 250 : 280),
      translation: exiting == 0 ? dragX : exitTranslation,
      angleDegrees: exiting == 0 ? dragX / 28 : exiting * 18,
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Seguir descubriendo'): pass,
        },
        child: _DiscoverySurface(
          preview: preview,
          support: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  InkWell(
                    onTap: busy ? null : open,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: discoveryMediaHeight(context),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item.text('photo').isNotEmpty)
                                Consumer(
                                  builder: (context, ref, _) => AdoptionPhoto(
                                    item.text('photo'),
                                    preview: preview,
                                    radius: 0,
                                    source: rescuePhotoSource(
                                      ref.read(rescueRepositoryProvider),
                                      item.text('photo'),
                                    ),
                                  ),
                                )
                              else
                                const ColoredBox(
                                  color: Color(0xffcfc9c0),
                                  child: Icon(Icons.pets, size: 80),
                                ),
                              const IgnorePointer(
                                child: DecoratedBox(
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
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 14,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontFamily: 'Fraunces',
                                        fontSize: 28,
                                        fontVariations:
                                            DopmiTokens.display28Variations,
                                        height: 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: DopmiTokens.sky,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.text('expense_title'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        height: 1.45,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Semantics(
                                      label:
                                          '${item.reimbursable == 0 ? 0 : (item.funded / item.reimbursable * 100).round()} % cubierto',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: item.reimbursable == 0
                                              ? 0
                                              : (item.funded /
                                                        item.reimbursable)
                                                    .clamp(0, 1)
                                                    .toDouble(),
                                          minHeight: 6,
                                          color: yellow,
                                          backgroundColor: const Color(
                                            0x47ffffff,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '\$${amount(item.funded)} de \$${amount(item.reimbursable)}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                      child: InkWell(
                        onTap: busy ? null : open,
                        child: Flex(
                          direction:
                              MediaQuery.textScalerOf(context).scale(16) > 22
                              ? Axis.vertical
                              : Axis.horizontal,
                          children: [
                            const Expanded(
                              child: Text(
                                'Apoya con sus necesidades',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1f1c160c),
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/navigation/tab-donate.svg',
                                  width: 26,
                                  height: 26,
                                  colorFilter: const ColorFilter.mode(
                                    ink,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _SwipeCard extends StatelessWidget {
  const _SwipeCard(
    this.post, {
    required this.dragX,
    required this.dragging,
    required this.exiting,
    required this.preview,
    required this.exitTranslation,
    this.onMotionEnd,
    this.onDisplayed,
    required this.busy,
    required this.onDragDelta,
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
  final bool preview;
  final double exitTranslation;
  final VoidCallback? onMotionEnd;
  final VoidCallback? onDisplayed;
  final bool busy;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onStart, onCancel, onEnd, pass, like, contact, open;
  @override
  Widget build(BuildContext context) => DiscoveryDragSurface(
    dragStartBehavior: DragStartBehavior.down,
    onHorizontalDragStart: busy ? null : (_) => onStart(),
    onHorizontalDragUpdate: busy
        ? null
        : (event) => onDragDelta(event.delta.dx),
    onHorizontalDragEnd: busy ? null : (_) => onEnd(),
    onHorizontalDragCancel: busy ? null : onCancel,
    child: DiscoveryCardMotion(
      key: ValueKey('discovery-motion-${post.id}'),
      onEnd: onMotionEnd,
      duration: MediaQuery.disableAnimationsOf(context) || dragging
          ? Duration.zero
          : Duration(milliseconds: exiting == 0 ? 250 : 280),
      translation: exiting == 0 ? dragX : exitTranslation,
      angleDegrees: exiting == 0 ? dragX / 28 : exiting * 18,
      child: _DiscoverySurface(
        preview: preview,
        support: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                InkWell(
                  onTap: busy ? null : open,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                              AdoptionPhoto(
                                post.photos.first,
                                preview: preview,
                                onDisplayed: onDisplayed,
                              ),
                            const IgnorePointer(
                              child: DecoratedBox(
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
                                      fontFamily: 'Inter',
                                      fontSize: 28,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                      color: DopmiTokens.yellow,
                                      letterSpacing: -.56,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x59000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/profile/location.svg',
                                        width: 12,
                                        height: 12,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${post.text('city')}, ${post.text('region')}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.55,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                              if ((post.data['personality']
                                                          as List? ??
                                                      const [])
                                                  .isNotEmpty)
                                                personalityLabels[(post
                                                                .data['personality']
                                                            as List)
                                                        .first] ??
                                                    legacyPersonalityLabels[(post
                                                                .data['personality']
                                                            as List)
                                                        .first] ??
                                                    (post.data['personality']
                                                            as List)
                                                        .first
                                                        .toString(),
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
                                                    0x33ffffff,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0x6bffffff,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  label,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    height: 1.2,
                                                    fontWeight: FontWeight.w700,
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
    final fill = message ? DopmiTokens.orange : Colors.white;
    final foreground = message
        ? Colors.white
        : hot
        ? (pass ? ink : yellow)
        : DopmiTokens.navigationInactive;
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
            width: hot && !message ? 2 : 1,
            color: message
                ? Colors.transparent
                : hot
                ? (pass ? ink : yellow)
                : DopmiTokens.line,
          ),
          boxShadow: message
              ? const [
                  BoxShadow(
                    color: Color(0x47eb6425),
                    offset: Offset(0, 8),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: SvgPicture.asset(
            !message && !pass && hot
                ? 'assets/navigation/nav-heart-solid.svg'
                : 'assets/profile/${message
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
