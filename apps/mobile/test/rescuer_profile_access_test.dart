import 'package:dopmi_mobile/features/profile/rescuer_settings_details.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';

import 'rescuer_profile_test.dart' show FakeRescuerProfile;

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

import 'rescue_test.dart' show FakeRescue;

import 'package:dopmi_mobile/app.dart';
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
      final expected = {
        'Configurar pagos con Stripe': '/connect',
        'Editar perfil público': '/rescuer/profile/edit',
        'Ver mi perfil público': '/people/one',
        'Mis publicaciones de adopción': '/my-adoptions',
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
            matching: entry.value == '/connect'
                ? find.byType(SettingsDataRow)
                : find.byType(ProfileRow),
          ),
        );
        expect(
          row is ProfileRow ? row.path : (row as SettingsDataRow).path,
          entry.value,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
