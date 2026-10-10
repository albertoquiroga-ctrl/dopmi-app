import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The reference payment-method action uses a one-pixel dashed outline.
class PaymentMethodBorder extends RoundedRectangleBorder {
  const PaymentMethodBorder({
    super.side = const BorderSide(color: Color(0xffd5cfc6)),
    super.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  PaymentMethodBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) => PaymentMethodBorder(
    side: side ?? this.side,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  ShapeBorder scale(double t) =>
      PaymentMethodBorder(side: side.scale(t), borderRadius: borderRadius * t);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final path = Path()
      ..addRRect(
        borderRadius
            .resolve(textDirection)
            .toRRect(rect)
            .deflate(side.width / 2),
      );
    final paint = side.toPaint();
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(
          metric.extractPath(offset, math.min(offset + 4, metric.length)),
          paint,
        );
      }
    }
  }
}
