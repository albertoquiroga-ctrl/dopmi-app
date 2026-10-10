import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dopmi_mobile/core/media/media_store.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_screen.dart';

import 'fake_identity_repository.dart';

final bytes = Uint8List.fromList(
  img.encodeJpg(img.Image(width: 16, height: 24)),
);
PhotoRef photo(String path) => PhotoRef(
  path: path,
  purpose: MediaPurpose.adoptionPhoto,
  sign: () async => 'https://example.test/$path',
);

Widget view(PhotoRuntime runtime, PhotoRef source, {bool active = true}) =>
    ProviderScope(
      overrides: [photoRuntimeProvider.overrideWithValue(runtime)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(devicePixelRatio: 1),
          child: child!,
        ),
        home: TickerMode(
          enabled: active,
          child: RemotePhoto(
            source: source,
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
    'confirmed account avatar retirement removes cached file and lease',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'one',
          'synthetic@example.test',
          verified: true,
        );
      addTearDown(identity.changes.close);
      String? path = 'one/one/73000000-0000-4000-8000-000000000001.jpg';
      var signatures = 0;
      final repository = AccountPhotoRepository(
        owner: () => identity.current?.id,
        rpc: (_, _) async => path == null ? null : {'photo_path': path},
        upload: (_, _) async => throw StateError('not an upload test'),
        sign: (_) async {
          signatures++;
          return 'https://example.test/avatar';
        },
      );
      final store = MemoryPhotoStore();
      final runtime = (await tester.runAsync(
        () async => PhotoRuntime(store: store, download: (_, _) async => bytes),
      ))!;
      addTearDown(runtime.dispose);
      final source = PhotoRef(
        path: path,
        purpose: MediaPurpose.accountAvatar,
        persistence: PhotoPersistence.ordinary,
        sign: () => repository.signedUrl(path!),
      );
      await tester.runAsync(() => runtime.load(source, width: 256));
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          accountPhotoRepositoryProvider.overrideWithValue(repository),
          photoRuntimeProvider.overrideWithValue(runtime),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BasicInfoScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.entries, hasLength(1));
      path = null;
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
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
      expect(find.byType(RemotePhoto), findsNothing);
      final before = signatures;
      // A fresh reference has to sign again; the old lease was removed too.
      await tester.runAsync(
        () => runtime.load(
          PhotoRef(
            path: source.path,
            purpose: MediaPurpose.accountAvatar,
            persistence: PhotoPersistence.ordinary,
            sign: () async {
              signatures++;
              return 'https://example.test/new-authorization';
            },
          ),
          width: 256,
        ),
      );
      expect(signatures, before + 1);
    },
  );
  testWidgets('actor change hides old pixels immediately while restoring', (
    tester,
  ) async {
    final runtime = (await tester.runAsync(
      () async => PhotoRuntime(
        store: MemoryPhotoStore(),
        download: (_, _) async => bytes,
      ),
    ))!;
    final source = photo('approved.jpg');
    await tester.runAsync(() => runtime.load(source, width: 128));
    await tester.runAsync(() => tester.pumpWidget(view(runtime, source)));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    runtime.scope('another-account', ready: false);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Cargando'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    runtime.dispose();
    await tester.pump();
  });

  testWidgets('late identity restoration restarts failed visible photo', (
    tester,
  ) async {
    var requests = 0;
    final runtime = (await tester.runAsync(
      () async => PhotoRuntime(
        store: MemoryPhotoStore(),
        ready: false,
        download: (_, _) async {
          requests++;
          return bytes;
        },
      ),
    ))!;
    final source = photo('approved.jpg');
    await tester.pumpWidget(view(runtime, source));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(requests, 0);
    await tester.runAsync(() async {
      runtime.scope('anonymous', ready: true);
      await runtime.load(source, width: 128);
    });
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    runtime.dispose();
  });

  testWidgets('cancelled signatures release both prefetch slots immediately', (
    tester,
  ) async {
    final runtime = PhotoRuntime(store: MemoryPhotoStore());
    final owner = Object();
    PhotoRef hanging(String path) => PhotoRef(
      path: path,
      purpose: MediaPurpose.adoptionPhoto,
      sign: () => Completer<String>().future,
    );
    runtime.prefetch(owner, [hanging('old1'), hanging('old2')]);
    await tester.pump();
    expect(runtime.metrics.signatures, 2);
    runtime.cancelPrefetch(owner);
    runtime.prefetch(owner, [hanging('new1'), hanging('new2')]);
    await tester.pump();
    expect(runtime.metrics.signatures, 4);
    runtime.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
}
