import 'dart:async';

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

void main() {
  for (final large in [false, true]) {
    Future<void> mount(
      WidgetTester tester,
      PrivateFileRepo repo, {
      String path = 'one/request/file.png',
    }) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rescueRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(theme: dopmiTheme(), home: RescueFileScreen(path)),
        ),
      );
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
        await mount(tester, repo);
        final image = find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is NetworkImage,
        );
        expect(image, findsOneWidget);
        final pending = Completer<String>();
        repo.read = () => pending.future;
        await reload(tester);
        expect(repo.paths, ['one/request/file.png', 'one/request/file.png']);
        expect(image, findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
        pending.completeError(const FormatException('Acceso revocado.'));
        await tester.pumpAndSettle();
        expect(image, findsNothing);
        expect(find.text('Acceso revocado.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'synchronous read failure can retry with a new signed URL: $large',
      (tester) async {
        final repo = PrivateFileRepo()
          ..read = () => throw const FormatException('No disponible.');
        await mount(tester, repo);
        expect(find.text('No disponible.'), findsOneWidget);
        repo.read = () => Future.value('https://fixture.invalid/fresh.png');
        await reload(tester);
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(
          find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is NetworkImage,
          ),
        );
        expect(
          (image.image as NetworkImage).url,
          'https://fixture.invalid/fresh.png',
        );
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
