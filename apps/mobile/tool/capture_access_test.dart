import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/fake_identity_repository.dart';
import 'capture_design_test.dart' show saveCapture;

void main() {
  testWidgets('capture actual access routes at normal and enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final family in ['Inter', 'Fraunces']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await tester.runAsync(loader.load);
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    final out = Directory('../../.tools/design-review');
    await tester.runAsync(() => out.create(recursive: true));
    for (final large in [false, true]) {
      tester.view.physicalSize = large
          ? const Size(320, 640)
          : const Size(377, 852);
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      for (final route in [
        ('welcome', '/welcome'),
        ('onboarding', '/onboarding?intent=adopt'),
        ('start', '/start?intent=adopt'),
        ('login', '/login'),
        ('login-google', '/login'),
        ('signup', '/signup'),
        ('forgot', '/forgot'),
      ]) {
        final identity = FakeIdentityRepository();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            configProvider.overrideWithValue(
              AppConfig(
                url: '',
                key: '',
                redirect: '',
                googleEnabled: route.$1 == 'login-google',
              ),
            ),
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
        expect(
          tester.takeException(),
          isNull,
          reason: '${route.$1} large=$large',
        );
        await tester.runAsync(
          () => saveCapture(
            key,
            '${out.path}/access-${route.$1}${large ? '-large' : ''}.png',
          ),
        );
        if (large &&
            ['login', 'login-google', 'signup', 'forgot'].contains(route.$1)) {
          final label = switch (route.$1) {
            'login' || 'login-google' => 'Inicia sesión',
            'signup' => 'Crea una cuenta',
            _ => 'Enviar instrucciones',
          };
          final submit = find.widgetWithText(FilledButton, label);
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.runAsync(
            () => saveCapture(
              key,
              '${out.path}/access-${route.$1}-footer-large.png',
            ),
          );
        }
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await identity.changes.close();
      }
    }
    debugDisableShadows = true;
  });
}
