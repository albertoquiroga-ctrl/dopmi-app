import 'package:flutter/material.dart';

/// Paints the CSS focus outline around the input, excluding validation text.
class ReferenceInputBorder extends OutlineInputBorder {
  const ReferenceInputBorder({
    super.borderSide,
    super.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.outlineStrength = 1,
  });

  final double outlineStrength;

  ReferenceInputBorder interpolate(
    OutlineInputBorder a,
    OutlineInputBorder b,
    double t,
  ) => ReferenceInputBorder(
    borderSide: BorderSide.lerp(a.borderSide, b.borderSide, t),
    borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t)!,
    outlineStrength:
        (a is ReferenceInputBorder ? a.outlineStrength : 0) * (1 - t) +
        (b is ReferenceInputBorder ? b.outlineStrength : 0) * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is OutlineInputBorder ? interpolate(a, this, t) : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is OutlineInputBorder ? interpolate(this, b, t) : super.lerpTo(b, t);

  @override
  ReferenceInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => ReferenceInputBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    outlineStrength: outlineStrength,
  );

  @override
  ReferenceInputBorder scale(double t) => ReferenceInputBorder(
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t,
    outlineStrength: outlineStrength * t,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
    if (outlineStrength <= 0) return;
    canvas.drawRRect(
      borderRadius.toRRect(rect).inflate(3.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xff7841f2)
            .withValues(alpha: .3 * outlineStrength),
    );
  }
}
