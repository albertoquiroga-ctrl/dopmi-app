import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Enlarged headings keep whole words while body copy retains system scaling.
TextStyle wordSafeHeadingStyle(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
) {
  final scaler = MediaQuery.textScalerOf(context);
  final fontSize = style.fontSize!;
  if (!maxWidth.isFinite ||
      maxWidth <= 0 ||
      scaler.scale(fontSize) <= fontSize) {
    return style;
  }
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textScaler: scaler,
      textDirection: Directionality.of(context),
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  if (widest <= maxWidth) return style;
  final target = scaler.scale(fontSize) * maxWidth / widest * .99;
  var low = 0.0;
  var high = fontSize;
  for (var i = 0; i < 16; i++) {
    final middle = (low + high) / 2;
    if (scaler.scale(middle) <= target) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return style.copyWith(fontSize: low);
}
