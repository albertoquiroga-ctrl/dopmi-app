import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// CSS angles: zero points up and positive angles turn clockwise.
/// Endpoints follow perpendicular lines through the rectangle's corners:
/// https://www.w3.org/TR/css-images-3/#linear-gradients
class CssLinearGradient extends Gradient {
  const CssLinearGradient({
    required this.degrees,
    required super.colors,
    super.stops,
  });
  final double degrees;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final radians = degrees * math.pi / 180;
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final length =
        rect.width * direction.dx.abs() + rect.height * direction.dy.abs();
    final halfLine = direction * (length / 2);
    return ui.Gradient.linear(
      rect.center - halfLine,
      rect.center + halfLine,
      colors,
      stops ??
          List.generate(colors.length, (index) => index / (colors.length - 1)),
    );
  }

  @override
  CssLinearGradient scale(double factor) => CssLinearGradient(
    degrees: degrees,
    colors: colors.map((color) => Color.lerp(null, color, factor)!).toList(),
    stops: stops,
  );

  @override
  CssLinearGradient withOpacity(double opacity) => CssLinearGradient(
    degrees: degrees,
    colors: colors.map((color) => color.withValues(alpha: opacity)).toList(),
    stops: stops,
  );

  @override
  CssLinearGradient fromColor(Color color) => CssLinearGradient(
    degrees: degrees,
    colors: List.filled(colors.length, color),
    stops: stops,
  );

  static CssLinearGradient interpolate(
    CssLinearGradient a,
    CssLinearGradient b,
    double t,
  ) {
    final values = LinearGradient.lerp(
      LinearGradient(colors: a.colors, stops: a.stops),
      LinearGradient(colors: b.colors, stops: b.stops),
      t,
    )!;
    return CssLinearGradient(
      degrees: a.degrees + (b.degrees - a.degrees) * t,
      colors: values.colors,
      stops: values.stops,
    );
  }

  @override
  Gradient? lerpFrom(Gradient? a, double t) =>
      a is CssLinearGradient ? interpolate(a, this, t) : super.lerpFrom(a, t);
  @override
  Gradient? lerpTo(Gradient? b, double t) =>
      b is CssLinearGradient ? interpolate(this, b, t) : super.lerpTo(b, t);

  @override
  bool operator ==(Object other) =>
      other is CssLinearGradient &&
      degrees == other.degrees &&
      listEquals(colors, other.colors) &&
      listEquals(stops, other.stops);
  @override
  int get hashCode => Object.hash(
    degrees,
    Object.hashAll(colors),
    stops == null ? null : Object.hashAll(stops!),
  );
}
