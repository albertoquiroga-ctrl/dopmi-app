import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'video_repository.dart';

typedef LocalVideoControllerFactory = VideoPlayerController Function(
  XFile file,
);

/// Reviews an app-local selection only. This widget has no server repository or
/// playback lease; accepting the selection is the parent's explicit upload seam.
class LocalVideoPreview extends StatefulWidget {
  const LocalVideoPreview({
    super.key,
    required this.file,
    required this.onUpload,
    required this.onDiscard,
    this.controllerFactory,
  });

  final XFile file;
  final Future<void> Function() onUpload;
  final VoidCallback onDiscard;
  final LocalVideoControllerFactory? controllerFactory;

  @override
  State<LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<LocalVideoPreview>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  String? error;
  int generation = 0;
  int playbackIntent = 0;
  bool foreground = true, visible = true, muted = true, submitting = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
  }

  bool current(int run) => mounted && run == generation;

  Future<void> release(VideoPlayerController? player) async {
    if (player == null) return;
    try {
      await player.pause();
    } catch (_) {
      // A failed decoder still needs disposal; never turn it into readiness.
    }
    try {
      await player.dispose();
    } catch (_) {
      // Discard remains local even if a platform decoder cannot be disposed.
    }
  }

  Future<void> load() async {
    final run = ++generation;
    final previous = controller;
    controller = null;
    error = null;
    muted = true;
    await release(previous);
    if (!current(run)) return;
    VideoPlayerController? created;
    try {
      created =
          widget.controllerFactory?.call(widget.file) ??
          VideoPlayerController.file(
            File(widget.file.path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          );
      await created.initialize();
      if (!current(run)) {
        await release(created);
        return;
      }
      final value = created.value;
      if (value.hasError ||
          !value.isInitialized ||
          value.duration <= Duration.zero ||
          value.duration > videoMaxDuration ||
          value.size.width <= 0 ||
          value.size.height <= 0) {
        throw const VideoFailure('invalid_local_video');
      }
      await created.setVolume(0);
      await created.pause();
      if (!current(run)) {
        await release(created);
        return;
      }
      controller = created;
      created.addListener(changed);
      setState(() {});
    } catch (_) {
      await release(created);
      if (current(run)) {
        setState(() {
          controller = null;
          error = 'No pudimos revisar este video. Elige un archivo reproducible de hasta 60 segundos.';
        });
      }
    }
  }

  void changed() {
    if (!mounted) return;
    final player = controller;
    if (player == null) return;
    if (player.value.hasError) {
      player.removeListener(changed);
      controller = null;
      generation++;
      unawaited(release(player));
      setState(() {
        submitting = false;
        error = 'La reproducción se interrumpió. Descarta la selección y elige otro video.';
      });
      return;
    }
    setState(() {});
  }

  Future<void> accept() async {
    final player = controller;
    if (submitting ||
        !foreground ||
        !visible ||
        player == null ||
        error != null) {
      return;
    }
    final run = generation;
    playbackIntent++;
    setState(() => submitting = true);
    try {
      await player.pause();
      if (!current(run) || !foreground || !visible || player.value.hasError) {
        return;
      }
      await widget.onUpload();
    } catch (_) {
      if (current(run)) {
        setState(() {
          error = 'No pudimos revisar este video. Descarta la selección y elige otro.';
        });
      }
    } finally {
      if (current(run)) setState(() => submitting = false);
    }
  }

  bool canPlay(VideoPlayerController player, int run, int intent) =>
      current(run) &&
      controller == player &&
      intent == playbackIntent &&
      foreground &&
      visible &&
      !submitting &&
      !player.value.hasError;

  void failPlayback(VideoPlayerController player, int run) {
    if (!current(run) || controller != player) return;
    player.removeListener(changed);
    controller = null;
    generation++;
    unawaited(release(player));
    setState(() {
      submitting = false;
      error = 'No pudimos reproducir este video. Descarta la selección y elige otro.';
    });
  }

  Future<void> pauseCurrent() async {
    final player = controller;
    if (player == null) return;
    final run = generation;
    try {
      await player.pause();
    } catch (_) {
      failPlayback(player, run);
    }
  }

  Future<void> toggleSound(VideoPlayerController player) async {
    final run = generation;
    final nextMuted = !muted;
    try {
      await player.setVolume(nextMuted ? 0 : 1);
      if (current(run) && controller == player) {
        setState(() => muted = nextMuted);
      }
    } catch (_) {
      failPlayback(player, run);
    }
  }

  Future<void> togglePlayback(VideoPlayerController player) async {
    final run = generation;
    final intent = ++playbackIntent;
    try {
      if (player.value.isPlaying) {
        await player.pause();
        return;
      }
      if (player.value.position >= player.value.duration) {
        await player.seekTo(Duration.zero);
      }
      if (!canPlay(player, run, intent)) return;
      await player.play();
      if (!canPlay(player, run, intent)) await player.pause();
    } catch (_) {
      failPlayback(player, run);
    }
  }

  @override
  void didUpdateWidget(covariant LocalVideoPreview old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file ||
        old.controllerFactory != widget.controllerFactory) {
      unawaited(load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TickerMode.valuesOf(context).enabled;
    if (visible != next) {
      visible = next;
      if (!visible) {
        playbackIntent++;
        unawaited(pauseCurrent());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      playbackIntent++;
      unawaited(pauseCurrent());
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    controller?.removeListener(changed);
    unawaited(release(controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final ready = player != null && error == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Revisa tu video antes de subirlo.'),
        const Text(
          'Todavía no se ha enviado. Puedes reproducirlo o descartar la selección.',
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (player == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Preparando vista previa…'),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Center(
                child: AspectRatio(
                  aspectRatio: player.value.aspectRatio,
                  child: Semantics(
                    label: 'Vista previa local del video seleccionado',
                    child: VideoPlayer(player),
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Duración: ${(player.value.duration.inMilliseconds / 1000).toStringAsFixed(1)} s',
          ),
          Wrap(
            spacing: 8,
            children: [
              IconButton.filledTonal(
                tooltip: player.value.isPlaying
                    ? 'Pausar vista previa'
                    : 'Reproducir vista previa',
                onPressed: !foreground || !visible || submitting
                    ? null
                    : () => togglePlayback(player),
                icon: Icon(
                  player.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
              IconButton.filledTonal(
                tooltip: muted
                    ? 'Activar sonido de vista previa'
                    : 'Silenciar vista previa',
                onPressed: submitting ? null : () => toggleSound(player),
                icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
              ),
            ],
          ),
        ],
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: ready && foreground && visible && !submitting
                  ? accept
                  : null,
              child: const Text('Subir video'),
            ),
            TextButton(
              onPressed: submitting ? null : widget.onDiscard,
              child: const Text('Descartar selección'),
            ),
          ],
        ),
      ],
    );
  }
}
