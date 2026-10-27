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
    const output = String.fromEnvironment(
      'CAPTURE_OUT',
      defaultValue: '../../.tools/design-review',
    );
    final out = Directory(output);
    await tester.runAsync(() => out.create(recursive: true));
    const filter = String.fromEnvironment('CAPTURE_FILTER');
    if (filter.startsWith('recovery20d21')) {
      try {
        await captureRecoveryDelta(tester, out, filter);
      } finally {
        debugDisableShadows = true;
      }
      return;
    }
    for (final large in [false, true]) {
      tester.view.physicalSize = large
          ? const Size(320, 640)
          : const Size(377, 852);
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      for (final route in [
        ('welcome', '/welcome'),
        ('onboarding', '/onboarding?intent=adopt'),
        ('onboarding-rescue', '/onboarding?intent=rescue'),
        ('start', '/start?intent=adopt'),
        ('login', '/login'),
        ('login-google', '/login'),
        ('signup', '/signup'),
        ('forgot', '/forgot'),
        ('reset', '/reset-password'),
        ('confirm', '/confirm'),
        ('confirm-recovery', '/confirm-recovery'),
      ]) {
        if (filter.isNotEmpty && !filter.split(',').contains(route.$1)) {
          continue;
        }
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
        await tester.runAsync(() async {
          for (final image in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(image.image, key.currentContext!);
          }
          await precacheImage(
            const AssetImage('assets/canvas-grain-f693.png'),
            key.currentContext!,
          );
        });
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
        if (route.$1 == 'welcome') {
          for (final choice in [
            ('adopt', 'Adoptar'),
            ('rescue', 'Dar en adopción'),
          ]) {
            await tester.ensureVisible(find.text(choice.$2).last);
            await tester.tap(find.text(choice.$2).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(
              () => saveCapture(
                key,
                '${out.path}/access-welcome-${choice.$1}${large ? '-large' : ''}.png',
              ),
            );
          }
        }
        if (route.$1.startsWith('onboarding')) {
          final next = find.widgetWithText(FilledButton, 'Continuar');
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            for (final image in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(image.image, key.currentContext!);
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(
            () => saveCapture(
              key,
              '${out.path}/access-${route.$1}-step2${large ? '-large' : ''}.png',
            ),
          );
        }
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
            'confirm' => 'Verificar código',
            'confirm-recovery' => 'Volver a iniciar sesión',
            _ => 'Enviar enlace',
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

Future<void> captureRecoveryDelta(
  WidgetTester tester,
  Directory out,
  String filter,
) async {
  final frames = <Map<String, Object>>[];
  var groups = 0;
  for (final intent in ['adopt', 'rescue']) {
    for (final variant in [
      ('normal', 1.0, const Size(377, 852)),
      ('115', 1.15, const Size(377, 852)),
      ('200', 2.0, const Size(320, 640)),
    ]) {
      final prefix = 'recovery20d21-$intent-${variant.$1}';
      if (!prefix.startsWith(filter) && !filter.startsWith(prefix)) continue;
      groups++;
      tester.view.physicalSize = variant.$3;
      tester.platformDispatcher.textScaleFactorTestValue = variant.$2;
      final identity = FakeIdentityRepository();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          configProvider.overrideWithValue(
            const AppConfig(url: '', key: '', redirect: ''),
          ),
          routerInitialLocationProvider.overrideWithValue(
            '/forgot?intent=$intent',
          ),
        ],
      );
      final key = GlobalKey();
      Future<void> capture(String state) async {
        expect(tester.takeException(), isNull, reason: '$prefix $state');
        final name = '$prefix-$state.png';
        if (!name.startsWith(filter)) return;
        await tester.runAsync(() => saveCapture(key, '${out.path}/$name'));
        frames.add({
          'file': name,
          'intent': intent,
          'scale': variant.$2,
          'width': variant.$3.width,
          'height': variant.$3.height,
          'state': state,
          'source': 'real Flutter widgets, synthetic repository',
        });
      }

      Future<void> reach(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(
          finder.hitTestable(),
          findsOneWidget,
          reason: '$prefix action must remain reachable',
        );
      }

      Future<void> top() async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
      }

      try {
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
        await capture('request');
        final send = find.widgetWithText(FilledButton, 'Enviar enlace');
        await reach(send);
        await capture('request-action');
        await reach(find.byType(TextFormField).first);
        await tester.enterText(
          find.byType(TextFormField).first,
          'qa@example.test',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await reach(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(identity.recoveryRequests, ['qa@example.test']);
        expect(find.byType(TextFormField), findsNothing);
        await capture('sent');
        final confirm = find.widgetWithText(
          TextButton,
          'Necesito confirmar mi correo',
        );
        await reach(confirm);
        await capture('sent-actions');
        final expand = find.widgetWithText(TextButton, 'Usar código');
        await reach(expand);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        await top();
        await capture('code');
        final verify = find.widgetWithText(FilledButton, 'Verificar código');
        await reach(verify);
        await capture('code-verify');
        await reach(confirm);
        await capture('code-actions');
        expect(identity.recoveryRequests, hasLength(1));
        expect(identity.codeRequests, 0);
        expect(identity.current, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await identity.changes.close();
      }
    }
  }
  expect(groups, greaterThan(0), reason: 'No recovery capture matched $filter');
  await tester.runAsync(
    () =>
        File('${out.path}/recovery20d21-manifest.json')
            .writeAsString(jsonEncode({'filter': filter, 'frames': frames})),
  );
}
