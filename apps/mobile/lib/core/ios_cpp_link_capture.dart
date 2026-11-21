import 'dart:async';

import 'ios_cpp_acquisition.dart';

/// Subscribes before asynchronous startup can replace the initial campaign URL.
class IosCppLinkCapture {
  IosCppLinkCapture({
    required this.events,
    required this.readInitial,
    required this.acquisition,
    this.onCaptured,
  });

  final Stream<Uri> events;
  final Future<Uri?> Function() readInitial;
  final Future<IosCppAcquisition?> acquisition;
  final void Function()? onCaptured;
  StreamSubscription<Uri>? _subscription;
  Future<void> _initial = Future.value();
  Future<void> _pending = Future.value();
  bool _started = false, _disposed = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscription = events.listen(_capture, onError: (Object _) {});
    _initial = _readInitial();
  }

  Future<void> _readInitial() async {
    try {
      final uri = await readInitial().timeout(const Duration(seconds: 3));
      if (uri != null) _capture(uri);
    } catch (_) {
      // A platform failure must leave ordinary startup available.
    }
  }

  void _capture(Uri uri) {
    if (_disposed || iosCppVariant(uri) == null) return;
    _pending = _pending
        .then((_) async {
          final service = await acquisition;
          if (_disposed || service == null) return;
          await service.capture(uri);
          if (!_disposed) onCaptured?.call();
        })
        .catchError((Object _) {});
  }

  Future<void> get ready async {
    await _initial;
    await _pending;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
  }
}
