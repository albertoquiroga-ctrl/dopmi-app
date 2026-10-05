import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_runtime.dart';
import 'photo_transport.dart';

/// Shared load/recovery lifecycle; the caller owns the existing composition.
class RemotePhoto extends ConsumerStatefulWidget {
  const RemotePhoto({
    super.key,
    required this.source,
    required this.loading,
    required this.unavailable,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });
  final PhotoRef source;
  final Widget loading;
  final Widget Function(VoidCallback retry) unavailable;
  final double? height, width;
  final BoxFit fit;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  @override
  ConsumerState<RemotePhoto> createState() => _RemotePhotoState();
}

class _RemotePhotoState extends ConsumerState<RemotePhoto>
    with WidgetsBindingObserver {
  late final PhotoRuntime runtime = ref.read(photoRuntimeProvider);
  PhotoFrame? frame;
  Object? failure;
  int generation = 0, decodeWidth = 0;
  String? namespace;
  bool active = false;
  bool wasReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    runtime.addListener(scopeChanged);
    wasReady = runtime.ready;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasActive = active;
    active = TickerMode.valuesOf(context).enabled;
    if (!active) {
      if (wasActive && frame == null) generation++;
      runtime.release(this);
      return;
    }
    final requestedWidth = widget.width;
    final logicalWidth = requestedWidth != null && requestedWidth.isFinite
        ? requestedWidth
        : MediaQuery.sizeOf(context).width;
    final physicalWidth = logicalWidth * MediaQuery.devicePixelRatioOf(context);
    final target = ((physicalWidth / 128).ceil() * 128).clamp(128, 1600);
    if (decodeWidth != target ||
        namespace == null ||
        !wasActive && (frame == null || runtime.expired(frame!))) {
      decodeWidth = target;
      load();
    }
  }

  @override
  void didUpdateWidget(RemotePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.identity != widget.source.identity) {
      runtime.release(this);
      generation++;
      frame = null;
      namespace = null;
      if (active) load();
    }
  }

  void scopeChanged() {
    if (!mounted) return;
    final restored = !wasReady && runtime.ready;
    wasReady = runtime.ready;
    if (!active) {
      if (namespace != runtime.key(widget.source)) {
        setState(() {
          generation++;
          frame = null;
          namespace = null;
        });
      }
      return;
    }
    if (namespace != runtime.key(widget.source) ||
        failure is PhotoCancelled ||
        restored && frame == null) {
      setState(load);
    }
  }

  void load({bool retry = false}) {
    final current = ++generation;
    namespace = runtime.key(widget.source);
    frame = null;
    failure = null;
    final request = retry
        ? runtime.retry(widget.source, width: decodeWidth, consumer: this)
        : runtime.load(widget.source, width: decodeWidth, consumer: this);
    unawaited(
      request.then<void>(
        (value) {
          if (!mounted || generation != current) return;
          setState(() => frame = value);
        },
        onError: (Object error) {
          if (!mounted || generation != current) return;
          setState(() => failure = error);
        },
      ),
    );
  }

  void retry() => setState(() => load(retry: true));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        TickerMode.valuesOf(context).enabled &&
        (failure != null || frame != null && runtime.expired(frame!))) {
      retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (failure != null) return widget.unavailable(retry);
    if (frame == null) return widget.loading;
    final current = generation;
    return Image(
      image: frame!.provider,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.excludeFromSemantics,
      errorBuilder: (_, error, _) {
        if (generation == current) failure = error;
        return widget.unavailable(retry);
      },
    );
  }

  @override
  void dispose() {
    generation++;
    runtime.release(this);
    WidgetsBinding.instance.removeObserver(this);
    runtime.removeListener(scopeChanged);
    super.dispose();
  }
}
