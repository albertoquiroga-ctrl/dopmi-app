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
    this.failureBuilder,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.preview = false,
  });
  final PhotoRef source;
  final Widget loading;
  final Widget Function(VoidCallback retry) unavailable;
  final Widget Function(Object error, VoidCallback retry)? failureBuilder;
  final double? height, width;
  final BoxFit fit;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  /// Observes the bounded prefetch without loading, retrying, or promoting it.
  final bool preview;
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
    runtime.frameUpdates.addListener(previewFrameChanged);
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
      if (widget.preview) {
        readPreviewFrame();
      } else {
        load();
      }
    } else if (widget.preview) {
      readPreviewFrame();
    }
  }

  @override
  void didUpdateWidget(RemotePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged = oldWidget.source.identity != widget.source.identity;
    if (sourceChanged) {
      runtime.release(this);
      generation++;
      frame = null;
      failure = null;
      namespace = null;
      if (active) {
        if (widget.preview) {
          readPreviewFrame();
        } else {
          load();
        }
      }
    } else if (oldWidget.preview != widget.preview) {
      runtime.release(this);
      generation++;
      failure = null;
      if (!active) return;
      if (widget.preview) {
        readPreviewFrame();
      } else {
        final prepared = runtime.readyFrame(widget.source, width: decodeWidth);
        namespace = runtime.key(widget.source);
        if (prepared != null) {
          frame = prepared;
        } else {
          load();
        }
      }
    }
  }

  void readPreviewFrame() {
    namespace = runtime.key(widget.source);
    frame = runtime.readyFrame(widget.source, width: decodeWidth);
    failure = null;
  }

  void previewFrameChanged() {
    if (!mounted || !active || !widget.preview) return;
    final next = runtime.readyFrame(widget.source, width: decodeWidth);
    if (namespace == runtime.key(widget.source) &&
        frame?.provider == next?.provider &&
        frame?.validUntil == next?.validUntil &&
        frame?.origin == next?.origin &&
        failure == null) {
      return;
    }
    setState(readPreviewFrame);
  }

  void scopeChanged() {
    if (!mounted) return;
    final restored = !wasReady && runtime.ready;
    wasReady = runtime.ready;
    if (widget.preview && active) {
      setState(readPreviewFrame);
      return;
    }
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
    if (widget.preview) {
      readPreviewFrame();
      return;
    }
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

  void retry() {
    if (widget.preview) return;
    setState(() => load(retry: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        TickerMode.valuesOf(context).enabled &&
        !widget.preview &&
        (failure != null || frame != null && runtime.expired(frame!))) {
      retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preview) readPreviewFrame();
    if (failure != null) {
      return widget.failureBuilder?.call(failure!, retry) ??
          widget.unavailable(retry);
    }
    if (frame == null) return widget.loading;
    final current = generation;
    return Image(
      image: frame!.provider,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.excludeFromSemantics || widget.preview,
      errorBuilder: (_, error, _) {
        if (widget.preview) return widget.loading;
        if (generation == current) failure = error;
        return widget.failureBuilder?.call(error, retry) ??
            widget.unavailable(retry);
      },
    );
  }

  @override
  void dispose() {
    generation++;
    runtime.release(this);
    WidgetsBinding.instance.removeObserver(this);
    runtime.removeListener(scopeChanged);
    runtime.frameUpdates.removeListener(previewFrameChanged);
    super.dispose();
  }
}
