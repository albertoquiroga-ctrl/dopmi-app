import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../rescue/rescue_public_photo.dart';

class ImpactPhoto {
  const ImpactPhoto(this.caseId, this.name, this.path);
  final String caseId, name, path;
}

/// Presentation only: the caller supplies public photos of confirmed assignments.
/// Scrolling never changes membership, assignments, favorites or payment state.
class ImpactPhotoJourney extends StatefulWidget {
  const ImpactPhotoJourney({
    super.key,
    required this.photos,
    required this.hero,
    this.photoBuilder,
  });
  final List<ImpactPhoto> photos;
  final ImpactPhoto? hero;
  @visibleForTesting
  final Widget Function(ImpactPhoto photo, double height)? photoBuilder;

  @override
  State<ImpactPhotoJourney> createState() => _ImpactPhotoJourneyState();
}

class _ImpactPhotoJourneyState extends State<ImpactPhotoJourney> {
  final stage = GlobalKey();
  final rail = ScrollController();
  ScrollPosition? position;
  double? startOffset;
  double progress = 0, gap = 1;
  bool reduced = false;

  @override
  void initState() {
    super.initState();
    rail.addListener(update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    final next = Scrollable.maybeOf(context)?.position;
    if (next != position) {
      position?.removeListener(update);
      position = next;
      position?.addListener(update);
    }
    startOffset = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => measure());
  }

