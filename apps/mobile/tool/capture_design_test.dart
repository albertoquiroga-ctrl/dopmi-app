import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/identity/onboarding_screen.dart';
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
    // Empty-state Source DOM at 377×852, a3c969c.
    final emptyPromptRect = tester.getRect(
      find.byKey(const ValueKey('welcome-prompt-region')),
    );
    expect(emptyPromptRect.top, closeTo(231.2, 1));
    expect(emptyPromptRect.height, closeTo(447.6, 1));
    expect(
      tester.getRect(find.byKey(const ValueKey('welcome-orb-adopt'))).top,
      closeTo(686.8, 1),
    );
    expect(
      tester.getRect(find.text('Bienvenido a DopMi')).top,
      closeTo(104, 1),
    );
    await tester.runAsync(
      () => saveCapture(welcomeKey, '${output.path}/welcome.png'),
    );
    await tester.tap(find.text('Adoptar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Source DOM measured at 377×852, irlanda/apoyar-detalle-perfil@a3c969c.
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
    expect(summaryRect.top, closeTo(333.6, 1));
    expect(summaryRect.height, 280);
    expect(continueRect.top, closeTo(726.1, 1));
    expect(footnoteRect.bottom, closeTo(824, 1));

    await tester.runAsync(
      () => saveCapture(welcomeKey, '${output.path}/welcome-selected.png'),
    );
    for (final route in [
      ('login', '/login'),
      ('signup', '/signup'),
      ('forgot', '/forgot'),
      ('confirm', '/confirm'),
      ('start', '/start?intent=adopt'),
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
        'assets/guardian/guardian-urgent.jpg',
      ]) {
        await tester.runAsync(
          () => precacheImage(AssetImage(asset), key.currentContext!),
        );
      }
      for (final path in [
        'assets/profile/icon-verified.svg',
        'assets/onboarding/send.svg',
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
      if (route.$1 == 'onboarding-adopt') {
        // Source adopter copy/CTA, 377×852, a3c969c, settled animation.
        final title = tester.getRect(
          find.text('Tu nuevo mejor amigo ya te espera.'),
        );
        expect(title.left, 20);
        expect(title.top, closeTo(621.8, 2));
        expect(
          tester.getRect(find.widgetWithText(FilledButton, 'Continuar')).top,
          closeTo(780, 1),
        );
      }
      if (route.$1.startsWith('onboarding')) {
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Continuar'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pumpAndSettle();
        if (route.$1 == 'onboarding-adopt') {
          expect(
            tester
                .getRect(find.text('Conoce a quien cuida cada historia.'))
                .top,
            closeTo(580.2, 2),
          );
          expect(
            tester
                .getRect(find.widgetWithText(FilledButton, 'Quiero adoptar'))
                .top,
            closeTo(780, 1),
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
      ('contribution-amount', '/contribute/expense-one'),
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
