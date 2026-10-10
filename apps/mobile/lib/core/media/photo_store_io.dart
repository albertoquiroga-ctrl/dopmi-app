import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file/file.dart' as fs;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'photo_store.dart';

PhotoStore createPhotoStore() => _LazyPhotoStore();

class _LazyPhotoStore implements PhotoStore {
  final Future<DiskPhotoStore> _store = DiskPhotoStore.open();
  @override
  Future<void> scope(String namespace) async => (await _store).scope(namespace);
  @override
  Future<Uint8List?> read(String key) async => (await _store).read(key);
  @override
  Future<void> write(String key, Uint8List bytes) async =>
      (await _store).write(key, bytes);
  @override
  Future<void> remove(String key) async => (await _store).remove(key);
  @override
  Future<void> clear() async => (await _store).clear();
  @override
  Future<void> close() async => (await _store).close();
}

class _PhotoFileSystem implements FileSystem {
  _PhotoFileSystem(this.path);
  final String path;
  @override
  Future<fs.File> createFile(String name) async {
    if (!RegExp(r'^[0-9a-f-]{36}\.photo$').hasMatch(name)) {
      throw const FormatException('invalid_photo_cache_name');
    }
    final directory = const LocalFileSystem().directory(path);
    await directory.create(recursive: true);
    return directory.childFile(name);
  }
}

/// CacheManager is used only as a local file store. Its network-first/stale
/// streams are never exposed, and its metadata never receives a signed URL.
class DiskPhotoStore implements PhotoStore {
  DiskPhotoStore._(
    this.directory,
    this.manager,
    this.now,
    this.maxBytes,
    this.maxFiles,
    this.maxAge,
  );
  static Future<DiskPhotoStore> open({
    io.Directory? directory,
    DateTime Function()? now,
    int maxBytes = 50 * 1024 * 1024,
    int maxFiles = 100,
    Duration maxAge = const Duration(days: 7),
  }) async {
    final root =
        directory ??
        io.Directory('${(await getTemporaryDirectory()).path}/dopmi-photo-v1');
    await root.create(recursive: true);
    final manager = CacheManager(
      Config(
        'dopmi-photo-v1',
        stalePeriod: maxAge,
        maxNrOfCacheObjects: maxFiles,
        repo: JsonCacheInfoRepository(path: '${root.path}/index.json'),
        fileSystem: _PhotoFileSystem(root.path),
      ),
    );
    await manager.config.repo.open();
    return DiskPhotoStore._(
      root,
      manager,
      now ?? DateTime.now,
      maxBytes,
      maxFiles,
      maxAge,
    );
  }

  final io.Directory directory;
  final CacheManager manager;
  final DateTime Function() now;
  final int maxBytes, maxFiles;
  final Duration maxAge;
  Future<void> _tail = Future.value();
  String? _namespace;
  bool _closed = false;
  CacheInfoRepository get _repo => manager.config.repo;

  Future<T> _serial<T>(Future<T> Function() action) {
    final work = _tail.then((_) {
      if (_closed) throw StateError('photo_store_closed');
      return action();
    });
    _tail = work.then<void>((_) {}, onError: (Object _) {});
    return work;
  }

  @override
  Future<void> scope(String namespace) => _serial(() async {
    final marker = io.File('${directory.path}/scope.json');
    Map<String, dynamic>? previous;
    if (await marker.exists()) {
      try {
        previous =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        previous = {'purging': true};
      }
    }
    if (previous != null &&
        (previous['namespace'] != namespace || previous['purging'] == true)) {
      await marker.writeAsString(
        jsonEncode({'namespace': namespace, 'purging': true}),
        flush: true,
      );
      await manager.emptyCache();
      manager.store.emptyMemoryCache();
    }
    _namespace = namespace;
    await marker.writeAsString(
      jsonEncode({'namespace': namespace, 'purging': false}),
      flush: true,
    );
    await _prune();
  });

  bool _belongs(String key) =>
      _namespace != null && key.startsWith('$_namespace/');

  CacheObject _metadata(CacheObject old, {DateTime? validTill, int? length}) =>
      CacheObject(
        old.url,
        key: old.key,
        id: old.id,
        relativePath: old.relativePath,
        validTill: validTill ?? old.validTill,
        touched: now(),
        length: length ?? old.length,
      );

  @override
  Future<Uint8List?> read(String key) => _serial(() async {
    if (!_belongs(key)) return null;
    final row = await _repo.get(key);
    if (row == null) return null;
    if (!row.validTill.isAfter(now())) {
      await manager.removeFile(key);
      return null;
    }
    try {
      final file = await manager.config.fileSystem.createFile(row.relativePath);
      if (!await file.exists()) {
        await manager.removeFile(key);
        return null;
      }
      final bytes = await file.readAsBytes();
      if (row.length != bytes.length || bytes.isEmpty) {
        await manager.removeFile(key);
        return null;
      }
      await _repo.update(_metadata(row), setTouchedToNow: false);
      return bytes;
    } on io.FileSystemException {
      await manager.removeFile(key);
      return null;
    }
  });

  @override
  Future<void> write(String key, Uint8List bytes) => _serial(() async {
    if (!_belongs(key) || bytes.isEmpty || bytes.length > maxBytes) return;
    await manager.putFile(
      'dopmi-photo:$key',
      bytes,
      key: key,
      maxAge: maxAge,
      fileExtension: 'photo',
    );
    final row = await _repo.get(key);
    if (row != null) {
      await _repo.update(
        _metadata(row, validTill: now().add(maxAge), length: bytes.length),
        setTouchedToNow: false,
      );
    }
    await _prune();
  });

  Future<void> _prune() async {
    final rows = await _repo.getAllObjects();
    final retained = <CacheObject>[];
    var size = 0;
    for (final row in rows) {
      if (!_belongs(row.key) || !row.validTill.isAfter(now())) {
        await manager.removeFile(row.key);
      } else {
        retained.add(row);
        size += row.length ?? maxBytes + 1;
      }
    }
    retained.sort(
      (a, b) => (a.touched ?? DateTime(0)).compareTo(b.touched ?? DateTime(0)),
    );
    while (retained.length > maxFiles || size > maxBytes) {
      final oldest = retained.removeAt(0);
      size -= oldest.length ?? maxBytes + 1;
      await manager.removeFile(oldest.key);
    }
  }

  @override
  Future<void> remove(String key) => _serial(() => manager.removeFile(key));
  @override
  Future<void> clear() => _serial(() async {
    await manager.emptyCache();
    manager.store.emptyMemoryCache();
  });
  @override
  Future<void> close() async {
    await _tail;
    if (_closed) return;
    _closed = true;
    await manager.dispose();
  }
}
