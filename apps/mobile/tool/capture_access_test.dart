import 'dart:io';
import 'dart:convert';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
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
        ('reset', '/reset-password'),
        ('confirm', '/confirm'),
        ('confirm-recovery', '/confirm-recovery'),
      ]) {
        final identity = FakeIdentityRepository();
        if (route.$1 == 'reset') {
          identity.user = const Identity(
            'one',
            'qa@example.test',
            verified: true,
          );
          identity.pending = true;
        }
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
        if (!large && route.$1 == 'login-google') {
          final fields = find.byType(TextFormField);
          final targets = {
            'sheet': find.byKey(const ValueKey('auth-form-sheet')),
            'title': find.text('Inicia sesión').first,
            'email': find.descendant(
              of: fields.first,
              matching: find.byType(InputDecorator),
            ),
            'password': find.descendant(
              of: fields.last,
              matching: find.byType(InputDecorator),
            ),
            'forgot': find.widgetWithText(TextButton, 'Olvidé mi contraseña'),
            'forgot_label': find.text('Olvidé mi contraseña'),
            'submit': find.widgetWithText(FilledButton, 'Inicia sesión'),
            'footer': find.byKey(const ValueKey('auth-switch-footer')),
          };
          // Source runtime567 at377x852 after fonts.ready.
          expect(
            tester.getRect(targets['email']!).top,
            closeTo(445.96875, .25),
          );
          expect(
            tester.getRect(targets['password']!).top,
            closeTo(529.96875, .25),
          );
          expect(
            tester.getRect(targets['submit']!).top,
            closeTo(617.96875, .25),
          );
          expect(tester.getSize(targets['forgot']!).height, 40);
          expect(
            tester.getRect(targets['title']!).top,
            closeTo(325.78125, .25),
          );
          final metrics = <String, dynamic>{};
          for (final item in targets.entries) {
            final rect = tester.getRect(item.value);
            metrics[item.key] = {
              'x': rect.left,
              'y': rect.top,
              'w': rect.width,
              'h': rect.height,
            };
          }
          await tester.runAsync(
            () =>
                File('${out.path}/access-login-google-metrics.json')
                    .writeAsString(jsonEncode(metrics)),
          );
        }
        if (large &&
            [
              'login',
              'login-google',
              'signup',
              'forgot',
              'reset',
              'confirm',
              'confirm-recovery',
            ].contains(route.$1)) {
          final label = switch (route.$1) {
            'login' || 'login-google' => 'Inicia sesión',
            'signup' => 'Crea una cuenta',
            'reset' => 'Actualizar contraseña',
            'confirm' || 'confirm-recovery' => 'Verificar código',
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
