import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';

import 'rescuer_profile_test.dart' show FakeRescuerProfile;

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

import 'rescue_test.dart' show FakeRescue;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/profile/help_center_screen.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

void main() {
  testWidgets('navigation hover is immediate and keyboard focus opens help', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: RescuerNavigationRow(
                  title: 'Centro de ayuda',
                  icon: 'icon-help',
                  path: '/help',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/help',
          builder: (_, _) => const Scaffold(body: Text('Help destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    Color borderColor() =>
        ((tester
                            .widget<Container>(
                              find.byKey(
                                const ValueKey('rescuer-navigation-card'),
                              ),
                            )
                            .decoration
                        as BoxDecoration)
                    .border
                as Border)
            .top
            .color;
    expect(borderColor(), const Color(0xffe3e4ed));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Centro de ayuda')));
    await tester.pump();
    expect(borderColor(), const Color(0xffd8d2ca));
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(borderColor(), const Color(0xffe3e4ed));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('rescuer-navigation-focus')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Help destination'), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  for (final item in [
    ('Configuración', '/settings'),
    ('Mis casos', '/my-cases'),
    ('Mensajes', '/messages'),
    ('Centro de ayuda', '/help'),
  ]) {
    testWidgets('profile access dispatches ${item.$2} at 320px and 200%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: RescuerProfileAccess()),
            ),
          ),
          for (final path in ['/settings', '/my-cases', '/messages', '/help'])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text('Opened $path')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(item.$1));
      await tester.tap(find.text(item.$1));
      await tester.pumpAndSettle();
      expect(find.text('Opened ${item.$2}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'rescuer configuration keeps public profile publications and Connect destinations',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await identity.setExperience('rescuer');
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          routerInitialLocationProvider.overrideWithValue('/settings'),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          rescuerProfileRepositoryProvider.overrideWithValue(
            FakeRescuerProfile()..value['owner_id'] = 'one',
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Estado de verificación'), findsOneWidget);
      expect(find.text('Cuenta verificada'), findsOneWidget);
      expect(find.text('Información básica'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Cuenta y privacidad'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Cuenta y privacidad')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta y privacidad'));
      await tester.pumpAndSettle();
      expect(find.byType(RescuerAccountOptionsScreen), findsOneWidget);
      final expected = {
        'Editar perfil público': '/rescuer/profile/edit',
        'Ver mi perfil público': '/people/one',
        'Mis publicaciones de adopción': '/my-adoptions',
        'Información básica': '/basic-info',
        'Historial de aportaciones': '/payments',
        'Términos y privacidad': '/terms',
        'Privacidad y eliminación': '/account-privacy',
        'Configurar pagos con Stripe': '/connect',
      };
      for (final entry in expected.entries) {
        await tester.scrollUntilVisible(
          find.text(entry.key),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final row = tester.widget(
          find.ancestor(
            of: find.text(entry.key),
            matching: find.byType(ProfileRow),
          ),
        );
        expect((row as ProfileRow).path, entry.value);
      }
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();
      final help = find.text('Centro de ayuda');
      await tester.scrollUntilVisible(
        help,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(help), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.byType(HelpCenterScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
