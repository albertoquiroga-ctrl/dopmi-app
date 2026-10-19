import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_repository.dart';

/// Only asset IDs cross screen boundaries. Every lease is requested from the
/// authorization endpoint and is disposed on identity changes or withdrawal.
class ModeratedVideo extends StatefulWidget {
  const ModeratedVideo({
    super.key,
    required this.repository,
    required this.assetId,
    this.autoplay = true,
    this.paused = false,
    this.onComplete,
    this.onProgress,
    this.onPlaybackReady,
    this.semanticLabel = 'Video del caso',
  });
  final VideoRepository repository;
  final String assetId, semanticLabel;
  final bool autoplay, paused;
  final VoidCallback? onComplete, onPlaybackReady;
  final ValueChanged<double>? onProgress;
  @override
  State<ModeratedVideo> createState() => _ModeratedVideoState();
}

class _ModeratedVideoState extends State<ModeratedVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  VideoLease? lease;
  Timer? expiry, scopeWatch;
  StreamSubscription<void>? identitySubscription;
  void watchIdentity() {
    unawaited(identitySubscription?.cancel());
    identitySubscription = widget.repository.identityChanges?.listen((_) {
      if (mounted && scope != widget.repository.identity()) {
        invalidateIdentity();
      }
    });
  }

  String? scope;
  String? error;
  int generation = 0;
  bool foreground = true,
      visible = true,
      muted = true,
      holding = false,
      completed = false;
  bool wantsPlaying = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scope = widget.repository.identity();
    watchIdentity();
    wantsPlaying = widget.autoplay;
    scopeWatch = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && scope != widget.repository.identity()) {
        invalidateIdentity();
      }
    });
    unawaited(load());
  }

  bool current(int run) =>
      mounted && run == generation && scope == widget.repository.identity();
  void evictPoster() {
    final poster = lease?.poster;
    if (poster != null) {
      unawaited(NetworkImage(poster.toString()).evict().then((_) {}));
    }
  }

  void invalidateIdentity() {
    evictPoster();
    generation++;
    expiry?.cancel();
    final previous = controller;
    controller = null;
    lease = null;
    unawaited(previous?.dispose());
    if (mounted) {
      setState(() => error = 'Tu sesión cambió. Vuelve a abrir el video.');
    }
  }

  Future<void> load({bool preserve = true}) async {
    final run = ++generation;
    expiry?.cancel();
    final previous = controller;
    final position = preserve
        ? (previous?.value.position ?? Duration.zero)
        : Duration.zero;
    evictPoster();
    controller = null;
    lease = null;
    if (mounted) setState(() => error = null);
    await previous?.dispose();
    VideoPlayerController? created;
    try {
      final granted = await widget.repository.playback(widget.assetId);
      if (!current(run)) return;
      lease = granted;
      setState(() {});
      // HLS can contain protected segments; do not persist controllers or leases.
      created = VideoPlayerController.networkUrl(
        granted.hls,
        formatHint: VideoFormat.hls,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await created.initialize();
      if (!current(run)) {
        await created.dispose();
        return;
      }
      if (created.value.duration > videoMaxDuration ||
          created.value.duration <= Duration.zero) {
        throw const VideoFailure('invalid_duration');
      }
      await created.setVolume(muted ? 0 : 1);
      if (position < created.value.duration) await created.seekTo(position);
      if (!current(run)) {
        await created.dispose();
        return;
      }
      controller = created;
      lease = granted;
      controller!.addListener(changed);
      expiry = Timer(
        granted.expiresAt.difference(DateTime.now().toUtc()) -
            const Duration(seconds: 10),
        () {
          if (mounted && foreground && visible) {
            unawaited(load());
          } else {
            unawaited(controller?.pause());
          }
        },
      );
      await syncPlayback();
      if (current(run)) {
        setState(() {});
        widget.onPlaybackReady?.call();
      }
    } catch (_) {
      if (created != null && created != controller) await created.dispose();
      if (current(run)) {
        final failed = controller;
        evictPoster();
        controller = null;
        lease = null;
        unawaited(failed?.dispose());
        setState(
          () => error = 'No pudimos reproducir este video. Comprueba tu conexión e inténtalo de nuevo.',
        );
      }
    }
  }

  Future<void> syncPlayback() async {
    final player = controller;
    if (player == null) return;
    final authorized =
        lease?.expiresAt.isAfter(DateTime.now().toUtc()) ?? false;
    if (foreground &&
        visible &&
        !widget.paused &&
        !holding &&
        wantsPlaying &&
        authorized) {
      await player.play();
    } else {
      await player.pause();
    }
  }

  void changed() {
    final player = controller;
    if (player == null || !mounted) return;
    if (player.value.hasError) {
      expiry?.cancel();
      generation++;
      evictPoster();
      controller = null;
      lease = null;
      unawaited(player.dispose());
      setState(
        () => error = 'La reproducción se interrumpió. Intenta de nuevo.',
      );
      return;
    }
    final total = player.value.duration.inMilliseconds;
    if (total > 0) {
      final progress = (player.value.position.inMilliseconds / total)
          .clamp(0.0, 1.0)
          .toDouble();
      widget.onProgress?.call(progress);
      if (!completed && progress >= 0.995) {
        completed = true;
        widget.onComplete?.call();
      }
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant ModeratedVideo old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository || old.assetId != widget.assetId) {
      scope = widget.repository.identity();
      watchIdentity();
      muted = true;
      holding = false;
      completed = false;
      wantsPlaying = widget.autoplay;
      unawaited(load(preserve: false));
    } else if (old.paused != widget.paused) {
      unawaited(syncPlayback());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TickerMode.valuesOf(context).enabled;
    if (next != visible) {
      visible = next;
      if (visible && foreground) {
        unawaited(load());
      } else {
        unawaited(controller?.pause());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && visible) {
      unawaited(load());
    } else {
      unawaited(controller?.pause());
    }
  }

  @override
  void dispose() {
    generation++;
    evictPoster();
    WidgetsBinding.instance.removeObserver(this);
    expiry?.cancel();
    scopeWatch?.cancel();
    unawaited(identitySubscription?.cancel());
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error!),
          TextButton(
            onPressed: scope == widget.repository.identity()
                ? () => load()
                : null,
            child: const Text('Reintentar video'),
          ),
        ],
      );
    }
    final player = controller;
    return Semantics(
      label: widget.semanticLabel,
      child: GestureDetector(
        onLongPressStart: (_) {
          holding = true;
          unawaited(syncPlayback());
        },
        onLongPressEnd: (_) {
          holding = false;
          unawaited(syncPlayback());
        },
        onLongPressCancel: () {
          holding = false;
          unawaited(syncPlayback());
        },
        child: AspectRatio(
          aspectRatio: player?.value.aspectRatio ?? 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (lease != null &&
                  (player == null || !player.value.isInitialized))
                Image.network(
                  lease!.poster.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => const SizedBox.shrink(),
                ),
              if (player != null && player.value.isInitialized)
                VideoPlayer(player)
              else
                const Center(child: CircularProgressIndicator()),
              if (player != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: wantsPlaying
                              ? 'Pausar video'
                              : 'Reproducir video',
                          onPressed: () {
                            setState(() => wantsPlaying = !wantsPlaying);
                            unawaited(syncPlayback());
                          },
                          icon: Icon(
                            wantsPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: muted ? 'Activar sonido' : 'Silenciar video',
                          onPressed: () async {
                            setState(() => muted = !muted);
                            await player.setVolume(muted ? 0 : 1);
                          },
                          icon: Icon(
                            muted ? Icons.volume_off : Icons.volume_up,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