  @override
  void didUpdateWidget(ImpactPhotoJourney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hero?.path != widget.hero?.path ||
        oldWidget.hero?.caseId != widget.hero?.caseId) {
      startOffset = null;
      progress = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => measure());
    }
  }

  List<ImpactPhoto> get cases {
    final seen = <String>{};
    return widget.photos
        .where((photo) => photo.path.isNotEmpty && seen.add(photo.caseId))
        .toList();
  }

  bool get hasDestination =>
      widget.hero != null &&
      widget.hero!.path.isNotEmpty &&
      cases.any(
        (photo) =>
            photo.caseId == widget.hero!.caseId &&
            photo.path == widget.hero!.path,
      );

  void measure() {
    if (!mounted) return;
    final box = stage.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || position == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is! RenderBox) return;
    startOffset =
        position!.pixels +
        box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    update();
  }

  void update() {
    if (!mounted) return;
    final value =
        reduced ||
            !hasDestination ||
            startOffset == null ||
            (rail.hasClients && rail.offset.abs() > .5)
        ? 0.0
        : ((position!.pixels - startOffset!) / gap).clamp(0.0, 1.0);
    if ((value - progress).abs() > .00001) setState(() => progress = value);
  }

  @override
  void dispose() {
    position?.removeListener(update);
    rail.dispose();
    super.dispose();
  }

  Widget image(ImpactPhoto photo, double height) =>
      widget.photoBuilder?.call(photo, height) ??
      RescuePublicPhoto(photo.path, height: height, radius: 0, compact: true);

  Widget openPhoto(ImpactPhoto photo, Widget child) => Semantics(
    button: true,
    label: 'Ver caso ${photo.name}',
    child: InkWell(
      onTap: () => context.push('/rescue-cases/${photo.caseId}'),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final entries = cases;
    if (entries.isEmpty && widget.hero == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final scaler = MediaQuery.textScalerOf(context);
        final railLabelStyle = DefaultTextStyle.of(context).style
            .copyWith(fontSize: 13, fontWeight: FontWeight.w700, height: 1.3);
        var railLabelHeight = 0.0;
        for (final photo in entries) {
          final painter = TextPainter(
            text: TextSpan(text: photo.name, style: railLabelStyle),
            maxLines: 1,
            ellipsis: '…',
            textScaler: scaler,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: 84);
          railLabelHeight = math.max(railLabelHeight, painter.height);
          painter.dispose();
        }
        // Ring, label gap, measured single-line label, and explicit bottom padding.
        final railHeight = 76 + 8 + railLabelHeight + 8;
        final collageWidth = math.min(width - 28, 272.0);
        const collageHeight = 248.0;
        final heroSize = (width * .36).clamp(118.0, 148.0);
        final collageTop = railHeight + 22;
        final footerLabelStyle = DefaultTextStyle.of(context).style
            .copyWith(fontSize: 14, height: 1.3, color: muted);
        final labelPainter = TextPainter(
          text: TextSpan(text: 'Tu apoyo llegó a:', style: footerLabelStyle),
          textScaler: scaler,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: width - 28);
        final namePainter = TextPainter(
          text: TextSpan(
            text: widget.hero?.name ?? '',
            style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          textScaler: scaler,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: width - 28);
        final footerHeight = labelPainter.height + 6 + namePainter.height + 28;
        labelPainter.dispose();
        namePainter.dispose();
        final heroRect = Rect.fromLTWH(
          (width - heroSize) / 2,
          collageTop + collageHeight * .44 - heroSize / 2,
          heroSize,
          heroSize,
        );
        final targetIndex = entries.indexWhere(
          (photo) =>
              photo.caseId == widget.hero?.caseId &&
              photo.path == widget.hero?.path,
        );
        final ringRect = Rect.fromLTWH(targetIndex * 100.0 + 10, 6, 64, 64);
        gap = math.max(1, heroRect.center.dy - ringRect.center.dy);
        final shift = hasDestination && !reduced ? progress * gap : 0.0;
        final target = ringRect.shift(Offset(0, shift));
        final flight = Rect.lerp(heroRect.deflate(6), target, progress)!;
        final collagePhotos = widget.photos
            .where(
              (photo) =>
                  photo.path.isNotEmpty &&
                  (photo.caseId != widget.hero?.caseId ||
                      photo.path != widget.hero?.path),
            )
            .take(4)
            .toList();
        const scatter = [
          (0.04, .10, .36, -12.0),
          (.56, .04, .34, 10.0),
          (.58, .44, .38, 8.0),
          (0.0, .46, .32, -9.0),
        ];
        return SizedBox(
          key: stage,
          height: collageTop + collageHeight + footerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: collageTop,
                height: collageHeight + footerHeight - 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff0eeea),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              for (var i = 0; i < collagePhotos.length; i++)
                Positioned(
                  left:
                      (width - collageWidth) / 2 + collageWidth * scatter[i].$1,
                  top: collageTop + collageHeight * scatter[i].$2,
                  width: collageWidth * scatter[i].$3,
                  height: collageHeight * .42,
                  child: ExcludeSemantics(
                    child: Transform.rotate(
                      angle: scatter[i].$4 * math.pi / 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: image(collagePhotos[i], collageHeight * .42),
                      ),
                    ),
                  ),
                ),
              if (widget.hero != null && widget.hero!.path.isNotEmpty)
                Positioned.fromRect(
                  rect: heroRect,
                  child: openPhoto(
                    widget.hero!,
                    Container(
                      key: ValueKey('impact-hero-${widget.hero!.caseId}'),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3315110d),
                            offset: Offset(0, 20),
                            blurRadius: 48,
                          ),
                        ],
                      ),
                      child: Opacity(
                        key: const ValueKey('impact-hero-opacity'),
                        opacity: reduced || !hasDestination ? 1 : 1 - progress,
                        child: ClipOval(
                          child: image(widget.hero!, heroSize - 12),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 14,
                right: 14,
                top: collageTop + collageHeight + 8,
                child: Column(
                  children: [
                    Text('Tu apoyo llegó a:', style: footerLabelStyle),
                    const SizedBox(height: 6),
                    Text(
                      widget.hero?.name ?? '',
                      key: const ValueKey('impact-collage-name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: shift,
                height: railHeight,
                child: Container(
                  color: Colors.white,
                  child: ListView.separated(
                    controller: rail,
                    scrollDirection: Axis.horizontal,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final photo = entries[index];
                      final opacity =
                          index == targetIndex &&
                              hasDestination &&
                              !reduced &&
                              progress > .02
                          ? ((progress - .82) / .18).clamp(0.0, 1.0)
                          : 1.0;
                      return SizedBox(
                        width: 84,
                        child: openPhoto(
                          photo,
                          Column(
                            children: [
                              Container(
                                key: ValueKey('impact-ring-${photo.caseId}'),
                                width: 76,
                                height: 76,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: yellow, width: 3),
                                ),
                                child: Opacity(
                                  key: ValueKey(
                                    'impact-ring-opacity-${photo.caseId}',
                                  ),
                                  opacity: opacity,
                                  child: ClipOval(child: image(photo, 64)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                photo.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: railLabelStyle,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (!reduced &&
                  hasDestination &&
                  progress > .001 &&
                  progress < .999)
                Positioned.fromRect(
                  key: const ValueKey('impact-photo-flight'),
                  rect: flight,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: ClipOval(
                        child: image(widget.hero!, flight.height),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
