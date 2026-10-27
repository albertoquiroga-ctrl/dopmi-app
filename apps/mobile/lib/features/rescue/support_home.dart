import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/donor_notification_button.dart';
import '../../core/ui.dart';
import '../../core/design_tokens.dart';
import '../../core/donor_canvas.dart';
import '../../core/reference_focus_outline.dart';
import '../../core/media/remote_photo.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../adoption/discovery_card_motion.dart';
import 'rescue_repository.dart';
import 'rescue_public_photo.dart';
import 'support_stories.dart';

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({
    super.key,
    required this.data,
    required this.page,
    required this.error,
    required this.changePage,
    this.status,
    this.onGuardianReturn,
  });
  final DataPage<RescueRecord> data;
  final int page;
  final String? error;
  final ValueChanged<int> changePage;
  final Widget? status;
  final VoidCallback? onGuardianReturn;

  Future<void> openGuardian(BuildContext context) async {
    await context.push('/guardian?enroll=1');
    if (context.mounted) onGuardianReturn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final eligible = data.items
        .where(
          (item) => item.targetCents > 0 && item.fundedCents < item.targetCents,
        )
        .toList();
    final scaler = MediaQuery.textScalerOf(context);
    final large = scaler.scale(14) > 20;
    final dockFlows = _guardianDockStacks(
      context,
      MediaQuery.sizeOf(context).width - 57,
    );
    // The donor navigation surface is 48px icons plus 20px vertical padding.
    // Its SafeArea uses at least 14px. The outer extended Scaffold also exposes
    // the real occupied height through MediaQuery.padding; honor the larger one.
    final navigationHeight = math.max(
      MediaQuery.paddingOf(context).bottom,
      68.0 + math.max(14.0, MediaQuery.viewPaddingOf(context).bottom),
    );
    final dockBottom = navigationHeight + 10.0;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: DonorCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    sliver: SliverList.list(
                      children: [
                        SizedBox(
                          height: 42,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SvgPicture.asset(
                                'assets/profile/logo-paw-naranja.svg',
                                width: 40,
                                height: 40,
                                semanticsLabel: 'Dopmi',
                              ),
                              const DonorNotificationButton(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (error != null) Notice(error!, isError: true),
                        if (status != null)
                          status!
                        else if (eligible.isNotEmpty)
                          SizedBox(
                            height: 100 + scaler.scale(26.4) + (large ? 4 : 0),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                              scrollDirection: Axis.horizontal,
                              itemCount: eligible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (_, index) => SupportCaseRing(
                                eligible[index],
                                queue: eligible.sublist(index),
                              ),
                            ),
                          )
                        else
                          Semantics(
                            liveRegion: true,
                            label: 'No hay casos para apoyar. Por ahora no hay gastos aprobados disponibles.',
                            child: const SizedBox.shrink(),
                          ),
                        if (data.total > 20)
                          PageControls(
                            page: page,
                            total: data.total,
                            size: 20,
                            change: changePage,
                          ),
                        SizedBox(
                          height: eligible.isEmpty && status == null ? 24 : 12,
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final heroWidth = constraints.crossAxisExtent - 20;
                        final dockHeight = _guardianDockHeight(
                          context,
                          // At normal text size the reference row starts at
                          // x=36 and its 17px CTA ends near the right edge.
                          // Reserve the height using the same width as the
                          // positioned dock, including its asymmetric inset.
                          constraints.crossAxisExtent - (dockFlows ? 36 : 21),
                        );
                        final bottom = dockBottom;
                        // The reference crops only the poster's outer artwork.
                        // Its embedded chip/headline must survive a short screen;
                        // enlarged text uses the complete source poster instead.
                        final posterHeight = heroWidth * 1280 / 720;
                        final minimumPosterHeight = large
                            ? posterHeight
                            : math.min(
                                posterHeight,
                                math.max(360.0, heroWidth * 1104 / 720),
                              );
                        // Rotated cards and the active card's shadow extend
                        // below the deck. Keep the flowing price outside them.
                        final deckFootprint = dockFlows ? 44.0 : 12.0;
                        final height = math.max(
                          minimumPosterHeight,
                          math.min(
                            posterHeight,
                            constraints.viewportMainAxisExtent -
                                constraints.precedingScrollExtent -
                                dockHeight -
                                bottom -
                                deckFootprint,
                          ),
                        );
                        return SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: GuardianSupportCard(
                                  height: height,
                                  onOpenEnrollment: () => openGuardian(context),
                                ),
                              ),
                              SizedBox(height: deckFootprint),
                              if (dockFlows)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  child: GuardianSupportDock(
                                    onOpenEnrollment: () =>
                                        openGuardian(context),
                                  ),
                                )
                              else
                                SizedBox(height: dockHeight),
                              SizedBox(height: bottom),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (!dockFlows)
                Positioned(
                  left: 36,
                  right: 21,
                  bottom: dockBottom,
                  child: GuardianSupportDock(
                    onOpenEnrollment: () => openGuardian(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportCaseRing extends ConsumerWidget {
  const SupportCaseRing(this.record, {super.key, this.queue});
  final RescueRecord record;
  final List<RescueRecord>? queue;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = record.publicData['photos'] as List? ?? const [];
    final ratio = record.targetCents <= 0
        ? 0.0
        : (record.fundedCents / record.targetCents).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label:
          '${record.title}, ${pesos(record.fundedCents)} de ${pesos(record.targetCents)}',
      child: ReferenceFocusOutline(
        radius: 0,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: () async {
            if (supportStoryPhotos(record).isEmpty) {
              context.push('/rescue-cases/${record.id}');
              return;
            }
            final detail = await Navigator.of(context, rootNavigator: true)
                .push<String>(
                  MaterialPageRoute(
                    builder: (_) => SupportStories(records: queue ?? [record]),
                    fullscreenDialog: true,
                  ),
                );
            if (context.mounted && detail != null) {
              context.push('/rescue-cases/$detail');
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: math.max(84, MediaQuery.textScalerOf(context).scale(84)),
            child: Column(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _CaseProgress(ratio)),
                      Padding(
                        padding: const EdgeInsets.all(7),
                        child: ClipOval(
                          child: photos.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xffefe8dc),
                                  child: Icon(Icons.pets_outlined),
                                )
                              : RemotePhoto(
                                  source: rescuePhotoSource(
                                    ref.read(rescueRepositoryProvider),
                                    photos.first as String,
                                  ),
                                  width: 58,
                                  height: 58,
                                  loading: const ColoredBox(
                                    color: Color(0xffefe8dc),
                                    child: Icon(Icons.pets_outlined),
                                  ),
                                  unavailable: (retry) => Tooltip(
                                    message: 'Reintentar foto del caso',
                                    child: InkWell(
                                      onTap: retry,
                                      child: const ColoredBox(
                                        color: Color(0xffefe8dc),
                                        child: Icon(Icons.refresh),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _compactPesos(record.fundedCents),
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' / ${_compactPesos(record.targetCents)}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaseProgress extends CustomPainter {
  _CaseProgress(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 4) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xffe7e2da)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..color = DopmiTokens.sky
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CaseProgress old) => old.value != value;
}

class GuardianSupportCard extends StatefulWidget {
  const GuardianSupportCard({
    super.key,
    required this.height,
    this.onOpenEnrollment,
  });
  final double height;
  final VoidCallback? onOpenEnrollment;
  @override
  State<GuardianSupportCard> createState() => _GuardianSupportCardState();
}

class _GuardianSupportCardState extends State<GuardianSupportCard> {
  static const assets = [
    'guardian-carousel-hero.jpg',
    'guardian-luna.jpg',
    'guardian-milo.jpg',
  ];
  int page = 0;
  double drag = 0;
  bool dragging = false, exiting = false, pointerCanceled = false;
  int transition = 0;

  void advance([int direction = 1]) {
    if (exiting) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        page = (page + 1) % assets.length;
        drag = 0;
        dragging = false;
      });
      return;
    }
    setState(() {
      exiting = true;
      dragging = false;
      drag = direction * 420;
    });
    final token = ++transition;
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || transition != token) return;
      setState(() {
        page = (page + 1) % assets.length;
        drag = 0;
        exiting = false;
      });
    });
  }

  void release() {
    if (!dragging || exiting) return;
    if (pointerCanceled) {
      setState(() {
        drag = 0;
        dragging = false;
      });
      return;
    }
    if (drag.abs() > 110) {
      advance(drag < 0 ? -1 : 1);
    } else {
      setState(() {
        drag = 0;
        dragging = false;
      });
    }
  }

  Widget photo(int index) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: Image.asset(
      'assets/guardian/${assets[index]}',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced || dragging
        ? Duration.zero
        : Duration(milliseconds: exiting ? 280 : 250);
    return SizedBox(
      height: widget.height,
      child: DiscoverySwipeHint(
        resetKey: 'guardian-support',
        enabled: !dragging && !exiting,
        builder: (context, hint) => hint.wrapStage(
          Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: IgnorePointer(
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..rotateZ(7 * math.pi / 180)
                      ..translateByDouble(14, 22, 0, 1)
                      ..scaleByDouble(.92, .92, 1, 1),
                    child: Opacity(opacity: .82, child: photo((page + 2) % 3)),
                  ),
                ),
              ),
              hint.wrapNext(
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..rotateZ(4 * math.pi / 180)
                        ..translateByDouble(8, 10, 0, 1)
                        ..scaleByDouble(.985, .985, 1, 1),
                      child: photo((page + 1) % 3),
                    ),
                  ),
                ),
              ),
              hint.wrapCurrent(
                AnimatedContainer(
                  key: const ValueKey('guardian-support-carousel'),
                  duration: duration,
                  curve: const Cubic(.22, 1, .36, 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2915110d),
                        offset: Offset(0, 18),
                        blurRadius: 44,
                      ),
                    ],
                  ),
                  transformAlignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..translateByDouble(drag, 0, 0, 1)
                    ..rotateZ(
                      (exiting ? drag.sign * 18 : drag / 28) * math.pi / 180,
                    ),
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: exiting ? .35 : 1,
                    child: Listener(
                      onPointerCancel: (_) {
                        pointerCanceled = true;
                        if (!exiting) {
                          setState(() {
                            drag = 0;
                            dragging = false;
                          });
                        }
                      },
                      child: GestureDetector(
                        dragStartBehavior: DragStartBehavior.down,
                        onHorizontalDragStart: exiting
                            ? null
                            : (_) => setState(() {
                                dragging = true;
                                pointerCanceled = false;
                              }),
                        onHorizontalDragUpdate: exiting
                            ? null
                            : (event) => setState(() => drag += event.delta.dx),
                        onHorizontalDragEnd: exiting ? null : (_) => release(),
                        onHorizontalDragCancel: () => setState(() {
                          drag = 0;
                          dragging = false;
                        }),
                        child: ReferenceFocusOutline(
                          radius: 28,
                          child: Semantics(
                            key: const ValueKey('guardian-support-card-action'),
                            container: true,
                            button: true,
                            label: 'Sé un Guardián. Imagen ${page + 1} de 3',
                            onIncrease: () => advance(1),
                            onDecrease: () => advance(-1),
                            child: InkWell(
                              splashFactory: NoSplash.splashFactory,
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              onTap: exiting
                                  ? null
                                  : widget.onOpenEnrollment ??
                                        () =>
                                            context.push('/guardian?enroll=1'),
                              borderRadius: BorderRadius.circular(28),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    photo(page),
                                    if (page != 0) ...[
                                      const IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0x8015110d),
                                                Color(0x2415110d),
                                                Color(0x0f15110d),
                                                Color(0x3315110d),
                                              ],
                                              stops: [0, .36, .62, 1],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SingleChildScrollView(
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Sé un Guardián',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  height: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              for (final label in [
                                                'Rescatistas y casos verificados',
                                                'Sigue tu huella',
                                                'Cancela cuando quieras',
                                              ])
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.pets_outlined,
                                                        color: yellow,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          label,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 14,
                                                                height: 1.3,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton(
                  tooltip: 'Siguiente imagen Guardián',
                  onPressed: exiting ? null : () => advance(-1),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ink,
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Size _guardianDockTextSize(
  BuildContext context,
  String text,
  double fontSize,
  FontWeight weight, {
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.2,
        letterSpacing: 0,
      ),
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
  )..layout(maxWidth: maxWidth);
  final result = painter.size;
  painter.dispose();
  return result;
}

bool _guardianDockStacks(BuildContext context, double width) {
  return MediaQuery.textScalerOf(context).scale(14) > 20 ||
      _guardianDockTextSize(
                context,
                'Desde \$20 / mes',
                14,
                FontWeight.w600,
              ).width +
              _guardianDockTextSize(
                context,
                'Suscríbete ahora',
                17,
                FontWeight.w700,
              ).width +
              12 +
              52 >
          width;
}

double _guardianDockHeight(BuildContext context, double width) {
  final stacked = _guardianDockStacks(context, width);
  // Price/CTA lines are 16.8/20.4px before scaling. Reserve wrapped CTA lines
  // within the actual 24px inner padding plus the 2px outer border per side.
  final priceHeight = _guardianDockTextSize(
    context,
    'Desde \$20 / mes',
    14,
    FontWeight.w600,
    maxWidth: stacked ? math.max(0.0, width) : double.infinity,
  ).height;
  final buttonTextHeight = _guardianDockTextSize(
    context,
    'Suscríbete ahora',
    17,
    FontWeight.w700,
    maxWidth: stacked ? math.max(0.0, width - 52) : double.infinity,
  ).height;
  final buttonHeight = math.max(52.0, buttonTextHeight + 24);
  return stacked ? priceHeight + 8 + buttonHeight : buttonHeight;
}

class GuardianSupportDock extends StatelessWidget {
  const GuardianSupportDock({super.key, this.onOpenEnrollment});
  final VoidCallback? onOpenEnrollment;
  @override
  Widget build(BuildContext context) => ReferenceFocusOutline(
    radius: 0,
    child: Semantics(
      button: true,
      label: 'Suscríbete a Guardián, desde 20 pesos al mes',
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        onTap: onOpenEnrollment ?? () => context.push('/guardian?enroll=1'),
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, box) {
            const price = Text(
              'Desde \$20 / mes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: 0,
                color: DopmiTokens.orangeButton,
              ),
            );
            final button = Container(
              key: const ValueKey('guardian-support-cta'),
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DopmiTokens.orange,
                    DopmiTokens.sky,
                    DopmiTokens.saffronSoft,
                  ],
                  stops: [0, .52, 1],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color(0x57eb6425), blurRadius: 10),
                  BoxShadow(color: Color(0x47cbe8fa), blurRadius: 16),
                  BoxShadow(color: Color(0x38fef3d4), blurRadius: 22),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: DopmiTokens.orangeButton,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Suscríbete ahora',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0,
                    color: Colors.white,
                  ),
                ),
              ),
            );
            if (_guardianDockStacks(context, box.maxWidth)) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [price, const SizedBox(height: 8), button],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [price, const SizedBox(width: 12), button],
            );
          },
        ),
      ),
    ),
  );
}

String _compactPesos(int cents) => cents % 100 == 0
    ? '\$${cents ~/ 100}'
    : '\$${(cents / 100).toStringAsFixed(2)}';
