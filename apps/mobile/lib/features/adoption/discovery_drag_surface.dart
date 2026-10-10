import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The reference treats horizontal movement of eight pixels as a drag.
class DiscoveryDragSurface extends StatelessWidget {
  const DiscoveryDragSurface({
    super.key,
    required this.child,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.dragStartBehavior = DragStartBehavior.down,
  });

  final Widget child;
  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;
  final GestureDragCancelCallback? onHorizontalDragCancel;
  final DragStartBehavior dragStartBehavior;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      if (onHorizontalDragStart != null)
        _DiscoveryHorizontalDrag:
            GestureRecognizerFactoryWithHandlers<_DiscoveryHorizontalDrag>(
              _DiscoveryHorizontalDrag.new,
              (recognizer) => recognizer
                ..dragStartBehavior = dragStartBehavior
                ..onStart = onHorizontalDragStart
                ..onUpdate = onHorizontalDragUpdate
                ..onEnd = onHorizontalDragEnd
                ..onCancel = onHorizontalDragCancel,
            ),
    },
    child: child,
  );
}

class _DiscoveryHorizontalDrag extends HorizontalDragGestureRecognizer {
  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => globalDistanceMoved.abs() >= 8;
}
