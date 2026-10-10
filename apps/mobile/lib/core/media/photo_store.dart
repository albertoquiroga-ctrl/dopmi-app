import 'dart:typed_data';

/// Stores validated pixels only. Authorization is deliberately not persisted.
abstract interface class PhotoStore {
  Future<void> scope(String namespace);
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<void> remove(String key);
  Future<void> clear();
  Future<void> close();
}

class MemoryPhotoStore implements PhotoStore {
  final entries = <String, Uint8List>{};
  String? _scope;
  @override
  Future<void> scope(String namespace) async {
    if (_scope != null && _scope != namespace) entries.clear();
    _scope = namespace;
  }

  @override
  Future<Uint8List?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, Uint8List bytes) async => entries[key] = bytes;
  @override
  Future<void> remove(String key) async => entries.remove(key);
  @override
  Future<void> clear() async => entries.clear();
  @override
  Future<void> close() async {}
}
