import 'dart:async';
import 'dart:io';

import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/media_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rescue_test.dart' show FakeRescue;

class PrivateFileRepo extends FakeRescue {
  final paths = <String>[];
  Future<String> Function()? read;
  @override
  Future<String> fileUrl(String path) {
    paths.add(path);
    return read?.call() ?? Future.value('https://fixture.invalid/first.png');
  }
}

PhotoRef source(PrivateFileRepo repo) => PhotoRef(
  path: 'one/request/file.png',
  purpose: MediaPurpose.rescuePhoto,
  sign: () => repo.fileUrl('one/request/file.png'),
);

void main() {
  for (final large in [false, true]) {
    Future<void> mount(
      WidgetTester tester,
      PrivateFileRepo repo, {
      PhotoRuntime? runtime,
      String path = 'one/request/file.png',
    }) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rescueRepositoryProvider.overrideWithValue(repo),
              if (runtime != null)
                photoRuntimeProvider.overrideWithValue(runtime),
            ],
            child: MaterialApp(
              theme: dopmiTheme(),
              home: RescueFileScreen(path),
            ),
          ),
        );
        if (runtime != null && repo.read == null) {
          try {
            await runtime.load(source(repo), width: 384);
          } catch (_) {}
        }
      });
      await tester.pumpAndSettle();
      final reload = find.text('Recargar archivo');
      await tester.scrollUntilVisible(
        reload,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(reload);
      await tester.pumpAndSettle();
    }

    Future<void> reload(WidgetTester tester) async {
      final button = find.text('Recargar archivo');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
    }

    testWidgets(
      'reload hides prior private image while access is pending: $large',
      (tester) async {
        final repo = PrivateFileRepo();
        final bytes = (await tester.runAsync(
          () => File('tool/fixtures/rocky.png').readAsBytes(),
        ))!;
        final runtime = (await tester.runAsync(
          () async => PhotoRuntime(
            store: MemoryPhotoStore(),
            download: (_, _) async => bytes,
          ),
        ))!;
        addTearDown(runtime.dispose);
        await mount(tester, repo, runtime: runtime);
        final image = find.byWidgetPredicate(
          (widget) => widget is RawImage && widget.image != null,
        );
        expect(image, findsOneWidget);
        final pending = Completer<String>();
        repo.read = () => pending.future;
        await reload(tester);
        expect(repo.paths, ['one/request/file.png', 'one/request/file.png']);
        expect(image, findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
        pending.completeError(
          const StorageException('Acceso revocado.', statusCode: '403'),
        );
        await tester.pumpAndSettle();
        expect(image, findsNothing);
        expect(
          find.text(
            rescueError(
              const StorageException('Acceso revocado.', statusCode: '403'),
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'synchronous read failure can retry with a new signed URL: $large',
      (tester) async {
        final repo = PrivateFileRepo()
          ..read = () =>
              throw const StorageException('No disponible.', statusCode: '403');
        final bytes = (await tester.runAsync(
          () => File('tool/fixtures/rocky.png').readAsBytes(),
        ))!;
        final runtime = (await tester.runAsync(
          () async => PhotoRuntime(
            store: MemoryPhotoStore(),
            download: (_, _) async => bytes,
          ),
        ))!;
        addTearDown(runtime.dispose);
        await mount(tester, repo, runtime: runtime);
        expect(
          find.text(
            rescueError(
              const StorageException('No disponible.', statusCode: '403'),
            ),
          ),
          findsOneWidget,
        );
        repo.read = () => Future.value('https://fixture.invalid/fresh.png');
        await tester.runAsync(() async {
          await reload(tester);
          await runtime.load(source(repo), width: 384);
        });
        await tester.pumpAndSettle();
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        expect(runtime.metrics.downloads, 1);
        expect(repo.paths, ['one/request/file.png', 'one/request/file.png']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'opening PDF rechecks access and launches the fresh URL: $large',
      (tester) async {
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        final calls = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final repo = PrivateFileRepo();
        await mount(tester, repo, path: 'one/request/file.pdf');
        repo.read = () => Future.value('https://fixture.invalid/fresh.pdf');
        final button = find.text('Abrir PDF');
        await tester.scrollUntilVisible(
          button,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.paths, ['one/request/file.pdf', 'one/request/file.pdf']);
        expect(calls.where((call) => call.method == 'launch'), hasLength(1));
        expect(
          (calls.single.arguments as Map)['url'],
          'https://fixture.invalid/fresh.pdf',
        );
        expect(repo.saveCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
