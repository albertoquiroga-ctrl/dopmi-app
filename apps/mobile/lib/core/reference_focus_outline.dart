import 'package:flutter/material.dart';

/// CSS focus-visible outline, without changing layout or pointer targets.
class ReferenceFocusOutline extends StatefulWidget {
  const ReferenceFocusOutline({
    super.key,
    required this.child,
    this.radius = 20,
  });
  final Widget child;
  final double radius;
  @override
  State<ReferenceFocusOutline> createState() => _ReferenceFocusOutlineState();
}

class _ReferenceFocusOutlineState extends State<ReferenceFocusOutline> {
  bool focused = false;
  void highlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(highlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(highlightModeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (value) => setState(() => focused = value),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (focused &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional)
          Positioned(
            left: -5,
            right: -5,
            top: -5,
            bottom: -5,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  key: const ValueKey('reference-keyboard-outline'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0x4d7841f2),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(widget.radius + 5),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
