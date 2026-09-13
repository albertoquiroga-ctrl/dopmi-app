import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';

import 'fake_identity_repository.dart';

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    FakeIdentityRepository repo,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [identityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(() async {
      container.dispose();
      await repo.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target.last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'onboarding passes the rescuer intent and registration requires consent',
    (tester) async {
      final repo = FakeIdentityRepository();
      await start(tester, repo);
      await tap(tester, 'Soy rescatista');
      await tap(tester, 'Comenzar');
      await tap(tester, 'Crear mi cuenta');
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ana@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1234');
      await tester.enterText(find.byType(TextFormField).at(4), 'Password1234');
      await tap(tester, 'Crear cuenta');
      expect(repo.signupCount, 0);
      await tap(tester, 'Leí y acepto el aviso de desarrollo.');
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
    expect(find.text('Una nueva historia\nempieza contigo.'), findsOneWidget);
    expect(find.text('Ana editada'), findsNothing);
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
    expect(find.text('Una nueva historia\nempieza contigo.'), findsOneWidget);
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
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
