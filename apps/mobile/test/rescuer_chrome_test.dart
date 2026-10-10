import 'package:dopmi_mobile/features/communication/notification_frame.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/help_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_identity_repository.dart';

void main() {
  for (final systemBack in [false, true]) {
    testWidgets(
      'direct rescuer notifications return to inbox; Android=$systemBack',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/notifications',
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, _) =>
                  const NotificationFrame(rescuer: true, children: []),
            ),
            GoRoute(
              path: '/messages',
              builder: (_, _) => const Scaffold(body: Text('Inbox real')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Regresar'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Inbox real'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'notifications pushed from another screen return to their caller',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/caller',
        routes: [
          GoRoute(
            path: '/caller',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/notifications'),
                child: const Text('Abrir notificaciones'),
              ),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) =>
                const NotificationFrame(rescuer: true, children: []),
          ),
          GoRoute(
            path: '/messages',
            builder: (_, _) =>
                const Scaffold(body: Text('Fallback incorrecto')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Abrir notificaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir notificaciones'), findsOneWidget);
      expect(find.text('Fallback incorrecto'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'rescuer help uses purple selection and actual settings fallback; scale=$scale Android=$systemBack',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final identity = FakeIdentityRepository()
            ..user = const Identity(
              'one',
              'fixture@example.test',
              verified: true,
            );
          await identity.setExperience('rescuer');
          final container = ProviderContainer(
            overrides: [identityRepositoryProvider.overrideWithValue(identity)],
          );
          final router = GoRouter(
            initialLocation: '/help',
            routes: [
              GoRoute(
                path: '/help',
                builder: (_, _) => const HelpCenterScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, _) =>
                    const Scaffold(body: Text('Configuración real')),
              ),
            ],
          );
          addTearDown(() async {
            router.dispose();
            container.dispose();
            await identity.changes.close();
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();
          final topic = find.widgetWithText(OutlinedButton, 'Verificación');
          await tester.scrollUntilVisible(
            topic,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(topic);
          await tester.pumpAndSettle();
          await tester.tap(topic);
          await tester.pumpAndSettle();
          final selected = tester.widget<OutlinedButton>(topic);
          expect(
            selected.style!.backgroundColor!.resolve({}),
            const Color(0xfff3eefe),
          );
          expect(
            selected.style!.foregroundColor!.resolve({}),
            const Color(0xff7841f2),
          );
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Volver'));
          }
          await tester.pumpAndSettle();
          expect(find.text('Configuración real'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
