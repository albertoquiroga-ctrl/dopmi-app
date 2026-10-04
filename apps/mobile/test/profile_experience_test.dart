import 'package:dopmi_mobile/core/navigation.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

import 'rescue_test.dart' show FakeRescue;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/experience_controller.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'fake_account_photo_repository.dart';

import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';

void main() {
  for (final mode in ['donor', 'rescuer']) {
    testWidgets(
      'settings has no selected tab and profile tap opens its real root: $mode',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        await identity.setExperience(mode);
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            accountPhotoRepositoryProvider.overrideWithValue(
              emptyAccountPhotoRepository(identity),
            ),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            routerInitialLocationProvider.overrideWithValue('/settings'),
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
        final bar = find.byType(DopmiBottomBar);
        final semantics = find.descendant(
          of: bar,
          matching: find.byType(Semantics),
        );
        expect(
          tester
              .widgetList<Semantics>(semantics)
              .where((node) => node.properties.selected == true),
          isEmpty,
        );
        final profile = find.descendant(
          of: bar,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Perfil',
          ),
        );
        await tester.tap(profile);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/profile');
        expect(
          tester
              .widgetList<Semantics>(
                find.descendant(
                  of: find.byType(DopmiBottomBar),
                  matching: find.byType(Semantics),
                ),
              )
              .where((node) => node.properties.selected == true)
              .map((node) => node.properties.label),
          ['Perfil'],
        );
        expect(identity.profile.name, 'Ana');
        expect(identity.profile.mode, mode);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final large in [false, true]) {
    testWidgets('profile settings return preserves the real profile: $large', (
      tester,
    ) async {
      tester.view.physicalSize = large
          ? const Size(320, 640)
          : const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true);
      await identity.saveProfile(name: 'Ana', phone: '', city: 'Monterrey');
      await identity.setExperience('rescuer');
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          accountPhotoRepositoryProvider.overrideWithValue(
            emptyAccountPhotoRepository(identity),
          ),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          routerInitialLocationProvider.overrideWithValue('/profile'),
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
      final access = find.text('Configuración');
      await tester.scrollUntilVisible(
        access,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(access);
      await tester.pumpAndSettle();
      final position = tester.getTopLeft(access);
      await tester.tap(access);
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/settings');
      expect(find.text('Estado de verificación'), findsOneWidget);
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/profile');
      expect(tester.getTopLeft(access), position);
      expect(identity.profile.name, 'Ana');
      expect(identity.profile.mode, 'rescuer');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('rescuer settings scrolls behind its fixed translucent header', (
    tester,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    await identity.setExperience('rescuer');
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(identity),
        ),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue('/settings'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    final header = find.byType(AppBar);
    final headerRect = tester.getRect(header);
    final appBar = tester.widget<AppBar>(header);
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.scrolledUnderElevation, 0);
    expect(
      find.descendant(of: header, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    final heading = find.text('Estado de verificación');
    final initialTop = tester.getTopLeft(heading).dy;
    expect(initialTop, closeTo(headerRect.bottom + 20, 1));
    await tester.drag(find.byType(ListView).first, const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(tester.getRect(header), headerRect);
    expect(tester.getTopLeft(heading).dy, lessThan(headerRect.bottom));
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    for (final path in ['/profile', '/settings']) {
      testWidgets(
        'rescuer source switch returns to donor only after server success: $fail $path',
        (tester) async {
          final identity = FakeIdentityRepository()
            ..user = const Identity('one', 'ana@example.test', verified: true);
          await identity.setExperience('rescuer');
          identity.failSave = fail;
          final container = ProviderContainer(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              accountPhotoRepositoryProvider.overrideWithValue(
                emptyAccountPhotoRepository(identity),
              ),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
              rescueRepositoryProvider.overrideWithValue(FakeRescue()),
              routerInitialLocationProvider.overrideWithValue(path),
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
          final target = find.byKey(const ValueKey('rescuer-donor-switch'));
          await tester.scrollUntilVisible(
            target,
            240,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(
            find.text(
              path == '/settings'
                  ? 'Cambiar a usuario donante'
                  : 'Modo donante',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              path == '/settings'
                  ? 'Cambia tu experiencia en la app'
                  : 'Adopta, apoya y sigue impacto',
            ),
            findsOneWidget,
          );
          expect(tester.getSize(target), const Size(32, 19));
          // Source profile switch is off; settings switch is on. Navigation
          // replaces the screen rather than toggling this thumb in place.
          final thumb = find.descendant(
            of: target,
            matching: find.byType(Transform),
          );
          expect(thumb, findsOneWidget);
          expect(
            tester.widget<Transform>(thumb).transform.entry(0, 3),
            path == '/settings' ? 13 : 0,
          );
          final touch = find.ancestor(
            of: target,
            matching: find.byType(InkWell),
          );
          expect(tester.getSize(touch), const Size(48, 48));
          // Tap beyond the visible 32px track, inside the 48px touch target.
          await tester.tapAt(tester.getCenter(target) + const Offset(20, 0));
          await tester.pumpAndSettle();
          expect(identity.profile.mode, fail ? 'rescuer' : 'donor');
          expect(identity.profile.name, 'Ana');
          expect(
            container.read(routerProvider).state.uri.path,
            fail ? path : '/adoptions',
          );
          if (fail) {
            expect(
              find.byKey(const ValueKey('rescuer-donor-switch')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final fail in [false, true]) {
    for (final path in ['/settings']) {
      testWidgets(
        'donor settings switch enters rescuer only after server success: $fail $path',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final identity = FakeIdentityRepository()
            ..user = const Identity('one', 'ana@example.test', verified: true);
          await identity.saveProfile(
            name: 'Ana',
            phone: '555',
            city: 'Monterrey',
          );
          identity.failSave = fail;
          final container = ProviderContainer(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              accountPhotoRepositoryProvider.overrideWithValue(
                emptyAccountPhotoRepository(identity),
              ),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
              rescueRepositoryProvider.overrideWithValue(FakeRescue()),
              routerInitialLocationProvider.overrideWithValue(path),
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
          final target = find.byKey(
            const ValueKey('donor-settings-mode-switch'),
          );
          await tester.scrollUntilVisible(
            target,
            240,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(find.text('Cambiar tipo de cuenta'), findsOneWidget);
          expect(find.text('Ir a cuenta Rescatista'), findsOneWidget);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(identity.profile.mode, fail ? 'donor' : 'rescuer');
          expect(identity.profile.name, 'Ana');
          expect(
            container.read(routerProvider).state.uri.path,
            fail ? path : '/rescuer',
          );
          if (fail) {
            expect(
              find.byKey(const ValueKey('donor-settings-mode-switch')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final reduced in [false, true]) {
    testWidgets(
      'profile feature press cancels safely; reduced motion=$reduced',
      (tester) async {
        var activations = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: DonorFeature(
                  title: 'Publica un caso de adopción',
                  subtitle: 'Tu perfil se conserva',
                  icon: Icons.add,
                  onPressed: () => activations++,
                ),
              ),
            ),
          ),
        );
        final feature = find.byType(DonorFeature);
        final gesture = await tester.startGesture(tester.getCenter(feature));
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          tester
              .widget<AnimatedScale>(
                find.descendant(
                  of: feature,
                  matching: find.byType(AnimatedScale),
                ),
              )
              .scale,
          .99,
        );
        expect(
          tester
              .widget<AnimatedScale>(
                find.descendant(
                  of: feature,
                  matching: find.byType(AnimatedScale),
                ),
              )
              .duration,
          reduced ? Duration.zero : const Duration(milliseconds: 120),
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(activations, 0);
        expect(
          tester
              .widget<AnimatedScale>(
                find.descendant(
                  of: feature,
                  matching: find.byType(AnimatedScale),
                ),
              )
              .scale,
          1,
        );
        await tester.tap(feature);
        await tester.pumpAndSettle();
        expect(activations, 1);
      },
    );
  }
  for (final fail in [false, true]) {
    testWidgets(
      'dedicated experience change preserves personal data; failure=$fail',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity('one', 'ana@example.test', verified: true)
          ..failSave = fail;
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            accountPhotoRepositoryProvider.overrideWithValue(
              emptyAccountPhotoRepository(identity),
            ),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            routerInitialLocationProvider.overrideWithValue('/profile'),
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
        expect(find.byType(TextFormField), findsNothing);
        final target = find.text('Publica un caso de adopción');
        await tester.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(target), alignment: .25);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(identity.profile.mode, 'donor');
        await tester.ensureVisible(find.text('Ahora no'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ahora no'));
        await tester.pumpAndSettle();
        expect(identity.profile.mode, 'donor');
        expect(container.read(routerProvider).state.uri.path, '/profile');
        await Scrollable.ensureVisible(tester.element(target), alignment: .25);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sí, cambiar a Rescatista'));
        await tester.tap(find.text('Sí, cambiar a Rescatista'));
        await tester.pumpAndSettle();
        expect(identity.profile.name, 'Ana');
        expect(identity.profile.phone, '');
        expect(identity.profile.mode, fail ? 'donor' : 'rescuer');
        expect(
          container.read(experienceProvider).value,
          fail ? AccountExperience.donor : AccountExperience.rescuer,
        );
        expect(
          container.read(routerProvider).state.uri.path,
          fail ? '/profile' : '/rescuer',
        );
        if (fail) {
          expect(
            find.text(
              'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.',
            ),
            findsOneWidget,
          );
        }
      },
    );
  }
  test(
    'editing personal data cannot reset a newer experience preference',
    () async {
      final repo = FakeIdentityRepository();
      await repo.setExperience('rescuer');
      await repo.saveProfile(
        name: 'Ana actualizada',
        phone: '',
        city: 'Monterrey',
      );
      expect(repo.profile.mode, 'rescuer');
    },
  );

  testWidgets('account preserves access to the dedicated saved rescuers view', (
    tester,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(identity),
        ),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        routerInitialLocationProvider.overrideWithValue('/basic-info'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rescatistas guardados'), findsNothing);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    final link = find.text('Rescatistas guardados');
    await tester.scrollUntilVisible(
      link,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(link), alignment: .25);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/saved?kind=rescuer',
    );
    expect(find.text('Rescatistas guardados'), findsOneWidget);
    expect(find.byTooltip('Tipos de guardados'), findsOneWidget);
    expect(
      find.text('Guarda perfiles desde el detalle de un caso.'),
      findsOneWidget,
    );
  });
}
