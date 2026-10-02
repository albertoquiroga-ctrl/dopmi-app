import 'package:flutter/material.dart';

/// CSS focus-visible outline, without changing layout or pointer targets.
class ReferenceFocusOutline extends StatefulWidget {
  const ReferenceFocusOutline({
    super.key,
    required this.child,
    this.radius = 20,
    this.outlineInset = EdgeInsets.zero,
    this.outlineBorderRadius,
  });
  final Widget child;
  final double radius;
  final EdgeInsets outlineInset;
  final BorderRadius? outlineBorderRadius;
  @override
  State<ReferenceFocusOutline> createState() => _ReferenceFocusOutlineState();
}

class _ReferenceOutlineFocusNode extends FocusNode {}

class _ReferenceFocusOutlineState extends State<ReferenceFocusOutline> {
  final focusNode = _ReferenceOutlineFocusNode();
  bool focused = false;
  void focusChanged() {
    FocusNode? target = FocusManager.instance.primaryFocus;
    while (target != null && target is! _ReferenceOutlineFocusNode) {
      target = target.parent;
    }
    final ownsFocus = identical(target, focusNode);
    if (mounted && ownsFocus != focused) {
      setState(() => focused = ownsFocus);
    }
  }

  void highlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(highlightModeChanged);
    FocusManager.instance.addListener(focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(highlightModeChanged);
    FocusManager.instance.removeListener(focusChanged);
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focusNode,
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (_) => focusChanged(),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (focused &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional)
          Positioned(
            left: widget.outlineInset.left - 5,
            right: widget.outlineInset.right - 5,
            top: widget.outlineInset.top - 5,
            bottom: widget.outlineInset.bottom - 5,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  key: const ValueKey('reference-keyboard-outline'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0x4d7841f2),
                      width: 3,
                    ),
                    borderRadius:
                        widget.outlineBorderRadius ??
                        BorderRadius.circular(
                          widget.radius == 0 ? 0 : widget.radius + 5,
                        ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
