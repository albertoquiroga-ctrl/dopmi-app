/// An account/environment cycle, independent of analytics consent and location.
/// The current front card stays on screen; only later catalog loads exclude it.
class DiscoveryHistory {
  DiscoveryHistory({
    required this.scope,
    required this.isCurrent,
    this.read,
    this.mark,
    this.reset,
  });

  final String scope;
  final bool Function() isCurrent;
  final Future<Set<String>> Function()? read;
  final Future<void> Function(String postId)? mark;
  final Future<void> Function()? reset;
  final seen = <String>{};
  final _failed = <String>{};
  final _writing = <String>{};
  Future<void> _tail = Future.value();
  int _epoch = 0;
  bool _disposed = false;

  bool _current(int epoch) => !_disposed && epoch == _epoch && isCurrent();

  Future<void> restore() async {
    final epoch = _epoch;
    await _tail.catchError((Object _) {});
    if (!_current(epoch)) return;
    for (final id in _failed.toList()) {
      await _write(id, epoch);
      if (!_current(epoch)) return;
    }
    final beforeRead = Set<String>.of(seen);
    final snapshot = await read?.call() ?? <String>{};
    if (_current(epoch) && read != null) {
      // A restart on another phone is authoritative. Retain only new local
      // fronts observed while this snapshot was being requested.
      seen.removeAll(beforeRead);
      seen.addAll(snapshot);
    }
  }

  Future<void> remember(String id) async {
    if (!_current(_epoch) || _writing.contains(id)) return;
    if (!seen.add(id)) return;
    await _write(id, _epoch);
  }

  Future<void> _write(String id, int epoch) async {
    _writing.add(id);
    final operation = _tail.catchError((Object _) {}).then((_) async {
      if (_current(epoch)) await mark?.call(id);
    });
    _tail = operation;
    try {
      await operation;
      if (_current(epoch)) _failed.remove(id);
    } catch (_) {
      if (_current(epoch)) _failed.add(id);
      rethrow;
    } finally {
      if (_current(epoch)) _writing.remove(id);
    }
  }

  Future<void> restart() async {
    final epoch = ++_epoch;
    // Drain an already-sent mark before resetting; queued old marks are skipped.
    await _tail.catchError((Object _) {});
    if (!_current(epoch)) return;
    _writing.clear();
    await reset?.call();
    if (!_current(epoch)) return;
    seen.clear();
    _failed.clear();
    _writing.clear();
  }

  void dispose() {
    _disposed = true;
    _epoch++;
  }
}
