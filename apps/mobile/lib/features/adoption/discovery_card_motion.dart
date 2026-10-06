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
