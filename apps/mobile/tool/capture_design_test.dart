import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/identity/onboarding_screen.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../test/fake_identity_repository.dart';
import '../test/community_test.dart' show FakeCommunity;

import 'design_gallery.dart';

void main() {
  testWidgets('capture actual Flutter components for visual review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final family in ['Inter', 'Fraunces']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await tester.runAsync(loader.load);
    }
    final output = Directory('../../.tools/design-review');
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    await tester.runAsync(() => output.create(recursive: true));
    for (final specification in [
      ('donor', false, const Size(377, 852), 1.0),
      ('rescuer', true, const Size(377, 852), 1.0),
      ('small-large-text', false, const Size(320, 640), 2.0),
    ]) {
      tester.view.physicalSize = specification.$3;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dopmiTheme(rescuer: specification.$2),
            home: MediaQuery(
              data: MediaQueryData(
                size: specification.$3,
                textScaler: TextScaler.linear(specification.$4),
              ),
              child: DesignGallery(rescuer: specification.$2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/dopmi-wordmark.png'),
          key.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${output.path}/${specification.$1}.png'),
      );
    }
    tester.view.physicalSize = const Size(377, 852);
    final welcomeKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: welcomeKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dopmiTheme(),
          home: const WelcomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => saveCapture(welcomeKey, '${output.path}/welcome.png'),
    );
    await tester.tap(find.text('Adoptar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => saveCapture(welcomeKey, '${output.path}/welcome-selected.png'),
    );
    for (final route in [
      ('login', '/login'),
      ('signup', '/signup'),
      ('forgot', '/forgot'),
      ('confirm', '/confirm'),
      ('start', '/start?intent=adopt'),
      ('onboarding-adopt', '/onboarding?intent=adopt'),
      ('onboarding-donate', '/onboarding?intent=donate'),
      ('onboarding-rescue', '/onboarding?intent=rescue'),
    ]) {
      final repo = FakeIdentityRepository();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          routerInitialLocationProvider.overrideWithValue(route.$2),
        ],
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final asset in [
        'assets/dopmi-wordmark.png',
        'assets/onboarding/luna-card.png',
        'assets/onboarding/luna-detail.png',
        'assets/onboarding/nina-card.png',
      ]) {
        await tester.runAsync(
          () => precacheImage(AssetImage(asset), key.currentContext!),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${output.path}/${route.$1}.png'),
      );
      if (route.$1.startsWith('onboarding')) {
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Continuar'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => saveCapture(key, '${output.path}/${route.$1}-2.png'),
        );
      }
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await repo.changes.close();
    }
    debugDisableShadows = true;
  });
}

Future<void> saveCapture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}
