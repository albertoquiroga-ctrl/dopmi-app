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

void main() {
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
          await tester.tap(target);
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
    expect(find.text('Rescatistas'), findsOneWidget);
    expect(
      find.text('Guarda un perfil público para seguir su trabajo.'),
      findsOneWidget,
    );
  });
}
