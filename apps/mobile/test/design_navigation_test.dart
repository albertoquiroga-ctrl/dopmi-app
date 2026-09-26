import 'dart:ui' show SemanticsAction;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/navigation.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/experience_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

void main() {
  testWidgets(
    'restoring a rescuer opens their home without changing permissions',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true)
        ..profile = const Profile(
          id: 'one',
          name: 'Ana',
          phone: '',
          city: '',
          mode: 'rescuer',
          intent: 'rescue',
          status: 'active',
          termsVersion: developmentTermsVersion,
        );
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
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
      expect(container.read(routerProvider).state.uri.path, '/rescuer');
      expect(find.text('Casos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final intent in ['adopt', 'donate', 'rescue']) {
    testWidgets(
      'onboarding $intent preserves intent and back navigation with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final identity = FakeIdentityRepository();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            routerInitialLocationProvider.overrideWithValue(
              '/onboarding?intent=$intent',
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
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        final next = find.widgetWithText(FilledButton, 'Continuar');
        final finish = find.widgetWithText(
          FilledButton,
          intent == 'adopt'
              ? 'Quiero adoptar'
              : intent == 'donate'
              ? 'Quiero ayudar'
              : 'Empezar',
        );
        await tap(next);
        expect(finish, findsOneWidget);
        await tap(find.byTooltip('Volver'));
        expect(next, findsOneWidget);
        await tap(next);
        await tap(finish);
        await tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        final uri = container.read(routerProvider).state.uri;
        expect(uri.path, '/signup');
        expect(uri.queryParameters['intent'], intent);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'switching tabs preserves an unsaved profile and signing out removes it',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true);
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
      for (
        var attempt = 0;
        attempt < 8 && find.byType(TextFormField).evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byType(TextFormField).first,
        'Borrador privado',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Adoptar').last);
      await tester.pumpAndSettle();
      expect(find.text('Apoyar'), findsOneWidget);
      await tester.tap(find.text('Perfil').last);
      await tester.pumpAndSettle();
      expect(find.text('Borrador privado'), findsOneWidget);
      identity.profile = const Profile(
        id: 'two',
        name: 'Bea',
        phone: '',
        city: '',
        mode: 'donor',
        intent: 'adopt',
        status: 'active',
        termsVersion: developmentTermsVersion,
      );
      identity.emit(
        const IdentityEvent(
          Identity('two', 'bea@example.test', verified: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Borrador privado', skipOffstage: false), findsNothing);
      container.read(routerProvider).go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Bea'), findsWidgets);
      await container.read(identityControllerProvider).logout();
      await tester.pumpAndSettle();
      expect(find.text('Borrador privado', skipOffstage: false), findsNothing);
      expect(container.read(experienceProvider).value, AccountExperience.donor);
    },
  );

  for (final rescuer in [false, true]) {
    testWidgets(
      'navigation remains usable at 320px and 200% text, rescuer=$rescuer',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? selected;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: dopmiTheme(rescuer: rescuer),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                bottomNavigationBar: DopmiBottomBar(
                  rescuer: rescuer,
                  selectedPath: '/profile',
                  onSelected: (item) => selected = item.path,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(rescuer ? 'Casos' : 'Apoyar'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(rescuer ? 'Casos' : 'Apoyar'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        await tester.tap(find.text(rescuer ? 'Casos' : 'Apoyar'));
        expect(selected, rescuer ? '/my-cases' : '/rescue-cases');
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
