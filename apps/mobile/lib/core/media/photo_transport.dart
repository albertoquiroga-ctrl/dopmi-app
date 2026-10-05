import 'dart:typed_data';

import 'photo_transport_web.dart'
    if (dart.library.io) 'photo_transport_io.dart'
    as platform;

class PhotoCancelled implements Exception {
  const PhotoCancelled();
}

class PhotoHttpFailure implements Exception {
  const PhotoHttpFailure(this.status);
  final int status;
}

class PhotoCancellation {
  bool cancelled = false;
  final _callbacks = <void Function()>{};
  void check() {
    if (cancelled) throw const PhotoCancelled();
  }

  void listen(void Function() callback) {
    if (cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void unlisten(void Function() callback) => _callbacks.remove(callback);
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final callback in _callbacks.toList()) {
      callback();
    }
    _callbacks.clear();
  }
}

typedef PhotoDownload = Future<Uint8List> Function(
  Uri uri,
  PhotoCancellation cancellation,
);

Future<Uint8List> downloadPhoto(Uri uri, PhotoCancellation cancellation) =>
    platform.downloadPhoto(uri, cancellation);

const photoDownloadLimit = 5 * 1024 * 1024;
