import 'dart:convert';
import 'dart:io';

import 'package:dopmi_mobile/core/media/media_store.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store_io.dart';
import 'package:flutter_test/flutter_test.dart';

// Controlled network comparison, not a claim about installed device latency.
void main() {
  testWidgets('ten covers, gallery and reopening: cold versus warm', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await File('assets/onboarding/account-rescue.jpg')
          .readAsBytes();
      final results = <String, Object>{};
      for (final prefetch in [false, true]) {
        final directory = await Directory.systemTemp.createTemp(
          'dopmi-photo-bench-',
        );
        final store = await DiskPhotoStore.open(directory: directory);
        final loader = PhotoRuntime(
          store: store,
          actor: 'synthetic-benchmark',
          download: (_, _) async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return bytes;
          },
        );
        PhotoRef source(int index) => PhotoRef(
          path: 'synthetic/$index.jpg',
          purpose: MediaPurpose.adoptionPhoto,
          persistence: PhotoPersistence.ordinary,
          sign: () async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return 'https://example.test/synthetic/$index';
          },
        );
        final cold = <int>[];
        final owner = Object();
        for (var index = 0; index < 10; index++) {
          final watch = Stopwatch()..start();
          await loader.load(source(index), width: 512);
          cold.add(watch.elapsedMilliseconds);
          if (prefetch) {
            loader.prefetch(owner, [
              if (index + 1 < 10) source(index + 1),
              if (index + 2 < 10) source(index + 2),
            ], width: 512);
          }
          // Fixed reading time before each swipe, identical in both routes.
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        loader.cancelPrefetch(owner);
        await loader.load(source(10), width: 512);
        if (prefetch) loader.prefetch(owner, [source(11)], width: 512);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final galleryWatch = Stopwatch()..start();
        await loader.load(source(11), width: 512);
        final galleryMs = galleryWatch.elapsedMilliseconds;
        final warm = <int>[];
        for (var index = 0; index < 10; index++) {
          final watch = Stopwatch()..start();
          await loader.load(source(index), width: 512);
          warm.add(watch.elapsedMilliseconds);
        }
        final downloads = loader.metrics.downloads;
        loader.dispose();
        await store.close();
        final restoredStore = await DiskPhotoStore.open(directory: directory);
        final restored = PhotoRuntime(
          store: restoredStore,
          actor: 'synthetic-benchmark',
          download: (_, _) async =>
              throw StateError('reopening must not download'),
        );
        final reopened = <int>[];
        for (var index = 0; index < 12; index++) {
          final watch = Stopwatch()..start();
          await restored.load(source(index), width: 512);
          reopened.add(watch.elapsedMilliseconds);
        }
        expect(restored.metrics.downloads, 0);
        expect(restored.metrics.signatures, 12);
        results[prefetch ? 'prefetch' : 'withoutPrefetch'] = {
          'coldMs': cold,
          'warmMs': warm,
          'galleryMs': galleryMs,
          'reopenedMs': reopened,
          'downloads': downloads,
          'reopenedDownloads': restored.metrics.downloads,
        };
        restored.dispose();
        await restoredStore.close();
        await directory.delete(recursive: true);
      }
      const output = String.fromEnvironment('PHOTO_RESULT');
      if (output.isNotEmpty) {
        final file = File(output);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(results),
        );
      }
      // ignore: avoid_print
      print(jsonEncode(results));
    });
  });
}
