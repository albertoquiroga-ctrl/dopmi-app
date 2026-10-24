import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'css_linear_gradient.dart';

/// Shared b9f6d5f AdoptionFilterModal surface; callers own constraints/scroll
/// and set the route barrier to black at 16% opacity.
class WarmFilterDialog extends StatelessWidget {
  const WarmFilterDialog({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2446281d),
              offset: Offset(0, 16),
              blurRadius: 48,
            ),
            BoxShadow(
              color: Color(0x47ffffff),
              offset: Offset(0, 8),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x8cffffff),
                borderRadius: BorderRadius.circular(24),
              ),
              // CSS paints the gradient over the base color. Separate boxes
              // keep Flutter from multiplying their alpha in a single Paint.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const CssLinearGradient(
                    degrees: 165,
                    colors: [
                      Color(0x61ffffff),
                      Color(0xb8ffffff),
                      Color(0xd1ffffff),
                    ],
                    stops: [0, .52, 1],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xc7ffffff)),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
