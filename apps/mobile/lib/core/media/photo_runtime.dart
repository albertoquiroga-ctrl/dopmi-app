import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_store.dart';
import 'photo_store.dart';
import 'photo_transport.dart';

enum PhotoPersistence { memory, ordinary }

enum PhotoOrigin { network, disk, memory }

@immutable
class PhotoRef {
  const PhotoRef({
    required this.path,
    required this.purpose,
    required this.sign,
    this.revision = '',
    this.persistence = PhotoPersistence.memory,
  });
  final String path, revision;
  final MediaPurpose purpose;
  final Future<String> Function() sign;
  final PhotoPersistence persistence;
  String get identity => jsonEncode([
    purpose.bucket,
    path,
    revision,
    purpose.name,
    persistence.name,
  ]);
}

class PhotoFrame {
  const PhotoFrame(this.provider, this.validUntil, this.origin);
  final ImageProvider provider;
  final DateTime validUntil;
  final PhotoOrigin origin;
}

class PhotoMetrics {
  String phase = 'idle';
  int downloads = 0, diskHits = 0, memoryHits = 0, signatures = 0;
  int retries = 0, cancelled = 0;
  final List<int> decodedMilliseconds = [];
}

/// The default supports isolated widget fixtures. Bootstrap installs the
/// production instance, gated by the server-validated identity restoration.
final photoRuntimeProvider = Provider<PhotoRuntime>((ref) {
  final runtime = PhotoRuntime(store: MemoryPhotoStore());
  ref.onDispose(runtime.dispose);
  return runtime;
});

class _Lease {
  _Lease(this.url, this.until);
  final String url;
  final DateTime until;
}

class _Pixels {
  _Pixels(this.bytes);
  final Uint8List bytes;
  final providers = <int, ImageProvider>{};
  final decodedWidths = <int>{};
  ImageProvider provider(int width) => providers.putIfAbsent(
    width,
    () => ResizeImage.resizeIfNeeded(
      width == 0 ? null : width,
      null,
      MemoryImage(bytes),
    ),
  );
  Future<void> evict() async {
    for (final provider in providers.values) {
      final key = await provider.obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.evict(key, includeLive: true);
    }
  }
}

class _Job {
  _Job(this.generation, {required this.visible, this.owner});
  final int generation;
  bool visible;
  Object? owner;
  bool cancelled = false;
  bool untrackedConsumer = false;
  final consumers = <Object>{};
  final stopped = Completer<_Pixels>();
  PhotoCancellation cancellation = PhotoCancellation();
  late Future<_Pixels> future;
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    cancellation.cancel();
    stopped.completeError(const PhotoCancelled());
  }
}

class PhotoRuntime extends ChangeNotifier {
  PhotoRuntime({
    required this.store,
    this.environment = 'fixture',
    // Keep the mutable actor private while exposing a named constructor input.
    String actor = 'anonymous',
    bool ready = true,
    PhotoDownload? download,
    DateTime Function()? now,
    this.attemptTimeout = const Duration(seconds: 10),
    this.retryDelay = const Duration(seconds: 1),
    // ignore: prefer_initializing_formals
  }) : _actor = actor,
       _ready = ready,
       _download = download ?? downloadPhoto,
       _now = now ?? DateTime.now {
    _scopeReady = _prepareScope();
    if (ready) _restored.complete();
  }
  final PhotoStore store;
  final String environment;
  final PhotoDownload _download;
  final DateTime Function() _now;
  final Duration attemptTimeout, retryDelay;
  final metrics = PhotoMetrics();
  final _leases = <String, _Lease>{};
  final _pixels = <String, _Pixels>{};
  final _jobs = <String, _Job>{};
  final _prefetchQueue = <({Object owner, PhotoRef ref, int width})>[];
  int _generation = 0, _background = 0;
  String _actor;
  bool _ready, _disposed = false;
  Completer<void> _restored = Completer<void>();
  late Future<void> _scopeReady;
  bool _diskAvailable = true;
  bool _scopePrepared = false;
  Future<void> _prepareScope() async {
    final generation = _generation;
    try {
      await store.scope(_namespace);
      _diskAvailable = true;
    } catch (_) {
      _diskAvailable = false;
    }
    if (generation == _generation) _scopePrepared = true;
  }

