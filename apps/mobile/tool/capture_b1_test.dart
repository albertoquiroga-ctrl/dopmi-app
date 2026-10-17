// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_payment_card.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_account_photo_repository.dart';
import '../test/fake_identity_repository.dart';
import '../test/guardian_test.dart' show FakeGuardian, activePlan;
import '../test/rescue_test.dart' show FakeRescue;
import 'capture_design_test.dart' show saveCapture;

// Real production routes/components with clearly synthetic, read-only data.
// Screenshots do not certify native SDK, network, device or human acceptance.
void main() {
  for (final mode in ['donor', 'rescuer']) {
    for (final scale in [1.0, 1.15, 2.0]) {
      for (final route in ['account', 'payment-methods']) {
        testWidgets('B1 capture $mode $route scale=$scale', (tester) async {
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
            ..user = const Identity(
              'one',
              'fixture@example.test',
              verified: true,
            );
          await identity.setExperience(mode);
          final guardian = FakeGuardian()
            ..value = {
              'plan': activePlan(),
              'activation': null,
              'method_change_available': true,
            }
            ..cards = [
              const GuardianPaymentCard(
                id: 'pm_fixture',
                brand: 'visa',
                last4: '4242',
                isDefault: true,
              ),
            ];
          final container = ProviderContainer(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              accountPhotoRepositoryProvider.overrideWithValue(
                emptyAccountPhotoRepository(identity),
              ),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
              rescueRepositoryProvider.overrideWithValue(FakeRescue()),
              guardianRepositoryProvider.overrideWithValue(guardian),
              guardianEnabledProvider.overrideWithValue(true),
              routerInitialLocationProvider.overrideWithValue(
                '/settings/$route',
              ),
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
                child: const DopmiApp(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final output = Directory('../../.tools/b1-visual-20261017');
          await tester.runAsync(() => output.create(recursive: true));
          final prefix = '${output.path}/$mode-$route-$scale';
          await tester.runAsync(() => saveCapture(key, '$prefix-top.png'));
          final list = find.byType(Scrollable).first;
          // Lazy lists refine their extent as children enter the viewport.
          for (var step = 0; step < 20; step++) {
            await tester.drag(list, const Offset(0, -500));
            await tester.pumpAndSettle();
            final position = tester.state<ScrollableState>(list).position;
            if (position.extentAfter < 0.5) break;
          }
          final scroll = tester.state<ScrollableState>(list).position;
          expect(scroll.pixels, closeTo(scroll.maxScrollExtent, 0.5));
          await tester.runAsync(() => saveCapture(key, '$prefix-end.png'));
          expect(guardian.calls, isEmpty);
          expect(guardian.opened, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
