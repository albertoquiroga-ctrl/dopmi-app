import 'package:flutter/material.dart';

import 'ui.dart';

/// Matches the shared prototype dialog close glyph while keeping a 48px target.
class DopmiDialogClose extends StatelessWidget {
  const DopmiDialogClose({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Positioned(
    top: 0,
    right: 16,
    child: Tooltip(
      message: 'Cerrar',
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          fixedSize: const Size(48, 48),
          padding: const EdgeInsets.only(right: 6),
          alignment: Alignment.centerRight,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          animationDuration: Duration.zero,
          foregroundColor: muted,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        onPressed: onPressed,
        child: const ExcludeSemantics(child: Text('×')),
      ),
    ),
  );
}
