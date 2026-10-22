import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Decoder adapter fake for widget contracts, never evidence of real playback.
class LocalVideoTestController extends VideoPlayerController {
  LocalVideoTestController({
    this.duration = const Duration(seconds: 2),
    this.decoderFails = false,
    this.initializing,
    this.seeking,
  }) : super.asset('local-preview-test');

  final Duration duration;
  final bool decoderFails;
  final Completer<void>? initializing;
  final Completer<void>? seeking;
  Completer<void>? pausing;
  bool disposed = false;
  int plays = 0, pauses = 0;
  int playRequests = 0;
  bool failPlay = false, failVolume = false, failPause = false;
  final volumes = <double>[];

  @override
  Future<void> initialize() async {
    await initializing?.future;
    if (decoderFails) throw StateError('local_decoder_failed');
    if (disposed) return;
    value = VideoPlayerValue(
      duration: duration,
      size: const Size(640, 360),
      isInitialized: true,
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    if (failVolume) throw StateError('volume_failed');
    if (disposed) return;
    volumes.add(volume);
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> play() async {
    playRequests++;
    if (failPlay) throw StateError('play_failed');
    if (disposed) return;
    plays++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    await pausing?.future;
    if (failPause) throw StateError('pause_failed');
    if (disposed) return;
    pauses++;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    await seeking?.future;
    if (!disposed) value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await super.dispose();
  }
}
