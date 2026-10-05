import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_runtime.dart';

/// A bounded, replaceable window. Rebuilds with the same window do no work.
class PhotoPrefetch extends ConsumerStatefulWidget {
  const PhotoPrefetch({
    super.key,
    required this.sources,
    required this.child,
    this.width,
  });
  final List<PhotoRef> sources;
  final Widget child;
  final double? width;
  @override
  ConsumerState<PhotoPrefetch> createState() => _PhotoPrefetchState();
}

class _PhotoPrefetchState extends ConsumerState<PhotoPrefetch> {
  late final runtime = ref.read(photoRuntimeProvider);
  String? window;
  int revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    update();
  }

  @override
  void didUpdateWidget(PhotoPrefetch oldWidget) {
    super.didUpdateWidget(oldWidget);
    update();
  }

  void update() {
    final active = TickerMode.valuesOf(context).enabled;
    final logical = widget.width ?? MediaQuery.sizeOf(context).width;
    final width =
        ((logical * MediaQuery.devicePixelRatioOf(context) / 128).ceil() * 128)
            .clamp(128, 1600);
    final next = active
        ? '${widget.sources.map(runtime.key).join('|')}:$width'
        : 'inactive';
    if (next == window) return;
    window = next;
    runtime.cancelPrefetch(this);
    final current = ++revision;
    if (!active || widget.sources.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && current == revision) {
        runtime.prefetch(this, widget.sources, width: width);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    revision++;
    runtime.cancelPrefetch(this);
    super.dispose();
  }
}
