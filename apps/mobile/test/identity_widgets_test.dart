import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    FakeIdentityRepository repo, {
    String? initialLocation,
    AppConfig? config,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(repo),
        if (config != null) configProvider.overrideWithValue(config),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        routerInitialLocationProvider.overrideWithValue(
          initialLocation ??
              (repo.user?.verified == true ? '/basic-info' : '/welcome'),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repo.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    Finder target() {
      final filled = find.widgetWithText(FilledButton, label);
      final outlined = find.widgetWithText(OutlinedButton, label);
      final textButton = find.widgetWithText(TextButton, label);
      if (filled.evaluate().isNotEmpty) return filled;
      if (outlined.evaluate().isNotEmpty) return outlined;
      if (textButton.evaluate().isNotEmpty) return textButton;
      return find.text(label);
    }

    for (
      var attempt = 0;
      attempt < 12 && target().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();
    }

    expect(target(), findsWidgets, reason: 'Could not find "$label"');
    await tester.ensureVisible(target().last);
    await tester.pumpAndSettle();
    await tester.tap(target().last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'onboarding passes the rescuer intent and registration requires consent',
    (tester) async {
      final repo = FakeIdentityRepository();
      await start(tester, repo);
      await tap(tester, 'Dar en adopción');
      await tap(tester, 'Continuar');
      await tap(tester, 'Continuar');
      await tap(tester, 'Empezar');
      await tap(tester, 'Crea una cuenta');
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ana@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1234');
      await tester.enterText(find.byType(TextFormField).at(4), 'Password1234');
      await tap(tester, 'Crear cuenta');
      expect(repo.signupCount, 0);
      await tap(
        tester,
        'Confirmo que tengo 18 años o más y acepto los Términos y el Aviso de privacidad.',
      );
      await tap(tester, 'Crear cuenta');
      expect(repo.signupCount, 1);
      expect(repo.signupIntent, 'rescue');
      expect(find.text('Revisa tu correo.'), findsOneWidget);
    },
  );
  testWidgets('a failed profile update keeps edits so the user can retry', (
    tester,
  ) async {
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true)
      ..failSave = true;
    await start(tester, repo);
    await tester.enterText(find.byType(TextFormField).first, 'Ana editada');
    await tap(tester, 'Guardar cambios');
    expect(find.text('Ana editada'), findsOneWidget);
    expect(
      find.text(
        'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    repo.failSave = false;
    await tap(tester, 'Guardar cambios');
    expect(repo.profile.name, 'Ana editada');
    expect(find.text('Guardamos los cambios de tu perfil.'), findsOneWidget);
    await tap(tester, 'Cerrar sesión');
    expect(find.text('Bienvenido a DopMi'), findsOneWidget);
    expect(find.text('Ana editada'), findsNothing);
  });
  testWidgets('settings opens basic info without a rendering exception', (
    tester,
  ) async {
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    await start(tester, repo, initialLocation: '/settings');

    expect(find.text('Términos y privacidad'), findsOneWidget);
    expect(find.text('Aviso de desarrollo'), findsNothing);
    await tap(tester, 'Información básica');
    expect(find.text('Mis datos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy route exposes account deletion', (tester) async {
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    await start(tester, repo, initialLocation: '/account-privacy');

    expect(find.text('Privacidad y cuenta'), findsOneWidget);
    for (
      var attempt = 0;
      attempt < 8 && find.text('Eliminar mi cuenta').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();
    }
    expect(find.text('Eliminar mi cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an outdated social profile must accept age and current terms', (
    tester,
  ) async {
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true)
      ..profile = const Profile(
        id: 'one',
        name: 'Ana',
        phone: '',
        city: '',
        mode: 'donor',
        intent: 'adopt',
        status: 'active',
        termsVersion: developmentTermsVersion,
      );
    await start(tester, repo, initialLocation: '/adoptions');

    expect(find.text('Antes de continuar'), findsOneWidget);
    expect(find.bySemanticsLabel('Adoptar'), findsNothing);
    await tap(
      tester,
      'Confirmo que tengo 18 años o más y acepto los términos y el aviso de privacidad.',
    );
    await tap(tester, 'Confirmar y continuar');
    expect(repo.consentCount, 1);
    expect(find.text('Antes de continuar'), findsNothing);
  });

  testWidgets('restoring accepted consent never flashes the consent screen', (
    tester,
  ) async {
    final profile = Completer<Profile>();
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true)
      ..profileResult = profile.future;

    await start(tester, repo, initialLocation: '/adoptions', settle: false);
    await tester.pump();

    expect(find.text('Antes de continuar'), findsNothing);
    expect(find.bySemanticsLabel('Restaurando sesión'), findsOneWidget);

    profile.complete(repo.profile);
    await tester.pumpAndSettle();

    expect(find.text('Antes de continuar'), findsNothing);
    expect(find.bySemanticsLabel('Adoptar'), findsOneWidget);
  });

  testWidgets('profile load failure cannot bypass legal consent', (
    tester,
  ) async {
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true)
      ..failLoad = true;
    final container = await start(tester, repo, initialLocation: '/basic-info');

    expect(find.text('Antes de continuar'), findsOneWidget);
    expect(find.text('Mis datos'), findsNothing);
    await tap(tester, 'Privacidad y eliminación de cuenta');
    expect(container.read(routerProvider).state.uri.path, '/account-privacy');
  });

  testWidgets('signup exposes Google as an account creation method', (
    tester,
  ) async {
    final repo = FakeIdentityRepository();
    await start(
      tester,
      repo,
      initialLocation: '/signup',
      config: const AppConfig(
        url: 'https://example.supabase.co',
        key: 'test',
        redirect: 'io.dopmi.app://auth/callback',
        googleEnabled: true,
      ),
    );

    expect(find.text('Crear cuenta con Google'), findsOneWidget);
  });
  testWidgets('a recovery link routes to reset without loading personal data', (
    tester,
  ) async {
    final repo = FakeIdentityRepository();
    await start(tester, repo);
    repo.emit(
      const IdentityEvent(
        Identity('one', 'ana@example.test', verified: true),
        recovery: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Una nueva\ncontraseña.'), findsOneWidget);
    expect(repo.loads, 0);
    await tap(tester, 'Cancelar y cerrar sesión');
    expect(find.text('Bienvenido a DopMi'), findsOneWidget);
  });
  testWidgets('password recovery ends at login with a success message', (
    tester,
  ) async {
    final repo = FakeIdentityRepository();
    await start(tester, repo);
    repo.emit(
      const IdentityEvent(
        Identity('one', 'ana@example.test', verified: true),
        recovery: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'NewPassword1234');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPassword1234');
    await tap(tester, 'Actualizar contraseña');
    expect(repo.passwordUpdates, 1);
    expect(
      find.text('Tu contraseña se actualizó. Inicia sesión con la nueva.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
  });
}
