import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/photo_prefetch.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/photo_transport.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_runtime_test.dart' show photograph, realRuntime, source;

const photoKey = ValueKey('preview-photo');

Widget view(
  PhotoRuntime runtime,
  PhotoRef request, {
  required bool preview,
  List<PhotoRef>? upcoming,
  VoidCallback? onDisplayed,
}) => ProviderScope(
  overrides: [photoRuntimeProvider.overrideWithValue(runtime)],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(devicePixelRatio: 1),
      child: child!,
    ),
    home: PhotoPrefetch(
      sources: upcoming ?? const [],
      width: 128,
      child: RemotePhoto(
        key: photoKey,
        source: request,
        preview: preview,
        onDisplayed: onDisplayed,
        width: 128,
        height: 160,
        loading: const Text('Cargando'),
        unavailable: (retry) =>
            TextButton(onPressed: retry, child: const Text('Reintentar')),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'display callback excludes prefetch and decoded background preview',
    (tester) async {
      final runtime = await realRuntime(
        tester,
        MemoryPhotoStore(),
        download: (_, _) async => photograph,
      );
      addTearDown(runtime.dispose);
      final request = source();
      await tester.runAsync(() => runtime.load(request, width: 128));
      var displayed = 0;
      await tester.pumpWidget(
        view(runtime, request, preview: true, onDisplayed: () => displayed++),
      );
      await tester.pump();
      expect(displayed, 0);
      await tester.pumpWidget(
        view(runtime, request, preview: false, onDisplayed: () => displayed++),
      );
      await tester.pump();
      expect(displayed, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('readyFrame follows authorization, scope and invalidation', (
    tester,
  ) async {
    final runtime = await realRuntime(
      tester,
      MemoryPhotoStore(),
      download: (_, _) async => photograph,
    );
    addTearDown(runtime.dispose);
    final request = source();
    var updates = 0;
    runtime.frameUpdates.addListener(() => updates++);
    expect(runtime.readyFrame(request, width: 128), isNull);
    final loaded = (await tester.runAsync(
      () => runtime.load(request, width: 128),
    ))!;
    expect(runtime.readyFrame(request, width: 128)!.provider, loaded.provider);
    expect(updates, greaterThan(0));
    final afterLoad = updates;
    await tester.runAsync(() => runtime.invalidate(request));
    expect(runtime.readyFrame(request, width: 128), isNull);
    expect(updates, greaterThan(afterLoad));
    await tester.runAsync(() => runtime.load(request, width: 128));
    expect(runtime.readyFrame(request, width: 128), isNotNull);
    final downloads = runtime.metrics.downloads;
    runtime.scope('another-account', ready: false);
    expect(runtime.readyFrame(request, width: 128), isNull);
    runtime.scope('another-account', ready: true);
    await tester.pump();
    expect(runtime.readyFrame(request, width: 128), isNull);
    expect(runtime.metrics.downloads, downloads);
  });

  testWidgets('readyFrame does not decode another width or renew expiry', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 5);
    final runtime = (await tester.runAsync(
      () async => PhotoRuntime(
        store: MemoryPhotoStore(),
        now: () => now,
        download: (_, _) async => photograph,
      ),
    ))!;
    addTearDown(runtime.dispose);
    final request = source();
    await tester.runAsync(() => runtime.load(request, width: 128));
    expect(runtime.readyFrame(request, width: 128), isNotNull);
    expect(runtime.readyFrame(request, width: 256), isNull);
    now = now.add(const Duration(minutes: 20));
    expect(runtime.readyFrame(request, width: 128), isNull);
    expect(runtime.metrics.signatures, 1);
    expect(runtime.metrics.downloads, 1);
  });

  testWidgets('preview does not load, retry or restart on resume', (
    tester,
  ) async {
    final runtime = PhotoRuntime(
      store: MemoryPhotoStore(),
      download: (_, _) async => throw const PhotoHttpFailure(503),
    );
    addTearDown(runtime.dispose);
    final request = source();
    await tester.pumpWidget(view(runtime, request, preview: true));
    await tester.pump(const Duration(seconds: 30));
    expect(runtime.metrics.signatures, 0);
    expect(runtime.metrics.downloads, 0);
    final owner = Object();
    runtime.prefetch(owner, [request], width: 128);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 30));
    expect(runtime.metrics.signatures, 1);
    expect(runtime.metrics.downloads, 1);
    expect(runtime.metrics.retries, 0);
    expect(find.text('Cargando'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ready preview promotes without replacing state or provider', (
    tester,
  ) async {
    final runtime = await realRuntime(
      tester,
      MemoryPhotoStore(),
      download: (_, _) async => photograph,
    );
    addTearDown(runtime.dispose);
    final request = source();
    final loaded = (await tester.runAsync(
      () => runtime.load(request, width: 128),
    ))!;
    await tester.pumpWidget(view(runtime, request, preview: true));
    await tester.pump();
    final originalState = tester.state(find.byKey(photoKey));
    expect(tester.widget<Image>(find.byType(Image)).image, loaded.provider);
    final hits = runtime.metrics.memoryHits;
    await tester.pumpWidget(view(runtime, request, preview: false));
    await tester.pump();
    expect(tester.state(find.byKey(photoKey)), same(originalState));
    expect(tester.widget<Image>(find.byType(Image)).image, loaded.provider);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(find.text('Cargando'), findsNothing);
    expect(runtime.metrics.memoryHits, hits);
    expect(runtime.metrics.signatures, 1);
    expect(runtime.metrics.downloads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final emptyWindow in [false, true]) {
    testWidgets(
      'pending preview promotes before window replacement; empty=$emptyWindow',
      (tester) async {
        final pending = (await tester.runAsync(
          () async =>
              (response: Completer<Uint8List>(), started: Completer<void>()),
        ))!;
        final response = pending.response;
        final started = pending.started;
        PhotoCancellation? cancellation;
        var currentSignatures = 0;
        final request = source(
          sign: () async {
            currentSignatures++;
            return 'https://example.test/current';
          },
        );
        final next = source(
          path: 'approved/next.jpg',
          sign: () => Completer<String>().future,
        );
        final runtime = await realRuntime(
          tester,
          MemoryPhotoStore(),
          download: (_, token) {
            cancellation = token;
            started.complete();
            return response.future;
          },
        );
        addTearDown(runtime.dispose);
        await tester.runAsync(() async {
          await tester.pumpWidget(
            view(runtime, request, preview: true, upcoming: [request]),
          );
          await started.future;
        });
        expect(runtime.metrics.downloads, 1);
        final originalState = tester.state(find.byKey(photoKey));
        await tester.runAsync(() async {
          await tester.pumpWidget(
            view(
              runtime,
              request,
              preview: false,
              upcoming: emptyWindow ? [] : [next],
            ),
          );
          expect(cancellation!.cancelled, isFalse);
          response.complete(photograph);
          await runtime.load(request, width: 128);
        });
        await tester.pump();
        expect(tester.state(find.byKey(photoKey)), same(originalState));
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        expect(runtime.metrics.downloads, 1);
        expect(currentSignatures, 1);
        expect(runtime.metrics.cancelled, 0);
        expect(cancellation!.cancelled, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
