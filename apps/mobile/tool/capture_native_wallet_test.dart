// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_payment_card.dart';
import 'package:dopmi_mobile/features/payments/native_wallet_repository.dart';
import 'package:dopmi_mobile/features/payments/native_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/guardian_test.dart' show FakeGuardian;
import '../test/native_wallet_screen_test.dart' show FakeWallet;
import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';

void main() {
  setUpAll(() async {
    for (final name in ['apple', 'google']) {
      final asset = SvgAssetLoader('assets/onboarding/icon-$name.svg');
      await svg.cache.putIfAbsent(
        asset.cacheKey(null),
        () => asset.loadBytes(null),
      );
    }
    for (final family in ['Inter', 'Fraunces']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });
  for (final large in [false, true]) {
    for (final review in [false, true]) {
      testWidgets('native wallets large=$large review=$review', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(large ? 320 : 377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final identity = FakeIdentityRepository()
          ..user = Identity('one', 'one@example.test', verified: true);
        final cards = FakeGuardian()
          ..cards = [
            const GuardianPaymentCard(
              id: 'pm_fixture',
              brand: 'visa',
              last4: '4242',
              isDefault: true,
            ),
          ];
        final wallet = FakeWallet();
        if (review) {
          wallet.receipt = {
            'key': '00000000-0000-4000-8000-000000000001',
            'wallet_type': 'google_pay',
            'status': 'attention',
            'card_id': null,
          };
        }
        final sdk = NativeWalletSdk(
          publishableKey: 'pk_test_fixture',
          enabled: true,
          platform: TargetPlatform.android,
          web: false,
          initialize: (key, merchant) async {},
          supported: (params) async => true,
          confirm: (secret, params) async {},
        );
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            guardianRepositoryProvider.overrideWithValue(cards),
            guardianEnabledProvider.overrideWithValue(true),
            nativeWalletRepositoryProvider.overrideWithValue(wallet),
            nativeWalletSdkProvider.overrideWithValue(sdk),
            routerInitialLocationProvider.overrideWithValue(
              '/settings/payment-methods',
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: const DopmiApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        Future<void> capture(String suffix) async {
          await tester.runAsync(() async {
            final img =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory(
              'C:/Users/betoq/AppData/Local/Temp/dopmi-native-wallet-396',
            );
            await dir.create(recursive: true);
            await File(
              '${dir.path}/wallets-${large ? 'large' : 'normal'}-${review ? 'review' : 'ready'}$suffix.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            img.dispose();
          });
        }

        await capture('');
        if (large && review) {
          await tester.scrollUntilVisible(
            find.text('Actualizar estado'),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          expect(
            tester.getRect(find.text('Actualizar estado')).bottom,
            lessThanOrEqualTo(852),
          );
          await capture('-bottom');
        }
      });
    }
  }
}
