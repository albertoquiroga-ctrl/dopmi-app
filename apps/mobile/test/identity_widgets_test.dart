import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:dopmi_mobile/features/identity/privacy_notice_screen.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'fake_account_photo_repository.dart';

import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';

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
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(repo),
        ),
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

  for (final route in ['/login', '/signup']) {
    testWidgets('reference auth $route retains private password fields', (
      tester,
    ) async {
      final repo = FakeIdentityRepository();
      await start(tester, repo, initialLocation: route);
      final fields = find.byType(TextFormField);
      final passwordIndex = route == '/login' ? 1 : 3;
      await tester.enterText(fields.at(passwordIndex), 'Password1234');
      final password = tester.widget<TextField>(
        find.descendant(
          of: fields.at(passwordIndex),
          matching: find.byType(TextField),
        ),
      );
      expect(password.obscureText, isTrue);
      expect(password.controller!.text, 'Password1234');
      expect(password.autocorrect, isFalse);
      expect(password.enableSuggestions, isFalse);
      expect(
        password.autofillHints,
        contains(
          route == '/login'
              ? AutofillHints.password
              : AutofillHints.newPassword,
        ),
      );
      expect(find.byTooltip('Mostrar contraseña'), findsNothing);
      if (route == '/signup') {
        await tester.enterText(fields.at(4), 'Password1234');
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: fields.at(4),
                  matching: find.byType(TextField),
                ),
              )
              .obscureText,
          isTrue,
        );
        expect(find.byTooltip('Mostrar confirmar contraseña'), findsNothing);
      }
      expect(repo.signupCount, 0);
    });
  }

  testWidgets('signup consent target and legal reading preserve draft', (
    tester,
  ) async {
    final repo = FakeIdentityRepository();
    final semantics = tester.ensureSemantics();
    try {
      await start(tester, repo, initialLocation: '/signup?intent=rescue');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ana@example.test',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final row = find.byType(AuthConsentRow);
      await tester.ensureVisible(row);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.tapAt(tester.getRect(row).topLeft + const Offset(2, 3));
      await tester.pumpAndSettle();
      expect(tester.widget<AuthConsentRow>(row).value, isTrue);
      expect(find.bySemanticsLabel('Términos y Condiciones'), findsOneWidget);
      expect(find.bySemanticsLabel('Aviso de Privacidad'), findsOneWidget);
      await tap(tester, 'Términos y Condiciones');
      expect(find.byType(TermsScreen), findsOneWidget);
      expect(repo.signupCount, 0);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(tester.widget<AuthConsentRow>(row).value, isTrue);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'ana@example.test',
      );
      await tester.ensureVisible(row);
      await tester.tapAt(tester.getRect(row).topLeft + const Offset(2, 3));
      await tester.pumpAndSettle();
      expect(tester.widget<AuthConsentRow>(row).value, isFalse);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Crea una cuenta'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.signupCount, 0);
      await tap(tester, 'Aviso de Privacidad');
      expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
      expect(find.byType(TermsScreen), findsNothing);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(tester.widget<AuthConsentRow>(row).value, isFalse);
      expect(repo.signupCount, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('enlarged legal reading returns to the unchanged signup draft', (
    tester,
  ) async {
    final repo = FakeIdentityRepository();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester, repo, initialLocation: '/signup?intent=rescue');
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'ana@example.test',
    );
    await tap(tester, 'Aviso de Privacidad');
    expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Entendido').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AuthConsentRow>(find.byType(AuthConsentRow)).value,
      isFalse,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'ana@example.test',
    );
    expect(repo.signupCount, 0);
    expect(tester.takeException(), isNull);
  });

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
      final signupButton = find.widgetWithText(FilledButton, 'Crea una cuenta');
      expect(tester.widget<FilledButton>(signupButton).onPressed, isNull);
      await tap(tester, 'Crea una cuenta');
      expect(repo.signupCount, 0);
      final consent = find.byType(AuthConsentRow);
      await tester.ensureVisible(consent);
      await tester.tapAt(tester.getRect(consent).topLeft + const Offset(2, 3));
      await tester.pumpAndSettle();
      await tap(tester, 'Crea una cuenta');
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
    expect(find.text('Cambios guardados'), findsOneWidget);
    expect(find.byType(Notice), findsNothing);
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('Cambios guardados'), findsNothing);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tap(tester, 'Cerrar sesión');
    expect(find.text('Bienvenido a DopMi'), findsOneWidget);
    expect(find.text('Ana editada'), findsNothing);
  });
  testWidgets(
    'suspended basic info stays read-only without querying guarded private name parts',
    (tester) async {
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true)
        ..profile = const Profile(
          id: 'one',
          name: 'Ana María López',
          phone: '',
          city: '',
          mode: 'donor',
          intent: 'adopt',
          status: 'suspended',
          termsVersion: currentTermsVersion,
          privacyVersion: currentPrivacyVersion,
          adultConfirmed: true,
        );
      await start(tester, repo);
      expect(find.textContaining('Tu cuenta está suspendida'), findsOneWidget);
      expect(repo.accountNameLoads, 0);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Ana María López',
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar cambios'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'basic info preserves all edits through the large keyboard and retry',
    (tester) async {
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true)
        ..failSave = true;
      await start(tester, repo);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      final values = [
        'Ana María',
        'López García',
        'ana@example.test',
        '5512345678',
        'Ciudad de México, CDMX',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.ensureVisible(fields.at(i));
        await tester.enterText(fields.at(i), values[i]);
        await tester.pumpAndSettle();
      }
      final save = find.widgetWithText(FilledButton, 'Guardar cambios');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(340));
      await tester.tap(save);
      await tester.pumpAndSettle();
      for (var i = 0; i < values.length; i++) {
        expect(
          tester.widget<TextFormField>(fields.at(i)).controller!.text,
          values[i],
        );
      }
      repo.failSave = false;
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(340));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.profile.name, '${values[0]} ${values[1]}');
      expect(repo.accountNames!.firstName, values[0]);
      expect(repo.accountNames!.lastName, values[1]);
      expect(repo.profile.phone, values[3]);
      expect(repo.profile.city, values[4]);
      expect(repo.user!.email, 'ana@example.test');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'email request preserves draft on failure and requires confirmation',
    (tester) async {
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true)
        ..failEmailChange = true;
      await start(tester, repo);
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'nueva@example.test',
      );
      await tap(tester, 'Guardar cambios');
      expect(find.text('nueva@example.test'), findsOneWidget);
      expect(find.text('Cambios guardados'), findsNothing);
      repo.failEmailChange = false;
      await tap(tester, 'Guardar cambios');
      expect(repo.requestedEmail, 'nueva@example.test');
      expect(repo.current!.email, 'ana@example.test');
      expect(
        find.textContaining('Revisa los correos de confirmación'),
        findsOneWidget,
      );
      await tap(tester, 'Guardar cambios');
      expect(repo.emailChangeRequests, 2);
    },
  );
  testWidgets('settings opens basic info without a rendering exception', (
    tester,
  ) async {
    final repo = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    await start(tester, repo, initialLocation: '/settings');

    expect(find.text('Términos y privacidad'), findsOneWidget);
    expect(find.text('Aviso de desarrollo'), findsNothing);
    final basicInfo = find.text('Información básica');
    await Scrollable.ensureVisible(tester.element(basicInfo), alignment: .35);
    await tester.pumpAndSettle();
    expect(basicInfo.hitTestable(), findsOneWidget);
    await tester.tap(basicInfo);
    await tester.pumpAndSettle();
    expect(find.text('Ciudad / estado'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
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
    final container = await start(tester, repo, initialLocation: '/adoptions');
    expect(find.text('Antes de continuar'), findsOneWidget);
    expect(find.bySemanticsLabel('Adoptar'), findsNothing);
    final row = find.byType(AuthConsentRow);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final bounds = tester.getRect(row);
    await tester.tapAt(Offset(bounds.left + 9, bounds.top + 11));
    await tester.pumpAndSettle();
    expect(tester.widget<AuthConsentRow>(row).value, true);
    await tap(tester, 'Términos y Condiciones');
    expect(container.read(routerProvider).state.uri.path, '/terms');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(tester.widget<AuthConsentRow>(row).value, true);
    await tap(tester, 'Aviso de Privacidad');
    expect(container.read(routerProvider).state.uri.path, '/privacy-notice');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(tester.widget<AuthConsentRow>(row).value, true);
    expect(repo.consentCount, 0);
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
    expect(find.text('Ciudad / estado'), findsNothing);
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

    expect(find.byTooltip('Continuar con Google'), findsOneWidget);
  });
  testWidgets(
    'form social icons dispatch one request and recover after provider failure',
    (tester) async {
      final repo = BlockingFormSocial();
      await start(
        tester,
        repo,
        initialLocation: '/login',
        config: const AppConfig(
          url: 'https://example.supabase.co',
          key: 'test',
          redirect: 'io.dopmi.app://auth/callback',
          googleEnabled: true,
        ),
      );
      final google = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Continuar con Google',
      );
      await tester.ensureVisible(google);
      await tester.pumpAndSettle();
      await tester.tap(google);
      await tester.tap(google);
      expect(repo.requests, ['google']);
      await tester.pump();
      expect(tester.widget<IconButton>(google).onPressed, isNull);
      repo.response.completeError(StateError('provider_not_configured'));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(google).onPressed, isNotNull);
      expect(repo.current, isNull);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'auth switch preserves rescuer intent and login input when returning',
    (tester) async {
      final repo = FakeIdentityRepository();
      await start(tester, repo, initialLocation: '/signup?intent=rescue');
      final loginLink = find.widgetWithText(TextButton, 'Inicia sesión');
      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AuthFormScreen>(find.byType(AuthFormScreen)).intent,
        'rescue',
      );
      final email = find.byType(TextFormField).first;
      await tester.enterText(email, 'ana@example.test');
      final signupLink = find.widgetWithText(TextButton, 'Crear cuenta');
      await tester.ensureVisible(signupLink);
      expect(tester.getSize(signupLink).height, greaterThanOrEqualTo(48));
      await tester.tapAt(
        tester.getRect(signupLink).bottomCenter - const Offset(0, 1),
      );
      await tester.pumpAndSettle();
      final screen = tester.widget<AuthFormScreen>(find.byType(AuthFormScreen));
      expect(screen.mode, AuthFormMode.signup);
      expect(screen.intent, 'rescue');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'ana@example.test',
      );
      expect(repo.current, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'forgot link opens real recovery and back retains entered email',
    (tester) async {
      final repo = FakeIdentityRepository();
      await start(tester, repo, initialLocation: '/login');
      final email = find.byType(TextFormField).first;
      await tester.enterText(email, 'ana@example.test');
      final forgot = find.widgetWithText(TextButton, 'Olvidé mi contraseña');
      await tester.ensureVisible(forgot);
      expect(tester.getSize(forgot).height, greaterThanOrEqualTo(48));
      final passwordRect = tester.getRect(find.byType(TextFormField).last);
      final forgotRect = tester.getRect(forgot);
      final submitRect = tester.getRect(
        find.widgetWithText(FilledButton, 'Inicia sesión'),
      );
      expect(forgotRect.top, closeTo(passwordRect.bottom, 0.5));
      expect(submitRect.top, closeTo(forgotRect.bottom, 0.5));
      expect(submitRect.top - passwordRect.bottom, closeTo(48, 0.5));
      await tester.tapAt(
        tester.getRect(forgot).bottomCenter - const Offset(0, 1),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AuthFormScreen>(find.byType(AuthFormScreen)).mode,
        AuthFormMode.forgot,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'ana@example.test',
      );
      expect(
        find.widgetWithText(TextButton, 'Necesito confirmar mi correo'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Enviar instrucciones'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'ana@example.test',
      );
      expect(repo.current, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final code in ['email_not_confirmed', 'invalid_credentials']) {
    testWidgets(
      'confirmation access follows Auth code without creating a session, $code',
      (tester) async {
        final repo = FailedFormLogin(code);
        await start(tester, repo, initialLocation: '/login');
        expect(find.text('Necesito confirmar mi correo'), findsNothing);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'ana@example.test',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Password1234',
        );
        final submit = find.widgetWithText(FilledButton, 'Inicia sesión');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        if (code == 'email_not_confirmed') {
          final confirm = find.widgetWithText(
            TextButton,
            'Necesito confirmar mi correo',
          );
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ConfirmationScreen>(find.byType(ConfirmationScreen))
                .email,
            'ana@example.test',
          );
        } else {
          expect(find.text('Necesito confirmar mi correo'), findsNothing);
          expect(find.text('Revisa tu correo y contraseña.'), findsOneWidget);
        }
        expect(repo.current, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
    expect(find.widgetWithText(FilledButton, 'Inicia sesión'), findsOneWidget);
  });
}

class BlockingFormSocial extends FakeIdentityRepository {
  final response = Completer<void>();
  final requests = <String>[];
  @override
  Future<void> oauth(String provider) {
    requests.add(provider);
    return response.future;
  }
}

class FailedFormLogin extends FakeIdentityRepository {
  FailedFormLogin(this.code);
  final String code;
  @override
  Future<void> login(String email, String password) async {
    throw AuthException('Login rejected', code: code);
  }
}
