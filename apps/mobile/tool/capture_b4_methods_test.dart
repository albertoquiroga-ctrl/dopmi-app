// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_screen.dart';
import 'package:dopmi_mobile/features/payments/guardian_method_setup.dart';
import 'package:dopmi_mobile/features/payments/guardian_payment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fake_identity_repository.dart';
import '../test/registration_method_control_test.dart'
    show MethodControlRepo, MethodControlSdk;
import 'capture_design_test.dart' show saveCapture;

// Actual methods screen and consent dialog, synthetic repository/SDK only.
// This never changes a provider method, registration, or payment.
void main() {
  for (final scale in [1.0, 1.15, 2.0]) {
    testWidgets('B4 native method consent and result scale=$scale', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scale == 2
          ? const Size(320, 640)
          : const Size(377, 852);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
        final loader = FontLoader(family)
          ..addFont(
            rootBundle.load(
              family == 'MaterialIcons'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$family.ttf',
            ),
          );
        await tester.runAsync(loader.load);
      }
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final repo = MethodControlRepo();
      repo.cards = [
        GuardianPaymentCard.fromJson({
          'id': 'pm_fixtureOld',
          'brand': 'visa',
          'last4': '4242',
          'default': true,
          'guardian_current': false,
          'exp_month': 12,
          'exp_year': 2030,
        }),
        GuardianPaymentCard.fromJson({
          'id': 'pm_fixtureCurrent',
          'brand': 'visa',
          'last4': '1111',
          'default': false,
          'guardian_current': true,
          'exp_month': 10,
          'exp_year': 2031,
        }),
      ];
      final sdk = MethodControlSdk(() async {
        repo.applied = true;
      });
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          guardianRepositoryProvider.overrideWithValue(repo),
          guardianEnabledProvider.overrideWithValue(true),
          guardianMethodSetupProvider.overrideWithValue(sdk),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dopmiTheme(),
              home: const GuardianScreen(paymentMethodsOnly: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final output = Directory('../../.tools/b4-visual-20261017');
      await tester.runAsync(() => output.create(recursive: true));
      final prefix = '${output.path}/method-$scale';
      await tester.runAsync(() => saveCapture(key, '$prefix-top.png'));
      final action = find.text('Cambiar tarjeta');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cambiar tarjeta'),
        ),
        findsOneWidget,
      );
      await tester.runAsync(() => saveCapture(key, '$prefix-consent.png'));
      final confirm = find.text('Autorizar y continuar');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(sdk.shown, 1);
      expect(repo.methodCalls.length, 1);
      expect(repo.calls, isEmpty);
      final scrollable = find.byType(Scrollable).first;
      for (var step = 0; step < 30; step++) {
        if (tester.state<ScrollableState>(scrollable).position.extentAfter <
            .5) {
          break;
        }
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(
        tester.state<ScrollableState>(scrollable).position.extentAfter,
        lessThan(.5),
      );
      await tester.runAsync(() => saveCapture(key, '$prefix-end.png'));
      expect(tester.takeException(), isNull);
    });
  }
}