  Future<void> _removeDisk(String identity) async {
    try {
      await store.remove(identity);
    } catch (_) {
      _diskAvailable = false;
    }
  }

  String get _namespace => _hash(jsonEncode([environment, _actor]));
  String key(PhotoRef ref) => '$_namespace/${_hash(ref.identity)}';
  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  bool get ready => _ready;
  bool expired(PhotoFrame frame) =>
      !frame.validUntil.isAfter(_now().add(const Duration(seconds: 30)));

  void scope(String actor, {required bool ready}) {
    if (_disposed) return;
    final changed = actor != _actor;
    if (changed) {
      _generation++;
      _cancelAll();
      _actor = actor;
      _leases.clear();
      _lastOrigins.clear();
      for (final pixels in _pixels.values) {
        unawaited(pixels.evict());
      }
      _pixels.clear();
      if (!_restored.isCompleted) _restored.complete();
      _restored = Completer<void>();
      _scopePrepared = false;
      _scopeReady = _prepareScope();
    }
    _ready = ready;
    if (ready && !_restored.isCompleted) _restored.complete();
    notifyListeners();
    _pumpPrefetch();
  }

  Future<PhotoFrame> load(
    PhotoRef ref, {
    int width = 0,
    Object? consumer,
  }) async {
    final elapsed = Stopwatch()..start();
    final identity = key(ref);
    var job = _jobs[identity];
    if (job != null && job.cancelled) {
      _jobs.remove(identity);
      job = null;
    }
    if (job == null) {
      job = _start(ref, width, visible: true);
    } else {
      // A visible consumer promotes a prefetch without a second request.
      job.visible = true;
      job.owner = null;
    }
    if (consumer == null) {
      job.untrackedConsumer = true;
    } else {
      job.consumers.add(consumer);
    }
    final pixels = await job.future;
    _check(job);
    final provider = pixels.provider(width);
    if (!pixels.decodedWidths.contains(width)) {
      final remaining = attemptTimeout * 2 + retryDelay - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('photo_timeout_decode');
      }
      try {
        await _decode(provider, job.cancellation).timeout(
          remaining,
          onTimeout: () {
            job!.cancellation.cancel();
            throw TimeoutException('photo_timeout_decode');
          },
        );
        pixels.decodedWidths.add(width);
      } catch (_) {
        unawaited(pixels.evict());
        rethrow;
      }
    }
    _check(job);
    final lease = _leases[identity];
    if (lease == null) throw const PhotoCancelled();
    return PhotoFrame(
      provider,
      lease.until,
      _lastOrigins[identity] ?? PhotoOrigin.memory,
    );
  }

  final _lastOrigins = <String, PhotoOrigin>{};

  _Job _start(PhotoRef ref, int width, {required bool visible, Object? owner}) {
    final identity = key(ref);
    final job = _Job(_generation, visible: visible, owner: owner);
    _jobs[identity] = job;
    job.future =
        Future.any([_drive(ref, identity, width, job), job.stopped.future])
            .whenComplete(() {
              if (identical(_jobs[identity], job)) _jobs.remove(identity);
              _pumpPrefetch();
            });
    // Prefetch may not have a consumer until a later frame.
    job.future.ignore();
    return job;
  }

  void _check(_Job job) {
    job.cancellation.check();
    if (_disposed ||
        job.cancelled ||
        job.generation != _generation ||
        !_ready) {
      throw const PhotoCancelled();
    }
  }

  Future<_Pixels> _drive(
    PhotoRef ref,
    String identity,
    int width,
    _Job job,
  ) async {
    final stopwatch = Stopwatch()..start();
    for (var attempt = 0; attempt < 2; attempt++) {
      job.cancellation = PhotoCancellation();
      try {
        final result =
            await Future.any([
              _attempt(ref, identity, width, job),
              job.stopped.future,
            ]).timeout(
              attemptTimeout,
              onTimeout: () {
                job.cancellation.cancel();
                metrics.cancelled++;
                throw TimeoutException('photo_timeout_${metrics.phase}');
              },
            );
        metrics.decodedMilliseconds.add(stopwatch.elapsedMilliseconds);
        if (metrics.decodedMilliseconds.length > 100) {
          metrics.decodedMilliseconds.removeAt(0);
        }
        return result;
      } catch (error) {
        if (error is PhotoCancelled ||
            _disposed ||
            job.cancelled ||
            job.generation != _generation) {
          rethrow;
        }
        // Signing denial is authoritative; an old signed GET is not.
        final denied =
            error is StorageException &&
            ['400', '401', '403', '404'].contains(error.statusCode);
        final missing = error is PhotoHttpFailure && error.status == 404;
        _leases.remove(identity);
        final badPixels = _pixels.remove(identity);
        if (badPixels != null) unawaited(badPixels.evict());
        if (denied || missing || error is FormatException) {
          unawaited(_removeDisk(identity));
        }
        if (denied || missing || attempt == 1 || !job.visible) rethrow;
        metrics.retries++;
        await _pause(job);
        if (_disposed || job.cancelled || job.generation != _generation) {
          throw const PhotoCancelled();
        }
      }
    }
    throw StateError('photo_attempts_exhausted');
  }

  Future<void> _pause(_Job job) {
    final done = Completer<void>();
    final timer = Timer(retryDelay, done.complete);
    return Future.any<void>([
      done.future,
      job.stopped.future.then<void>((_) {}),
    ]).whenComplete(timer.cancel);
  }

  Future<_Pixels> _attempt(
    PhotoRef ref,
    String identity,
    int width,
    _Job job,
  ) async {
    final cancellation = job.cancellation;
    metrics.phase = 'restoration';
    if (!_restored.isCompleted) await _restored.future;
    if (!_scopePrepared) await _scopeReady;
    _check(job);
    metrics.phase = 'authorization';
    var lease = _leases[identity];
    if (lease == null ||
        !lease.until.isAfter(_now().add(const Duration(seconds: 30)))) {
      final started = _now();
      metrics.signatures++;
      final url = await ref.sign();
      cancellation.check();
      _check(job);
      lease = _Lease(
        url,
        started.add(const Duration(seconds: mediaSignedUrlLifetimeSeconds)),
      );
      _leases[identity] = lease;
      _leases.removeWhere((key, value) => !value.until.isAfter(_now()));
      while (_leases.length > 256) {
        _leases.remove(_leases.keys.first);
      }
    }
    metrics.phase = 'cache_read';
    var pixels = _pixels.remove(identity);
    var origin = PhotoOrigin.memory;
    if (pixels != null) {
      metrics.memoryHits++;
    } else {
      Uint8List? bytes;
      if (_diskAvailable && ref.persistence == PhotoPersistence.ordinary) {
        try {
          bytes = await store.read(identity);
        } catch (_) {
          _diskAvailable = false;
        }
        cancellation.check();
        _check(job);
      }
      if (bytes != null) {
        origin = PhotoOrigin.disk;
        metrics.diskHits++;
      } else {
        origin = PhotoOrigin.network;
        metrics.phase = 'download';
        metrics.downloads++;
        bytes = await _download(Uri.parse(lease.url), cancellation);
      }
      cancellation.check();
      _check(job);
      pixels = _Pixels(bytes);
    }
    try {
      metrics.phase = 'decode';
      if (!pixels.decodedWidths.contains(width)) {
        await _decode(pixels.provider(width), cancellation);
        pixels.decodedWidths.add(width);
      }
    } catch (_) {
      unawaited(pixels.evict());
      await _removeDisk(identity);
      rethrow;
    }
    cancellation.check();
    _check(job);
    if (_diskAvailable &&
        ref.persistence == PhotoPersistence.ordinary &&
        origin == PhotoOrigin.network) {
      // No signed URL enters the disk manager, including its metadata.
      try {
        metrics.phase = 'cache_write';
        await store.write(identity, pixels.bytes);
      } catch (_) {
        // Disk exhaustion must not hide a successfully downloaded photo.
      }
    }
    cancellation.check();
    _check(job);
    _pixels[identity] = pixels;
    metrics.phase = 'ready';
    _lastOrigins[identity] = origin;
    while (_pixels.length > 40 ||
        _pixels.values.fold<int>(0, (sum, entry) => sum + entry.bytes.length) >
            10 * 1024 * 1024) {
      final oldest = _pixels.keys.first;
      _pixels.remove(oldest);
      _lastOrigins.remove(oldest);
    }
    return pixels;
  }

  Future<void> _decode(ImageProvider provider, PhotoCancellation cancellation) {
    final result = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    void detach() => stream.removeListener(listener);
    void abort() {
      detach();
      if (!result.isCompleted) result.completeError(const PhotoCancelled());
    }

    listener = ImageStreamListener(
      (info, _) {
        info.dispose();
        if (!result.isCompleted) result.complete();
        detach();
      },
      onError: (Object error, StackTrace? stack) {
        if (!result.isCompleted) result.completeError(error, stack);
        detach();
      },
    );
    stream.addListener(listener);
    cancellation.listen(abort);
    return result.future.whenComplete(() => cancellation.unlisten(abort));
  }

  Future<PhotoFrame> retry(
    PhotoRef ref, {
    int width = 0,
    Object? consumer,
  }) async {
    await invalidate(ref);
    return load(ref, width: width, consumer: consumer);
  }

  void release(Object consumer) {
    for (final job in _jobs.values.toList()) {
      if (job.consumers.remove(consumer) &&
          job.consumers.isEmpty &&
          job.visible &&
          !job.untrackedConsumer) {
        job.cancel();
      }
    }
  }

  Future<void> invalidate(PhotoRef ref, {bool removeDisk = false}) async {
    final identity = key(ref);
    _jobs.remove(identity)?.cancel();
    _leases.remove(identity);
    final pixels = _pixels.remove(identity);
    _lastOrigins.remove(identity);
    if (pixels != null) await pixels.evict();
    if (removeDisk) await _removeDisk(identity);
  }

  void prefetch(Object owner, List<PhotoRef> refs, {int width = 0}) {
    cancelPrefetch(owner);
    for (final ref in refs.take(2)) {
      _prefetchQueue.add((owner: owner, ref: ref, width: width));
    }
    _pumpPrefetch();
  }

  void cancelPrefetch(Object owner) {
    _prefetchQueue.removeWhere((request) => identical(request.owner, owner));
    for (final job in _jobs.values.toList()) {
      if (!job.visible && identical(job.owner, owner)) {
        job.cancel();
      }
    }
  }

  void _pumpPrefetch() {
    if (_disposed || !_ready) return;
    if (_jobs.values.any((job) => job.visible && !job.cancelled)) return;
    while (_background < 2 && _prefetchQueue.isNotEmpty) {
      final request = _prefetchQueue.removeAt(0);
      if (_jobs.containsKey(key(request.ref))) continue;
      _background++;
      final job = _start(
        request.ref,
        request.width,
        visible: false,
        owner: request.owner,
      );
      unawaited(
        job.future.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
          _background--;
          _pumpPrefetch();
        }),
      );
    }
  }

  void _cancelAll() {
    _prefetchQueue.clear();
    for (final job in _jobs.values.toList()) {
      job.cancel();
    }
    _jobs.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelAll();
    if (!_restored.isCompleted) _restored.complete();
    for (final pixels in _pixels.values) {
      unawaited(pixels.evict());
    }
    _pixels.clear();
    unawaited(store.close());
    super.dispose();
  }
}
