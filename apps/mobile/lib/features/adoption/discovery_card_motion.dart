import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Matches the reference's translateX/rotate interpolation in CSS units.
class DiscoveryCardMotion extends ImplicitlyAnimatedWidget {
  const DiscoveryCardMotion({
    super.key,
    required this.translation,
    required this.angleDegrees,
    required super.duration,
    super.onEnd,
    required this.child,
  }) : super(curve: const Cubic(.22, 1, .36, 1));

  final double translation;
  final double angleDegrees;
  final Widget child;

  @override
  AnimatedWidgetBaseState<DiscoveryCardMotion> createState() =>
      _DiscoveryCardMotionState();
}

class _DiscoveryCardMotionState
    extends AnimatedWidgetBaseState<DiscoveryCardMotion> {
  Tween<double>? _translation;
  Tween<double>? _angle;

  @override
  void didUpdateWidget(covariant DiscoveryCardMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration == Duration.zero) controller.value = 1;
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _translation = visitor(
      _translation,
      widget.translation,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
    _angle = visitor(
      _angle,
      widget.angleDegrees,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..translateByDouble(
        widget.duration == Duration.zero
            ? widget.translation
            : _translation!.evaluate(animation),
        0,
        0,
        1,
      )
      ..rotateZ(
        (widget.duration == Duration.zero
                ? widget.angleDegrees
                : _angle!.evaluate(animation)) *
            math.pi /
            180,
      ),
    child: widget.child,
  );
}

/// The single f693 teaching sequence shared by the discovery and Guardian decks.
/// Pointer observation never claims the gesture arena or performs a swipe.
class DiscoverySwipeHint extends StatefulWidget {
  const DiscoverySwipeHint({
    super.key,
    required this.resetKey,
    this.enabled = true,
    required this.builder,
  });
  final Object resetKey;
  final bool enabled;
  final Widget Function(BuildContext, DiscoveryHintFrame) builder;

  @override
  State<DiscoverySwipeHint> createState() => _DiscoverySwipeHintState();
}

class _DiscoverySwipeHintState extends State<DiscoverySwipeHint>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool cancelled = false;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      controller.value = 1;
      started = true;
    } else if (!started && widget.enabled) {
      started = true;
      controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DiscoverySwipeHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) {
      cancelled = false;
      started = true;
      if (widget.enabled && !MediaQuery.disableAnimationsOf(context)) {
        controller.forward(from: 0);
      } else {
        controller.stop();
        controller.value = 1;
      }
    } else if (!widget.enabled) {
      cancelled = true;
      controller.stop();
    }
  }

  void cancel() {
    if (cancelled || !mounted) return;
    controller.stop();
    setState(() => cancelled = true);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => cancel(),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => widget.builder(
        context,
        DiscoveryHintFrame._(
          controller.value * 3200,
          widget.enabled &&
              !cancelled &&
              controller.value < 1 &&
              !MediaQuery.disableAnimationsOf(context),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class DiscoveryHintFrame {
  const DiscoveryHintFrame._(this.milliseconds, this.active);
  final double milliseconds;
  final bool active;
  static const _ease = Cubic(.22, 1, .36, 1);

  double get _entry => !active
      ? 1
      : _ease.transform((milliseconds / 550).clamp(0.0, 1.0).toDouble());
  double get _swipe => ((milliseconds - 450) / 1850).clamp(0.0, 1.0).toDouble();
  bool get _nextAnimating =>
      active && milliseconds >= 450 && milliseconds < 2300;

  double _keyframe(List<double> positions, List<double> values) {
    final progress = _swipe;
    for (var index = 1; index < positions.length; index++) {
      if (progress <= positions[index]) {
        final local =
            (progress - positions[index - 1]) /
            (positions[index] - positions[index - 1]);
        final eased = _ease.transform(local.clamp(0.0, 1.0).toDouble());
        return values[index - 1] + (values[index] - values[index - 1]) * eased;
      }
    }
    return values.last;
  }

  Widget wrapStage(Widget child) => Opacity(
    opacity: _entry,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(0, 18 * (1 - _entry), 0, 1)
        ..scaleByDouble(.96 + .04 * _entry, .96 + .04 * _entry, 1, 1),
      child: child,
    ),
  );

  Widget wrapCurrent(Widget child) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..translateByDouble(
        active
            ? _keyframe(const [0, .22, .48, .72, 1], const [0, -26, 26, -14, 0])
            : 0,
        0,
        0,
        1,
      )
      ..rotateZ(
        (active
                ? _keyframe(
                    const [0, .22, .48, .72, 1],
                    const [0, -5, 5, -2.5, 0],
                  )
                : 0) *
            math.pi /
            180,
      ),
    child: child,
  );

  Widget wrapNext(Widget child) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..rotateZ(
        (_nextAnimating ? _keyframe(const [0, .48, 1], const [4, 2, 4]) : 0) *
            math.pi /
            180,
      )
      ..translateByDouble(
        _nextAnimating ? _keyframe(const [0, .48, 1], const [8, 4, 8]) : 0,
        _nextAnimating ? _keyframe(const [0, .48, 1], const [10, 8, 10]) : 0,
        0,
        1,
      )
      ..scaleByDouble(
        _nextAnimating
            ? _keyframe(const [0, .48, 1], const [.985, .99, .985])
            : 1,
        _nextAnimating
            ? _keyframe(const [0, .48, 1], const [.985, .99, .985])
            : 1,
        1,
        1,
      ),
    child: child,
  );
}
