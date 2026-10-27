import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/identity/onboarding_screen.dart';
import 'package:dopmi_mobile/features/identity/onboarding_art.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fake_identity_repository.dart';
import '../test/community_test.dart' show FakeCommunity;
import '../test/rescue_test.dart' show FakeCaseUpdates, FakeRescue;
import '../test/payments_test.dart' show FakePayments;
import '../test/guardian_test.dart' show FakeGuardian, activePlan;

import 'design_gallery.dart';

void main() {
  testWidgets('capture actual Flutter components for visual review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Rect viewport() =>
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    void expectInside(Rect rect, Rect bounds) {
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(bounds.left - .5));
      expect(rect.top, greaterThanOrEqualTo(bounds.top - .5));
      expect(rect.right, lessThanOrEqualTo(bounds.right + .5));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .5));
    }

    Future<void> revealControl(Finder control) async {
      if (control.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          control,
          120,
          scrollable: find.byType(Scrollable).first,
        );
      }
      expect(control, findsOneWidget);
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      expectInside(tester.getRect(control), viewport());
      expect(control.hitTestable(), findsOneWidget);
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    }

    Future<void> expectIntroduction(String title, String cta) async {
      final heading = find.text(title);
      final action = find.widgetWithText(FilledButton, cta);
      expect(heading, findsOneWidget);
      expect(find.byType(OnboardingArt), findsOneWidget);
      final headingRect = tester.getRect(heading);
      expect(headingRect.left, closeTo(20, .5));
      expect(
        tester.getRect(find.byType(OnboardingArt)).bottom,
        lessThanOrEqualTo(headingRect.top),
      );
      final dots = find.byType(AnimatedContainer);
      expect(dots, findsNWidgets(2));
      expect(
        headingRect.bottom,
        lessThanOrEqualTo(tester.getRect(dots.first).top),
      );
      expect(
        tester.getRect(dots.last).bottom,
        lessThanOrEqualTo(tester.getRect(action).top),
      );
      await tester.ensureVisible(heading);
      await tester.pumpAndSettle();
      expectInside(tester.getRect(heading), viewport());
      await revealControl(action);
      expect(tester.takeException(), isNull);
    }

    for (final family in ['Inter', 'Fraunces']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await tester.runAsync(loader.load);
    }
    final output = Directory('../../.tools/design-review');
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    await tester.runAsync(() => output.create(recursive: true));
    for (final specification in [
      ('donor', false, const Size(377, 852), 1.0),
      ('rescuer', true, const Size(377, 852), 1.0),
      ('small-large-text', false, const Size(320, 640), 2.0),
    ]) {
      tester.view.physicalSize = specification.$3;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dopmiTheme(rescuer: specification.$2),
            home: MediaQuery(
              data: MediaQueryData(
                size: specification.$3,
                textScaler: TextScaler.linear(specification.$4),
              ),
              child: DesignGallery(rescuer: specification.$2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/dopmi-wordmark.png'),
          key.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${output.path}/${specification.$1}.png'),
      );
      // This component gallery has no equivalent route in f693. Keep its
      // controls reachable at every captured scale, without a pixel baseline.
      for (final control in [
        find.byType(TextField),
        find.widgetWithText(FilledButton, 'Continuar'),
        find.widgetWithText(OutlinedButton, 'Conocer más'),
      ]) {
        await revealControl(control);
      }
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(377, 852);
    final welcomeKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: welcomeKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dopmiTheme(),
          home: const WelcomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // f693 places welcome copy above the prompt, then the two 92px orbs.
    // Absolute a3c969c positions no longer describe the approved F1 layout.
    final emptyPromptRect = tester.getRect(
      find.byKey(const ValueKey('welcome-prompt-region')),
    );
    final emptyHeadingRect = tester.getRect(find.text('Bienvenido a DopMi'));
    final adoptOrb = find.byKey(const ValueKey('welcome-orb-adopt'));
    final rescueOrb = find.byKey(const ValueKey('welcome-orb-rescue'));
    expectInside(emptyHeadingRect, viewport());
    expectInside(emptyPromptRect, viewport());
    expect(emptyHeadingRect.bottom, lessThanOrEqualTo(emptyPromptRect.top));
    expect(
      emptyPromptRect.bottom,
      lessThanOrEqualTo(tester.getRect(adoptOrb).top),
    );
    for (final orb in [adoptOrb, rescueOrb]) {
      expect(tester.getSize(orb), const Size(92, 92));
      expectInside(tester.getRect(orb), viewport());
      expect(orb.hitTestable(), findsOneWidget);
    }
    expect(
      tester.getRect(adoptOrb).right,
      lessThan(tester.getRect(rescueOrb).left),
    );
    await tester.runAsync(
      () => saveCapture(welcomeKey, '${output.path}/welcome.png'),
    );
    await tester.tap(adoptOrb);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // f693 retains a 280px summary; footer controls remain below it and visible.
    final summaryRect = tester.getRect(
      find.byKey(const ValueKey('welcome-summary-region')),
    );
    final continueRect = tester.getRect(
      find.ancestor(
        of: find.text('Continuar'),
        matching: find.byType(FilledButton),
      ),
    );
    final footnoteRect = tester.getRect(
      find.text(
        'Puedes cambiar tu selección en cualquier momento desde la configuración de tu perfil.',
      ),
    );
    expect(summaryRect.height, 280);
    expectInside(summaryRect, viewport());
    expect(
      summaryRect.top,
      greaterThanOrEqualTo(tester.getRect(adoptOrb).bottom),
    );
    expect(summaryRect.bottom, lessThanOrEqualTo(continueRect.top));
    expect(continueRect.height, greaterThanOrEqualTo(52));
    expectInside(continueRect, viewport());
    expect(continueRect.bottom, lessThanOrEqualTo(footnoteRect.top));
    expectInside(footnoteRect, viewport());

    await tester.runAsync(
      () => saveCapture(welcomeKey, '${output.path}/welcome-selected.png'),
    );
    for (final route in [
      ('login', '/login'),
      ('signup', '/signup'),
      ('forgot', '/forgot'),
      ('confirm', '/confirm'),
      ('start', '/start?intent=adopt'),
      ('start-rescue', '/start?intent=rescue'),
      ('onboarding-adopt', '/onboarding?intent=adopt'),
      ('onboarding-donate', '/onboarding?intent=donate'),
      ('onboarding-rescue', '/onboarding?intent=rescue'),
    ]) {
      final repo = FakeIdentityRepository();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
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
      for (final asset in [
        'assets/dopmi-wordmark.png',
        'assets/onboarding/luna-card.png',
        'assets/onboarding/luna-detail.png',
        'assets/onboarding/nina-card.png',
        'assets/onboarding/account-rescue.jpg',
        'assets/welcome-pets.png',
        'assets/guardian/guardian-urgent.jpg',
      ]) {
        await tester.runAsync(
          () => precacheImage(AssetImage(asset), key.currentContext!),
        );
      }
      for (final path in [
        'assets/profile/icon-verified.svg',
        'assets/onboarding/onb-syringe.svg',
        'assets/onboarding/icon-plus-circle.svg',
        'assets/profile/icon-bell.svg',
        'assets/profile/tab-donate.svg',
        'assets/onboarding/send.svg',
        'assets/onboarding/account-paw.svg',
        'assets/onboarding/icon-apple.svg',
        'assets/onboarding/icon-google.svg',
      ]) {
        final asset = SvgAssetLoader(path);
        await tester.runAsync(
          () => svg.cache.putIfAbsent(
            asset.cacheKey(null),
            () => asset.loadBytes(null),
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${output.path}/${route.$1}.png'),
      );
      if (route.$1 == 'login' || route.$1 == 'signup') {
        // f693 auth-gate--sheet retains the 32ch Inter14 description measure.
        final description = route.$1 == 'login'
            ? 'Entra para seguir tus favoritos y retomar donde lo dejaste.'
            : 'Completa tus datos para guardar favoritos y contactar al rescatista.';
        expect(
          tester.getSize(find.text(description)).width,
          closeTo(282.625, .5),
        );
      }
      if (route.$1 == 'login') {
        // Source: gap12 + margin2 + paragraph13*1.55 + sheet bottom18.
        final footer = tester.getRect(
          find.byKey(const ValueKey('auth-switch-footer')),
        );
        expect(footer.height, closeTo(52.15, .5));
        final sheet = tester.getRect(
          find.byKey(const ValueKey('auth-form-sheet')),
        );
        expectInside(sheet, viewport());
        expectInside(footer, sheet);
        expect(
          footer.bottom,
          closeTo(sheet.bottom, 1.5), // f693 adds the 1px frost hairline.
        );

        final emailField = find.byType(TextFormField).first;
        final input = find.descendant(
          of: emailField,
          matching: find.byType(InputDecorator),
        );
        expect(tester.getSize(input).height, closeTo(48, .5));
        await revealControl(emailField);
        Future<List<int>> sampleFocusRing() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          return (await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final pixels = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final rect = tester.getRect(input);
            final root = tester.getRect(find.byKey(key));
            final sampleX = (rect.left - root.left - 2).round();
            final sampleY = (rect.center.dy - root.top).round();
            final offset = (sampleY * image.width + sampleX) * 4;
            final result = List<int>.generate(
              4,
              (channel) => pixels!.getUint8(offset + channel),
            );
            image.dispose();
            return result;
          }))!;
        }

        final idleRing = await sampleFocusRing();
        await tester.tap(emailField);
        await tester.pump(const Duration(milliseconds: 1));
        // Focus notifications rebuild at the first frame; paint on the next.
        await tester.pump(const Duration(milliseconds: 1));
        final focusedRing = await sampleFocusRing();
        // CSS still paints rgba(247,203,45,.22), now over translucent frost.
        // Compare against the independently sampled idle background, not white.
        final expectedRing = Color.alphaBlend(
          const Color.fromRGBO(247, 203, 45, .22),
          Color.fromARGB(idleRing[3], idleRing[0], idleRing[1], idleRing[2]),
        ).toARGB32();
        expect(focusedRing, isNot(idleRing));
        for (var channel = 0; channel < 3; channel++) {
          expect(
            focusedRing[channel],
            closeTo((expectedRing >> ((2 - channel) * 8)) & 255, 2),
          );
        }
        expect(tester.widget<InputDecorator>(input).isFocused, isTrue);
        await tester.runAsync(
          () => saveCapture(key, '${output.path}/login-focused.png'),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<InputDecorator>(input).isFocused, isTrue);
        await tester.runAsync(
          () => saveCapture(key, '${output.path}/login-focused-settled.png'),
        );
        expect(tester.takeException(), isNull);
      }
      if (route.$1.startsWith('start') &&
          const bool.fromEnvironment('ENABLE_GOOGLE_AUTH')) {
        // f693's frost panel contains the CTA and available native providers.
        final panel = tester.getRect(
          find.byKey(const ValueKey('account-actions')),
        );
        expectInside(panel, viewport());
        final cta = tester.getRect(
          find.widgetWithText(FilledButton, 'Crea una cuenta'),
        );
        expectInside(cta, panel);
        await revealControl(
          find.widgetWithText(FilledButton, 'Crea una cuenta'),
        );
        final google = find.byTooltip('Continuar con Google');
        expect(google, findsOneWidget);
        expectInside(tester.getRect(google), panel);
      }
      if (route.$1 == 'onboarding-rescue') {
        await expectIntroduction(
          'Encontrarle hogar también es parte del rescate.',
          'Continuar',
        );
      }
      if (route.$1 == 'onboarding-adopt') {
        await expectIntroduction(
          'Tu nuevo mejor amigo ya te espera.',
          'Continuar',
        );
      }
      if (route.$1.startsWith('onboarding')) {
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Continuar'),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, 'Continuar').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pumpAndSettle();
        if (route.$1 == 'onboarding-rescue') {
          await expectIntroduction(
            'Tú lo cuidas. Te ayudamos a cubrir lo que necesita.',
            'Empezar',
          );
        }
        if (route.$1 == 'onboarding-adopt') {
          await expectIntroduction(
            'Conoce a quien cuida cada historia.',
            'Quiero adoptar',
          );
        }
        await tester.runAsync(
          () => saveCapture(key, '${output.path}/${route.$1}-2.png'),
        );
      }
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await repo.changes.close();
    }
    for (final route in [
      ('support-home', '/rescue-cases'),
      ('case-detail', '/rescue-cases/case-one'),
      ('rescuer-home', '/rescuer'),
      ('rescuer-cases', '/my-cases'),
      ('verification-files', '/rescue/verification-id'),
    ]) {
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'capture-user',
          'captura@example.test',
          verified: true,
        );
      if (route.$1.startsWith('rescuer') || route.$1 == 'verification-files') {
        identity.profile = const Profile(
          id: 'capture-user',
          name: 'Ana',
          phone: '',
          city: 'Monterrey',
          mode: 'rescuer',
          intent: 'rescue',
          status: 'active',
          termsVersion: currentTermsVersion,
          privacyVersion: currentPrivacyVersion,
          adultConfirmed: true,
        );
      }
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
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
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${output.path}/${route.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await identity.changes.close();
    }
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    for (final route in [
      ('contribution-amount', '/contribute-case/case-one'),
      ('guardian-intro', '/guardian'),
      ('guardian-active', '/guardian'),
    ]) {
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'capture-user',
          'captura@example.test',
          verified: true,
        );
      final guardian = FakeGuardian();
      if (route.$1 == 'guardian-active') {
        guardian.value = {'plan': activePlan(), 'activation': null};
      }
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          paymentRepositoryProvider.overrideWithValue(FakePayments()),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          guardianRepositoryProvider.overrideWithValue(guardian),
          guardianEnabledProvider.overrideWithValue(true),
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
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => saveCapture(key, '${output.path}/${route.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await identity.changes.close();
    }
    debugDisableShadows = true;
  });
}

Future<void> saveCapture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}
