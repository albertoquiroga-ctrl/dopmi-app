import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dopmi_mobile/core/media/media_store.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/photo_store_io.dart';
import 'package:dopmi_mobile/core/media/photo_transport.dart';

final photograph = Uint8List.fromList(
  img.encodeJpg(img.Image(width: 16, height: 24)),
);

PhotoRef source({
  String path = 'approved/fixture.jpg',
  Future<String> Function()? sign,
  PhotoPersistence persistence = PhotoPersistence.ordinary,
}) => PhotoRef(
  path: path,
  purpose: MediaPurpose.adoptionPhoto,
  sign: sign ?? () async => 'https://example.test/photo?token=secret',
  persistence: persistence,
);

Future<PhotoRuntime> realRuntime(
  WidgetTester tester,
  PhotoStore store, {
  required PhotoDownload download,
  Duration retryDelay = Duration.zero,
}) async => (await tester.runAsync(
  () async =>
      PhotoRuntime(store: store, download: download, retryDelay: retryDelay),
))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'same object deduplicates signature, bytes and decoded provider',
    (tester) async {
      final runtime = await realRuntime(
        tester,
        MemoryPhotoStore(),
        download: (_, _) async => photograph,
      );
      final request = source();
      await tester.pump();
      await tester.runAsync(() async {
        final frames = await Future.wait([
          runtime.load(request, width: 128),
          runtime.load(request, width: 128),
        ]);
        expect(identical(frames[0].provider, frames[1].provider), isTrue);
        await runtime.load(request, width: 128);
      });
      expect(runtime.metrics.signatures, 1);
      expect(runtime.metrics.downloads, 1);
      expect(runtime.metrics.memoryHits, 1);
      runtime.dispose();
    },
  );

  testWidgets('two hung signing attempts stop at21 seconds, no third attempt', (
    tester,
  ) async {
    var signatures = 0;
    final late = <Completer<String>>[];
    final runtime = PhotoRuntime(store: MemoryPhotoStore());
    final pending = runtime.load(
      source(
        sign: () {
          signatures++;
          final request = Completer<String>();
          late.add(request);
          return request.future;
        },
      ),
    );
    final stopped = expectLater(pending, throwsA(isA<TimeoutException>()));
    await tester.pump();
    expect(signatures, 1);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(signatures, 2);
    await tester.pump(const Duration(seconds: 10));
    await stopped;
    await tester.pump(const Duration(minutes: 1));
    expect(signatures, 2);
    expect(runtime.metrics.cancelled, 2);
    for (final request in late) {
      request.complete('https://example.test/late');
    }
    await tester.pump();
    expect(runtime.metrics.downloads, 0);
    runtime.dispose();
  });

  testWidgets('hung transport is cancelled after two bounded attempts', (
    tester,
  ) async {
    PhotoCancellation? stalled;
    var downloads = 0;
    final runtime = PhotoRuntime(
      store: MemoryPhotoStore(),
      download: (_, cancellation) {
        downloads++;
        if (downloads <= 2) {
          stalled = cancellation;
          return Completer<Uint8List>().future;
        }
        return Future.value(photograph);
      },
    );
    final request = source();
    final stopped = expectLater(
      runtime.load(request),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(stalled!.cancelled, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
    await stopped;
    expect(downloads, 2);
    expect(stalled!.cancelled, isTrue);
    runtime.dispose();
  });

  testWidgets('signed GET failure refreshes once and recovers', (tester) async {
    var downloads = 0;
    final runtime = await realRuntime(
      tester,
      MemoryPhotoStore(),
      retryDelay: Duration.zero,
      download: (_, _) async {
        if (++downloads == 1) throw const PhotoHttpFailure(403);
        return photograph;
      },
    );
    await tester.pump();
    await tester.runAsync(() => runtime.load(source()));
    expect(runtime.metrics.signatures, 2);
    expect(downloads, 2);
    expect(runtime.metrics.retries, 1);
    runtime.dispose();
  });

  testWidgets('manual retry recovers after both automatic attempts fail', (
    tester,
  ) async {
    var downloads = 0;
    final runtime = await realRuntime(
      tester,
      MemoryPhotoStore(),
      download: (_, _) async {
        if (++downloads <= 2) throw const PhotoHttpFailure(503);
        return photograph;
      },
    );
    await tester.runAsync(() async {
      final request = source();
      await expectLater(
        runtime.load(request),
        throwsA(isA<PhotoHttpFailure>()),
      );
      final recovered = await runtime.retry(request, width: 128);
      expect(recovered.provider, isA<ImageProvider>());
    });
    expect(downloads, 3);
    runtime.dispose();
  });

  testWidgets(
    'denied signing never serves the saved photo and does not retry',
    (tester) async {
      final store = MemoryPhotoStore();
      final runtime = PhotoRuntime(store: store);
      final request = source(
        sign: () async =>
            throw const StorageException('denied', statusCode: '403'),
      );
      await store.write(runtime.key(request), photograph);
      await expectLater(
        runtime.load(request),
        throwsA(isA<StorageException>()),
      );
      await tester.pump();
      expect(runtime.metrics.signatures, 1);
      expect(runtime.metrics.downloads, 0);
      expect(store.entries, isEmpty);
      runtime.dispose();
    },
  );

  testWidgets('corrupt disk entry is purged before the single clean retry', (
    tester,
  ) async {
    final store = MemoryPhotoStore();
    final runtime = await realRuntime(
      tester,
      store,
      download: (_, _) async => photograph,
      retryDelay: Duration.zero,
    );
    final request = source();
    await store.write(runtime.key(request), Uint8List.fromList([1, 2, 3]));
    await tester.pump();
    await tester.runAsync(() => runtime.load(request));
    expect(runtime.metrics.retries, 1);
    expect(runtime.metrics.downloads, 1);
    expect(store.entries.values.single, photograph);
    runtime.dispose();
  });

  testWidgets('switching actor rejects late pixels and clears previous scope', (
    tester,
  ) async {
    final response = Completer<Uint8List>();
    final store = MemoryPhotoStore();
    final runtime = PhotoRuntime(
      store: store,
      actor: 'A',
      download: (_, _) => response.future,
    );
    final result = runtime.load(source());
    final rejected = expectLater(result, throwsA(isA<PhotoCancelled>()));
    await tester.pump();
    runtime.scope('B', ready: true);
    response.complete(photograph);
    await tester.pump();
    await rejected;
    expect(store.entries, isEmpty);
    runtime.dispose();
  });

  testWidgets('sensitive image leaves no persistent entry', (tester) async {
    final store = MemoryPhotoStore();
    final runtime = await realRuntime(
      tester,
      store,
      download: (_, _) async => photograph,
    );
    await tester.pump();
    await tester.runAsync(
      () => runtime.load(source(persistence: PhotoPersistence.memory)),
    );
    expect(store.entries, isEmpty);
    runtime.dispose();
  });

  testWidgets('prefetch is limited to two and visible reuses its download', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pending = <String, Completer<Uint8List>>{};
      final started = Completer<void>();
      final runtime = PhotoRuntime(
        store: MemoryPhotoStore(),
        download: (uri, cancellation) {
          final request = pending.putIfAbsent(
            uri.path,
            Completer<Uint8List>.new,
          );
          cancellation.listen(() {
            if (!request.isCompleted) {
              request.completeError(const PhotoCancelled());
            }
          });
          if (pending.length == 2 && !started.isCompleted) started.complete();
          return request.future;
        },
      );
      PhotoRef item(int i) => source(
        path: 'photo$i',
        sign: () async => 'https://example.test/photo$i',
      );
      final owner = Object();
      runtime.prefetch(owner, [item(1), item(2), item(3)], width: 128);
      await started.future;
      expect(pending.length, 2);
      final visible = runtime.load(item(1), width: 128);
      runtime.cancelPrefetch(owner);
      pending['/photo1']!.complete(photograph);
      await visible;
      expect(runtime.metrics.downloads, 2);
      runtime.dispose();
    });
  });
  testWidgets(
    'recreated disk runtime authorizes again without downloading body',
    (tester) async {
      var downloads = 0, signatures = 0;
      Future<Uint8List> transport(Uri _, PhotoCancellation cancellation) async {
        downloads++;
        return photograph;
      }

      final request = source(
        sign: () async => 'https://example.test/photo?token=${++signatures}',
      );
      await tester.pump();
      await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'dopmi-photo-test-',
        );
        var store = await DiskPhotoStore.open(directory: directory);
        final first = PhotoRuntime(
          store: store,
          actor: 'same-owner',
          download: transport,
        );
        await first.load(request);
        first.dispose();
        await store.close();
        store = await DiskPhotoStore.open(directory: directory);
        final reopened = PhotoRuntime(
          store: store,
          actor: 'same-owner',
          download: transport,
        );
        final frame = await reopened.load(request);
        expect(frame.origin, PhotoOrigin.disk);
        expect(downloads, 1);
        expect(signatures, 2);
        final index = await File('${directory.path}/index.json').readAsString();
        expect(index.contains('token='), isFalse);
        expect(index.contains('https://'), isFalse);
        reopened.dispose();
        await store.close();
        await directory.delete(recursive: true);
      });
    },
  );

  test(
    'disk enforces byte budget, entry count and absolute age despite reads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dopmi-photo-quota-',
      );
      var now = DateTime(2026, 10, 5);
      final store = await DiskPhotoStore.open(
        directory: directory,
        now: () => now,
        maxBytes: 8,
        maxFiles: 2,
        maxAge: const Duration(days: 7),
      );
      await store.scope('actor');
      await store.write('actor/1', Uint8List.fromList([1, 2, 3, 4]));
      now = now.add(const Duration(seconds: 1));
      await store.write('actor/2', Uint8List.fromList([5, 6, 7, 8]));
      now = now.add(const Duration(seconds: 1));
      await store.read('actor/1');
      now = now.add(const Duration(seconds: 1));
      await store.write('actor/3', Uint8List.fromList([9, 10, 11, 12]));
      expect(await store.read('actor/2'), isNull);
      expect(await store.read('actor/1'), isNotNull);
      expect(await store.read('actor/3'), isNotNull);
      now = now.add(const Duration(days: 7));
      expect(await store.read('actor/1'), isNull);
      expect(await store.read('actor/3'), isNull);
      await store.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'different actor and interrupted purge remove disk from the old scope',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dopmi-photo-scope-',
      );
      var store = await DiskPhotoStore.open(directory: directory);
      await store.scope('A');
      await store.write('A/1', photograph);
      await store.close();
      await File('${directory.path}/scope.json')
          .writeAsString('{"namespace":"B","purging":true}');
      store = await DiskPhotoStore.open(directory: directory);
      await store.scope('B');
      expect(await store.read('A/1'), isNull);
      expect(await store.manager.config.repo.getAllObjects(), isEmpty);
      await store.close();
      await directory.delete(recursive: true);
    },
  );
}
