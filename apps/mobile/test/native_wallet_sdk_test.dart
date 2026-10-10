import 'package:dopmi_mobile/features/payments/native_wallet_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported or unconfigured wallets never initialize SDK', () async {
    for (final sdk in [
      NativeWalletSdk(publishableKey: 'pk_test_fixture'),
      NativeWalletSdk(
        publishableKey: 'pk_live_fixture',
        enabled: true,
        platform: TargetPlatform.android,
      ),
      NativeWalletSdk(
        publishableKey: 'pk_test_fixture',
        enabled: true,
        platform: TargetPlatform.iOS,
      ),
      NativeWalletSdk(
        publishableKey: 'pk_test_fixture',
        enabled: true,
        platform: TargetPlatform.android,
        web: true,
      ),
    ]) {
      expect(sdk.provider, null);
      expect(await sdk.available(), false);
      await expectLater(
        sdk.authorize('google_pay', 'seti_fixture_secret_fixture'),
        throwsFormatException,
      );
    }
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform authorizes only SetupIntent with correct native provider',
      () async {
        var initialized = 0, confirmations = 0;
        IsGooglePaySupportedParams? availability;
        PlatformPayConfirmParams? confirmed;
        final sdk = NativeWalletSdk(
          publishableKey: 'pk_test_fixture',
          enabled: true,
          merchantId: 'merchant.com.example.fixture',
          platform: platform,
          web: false,
          initialize: (key, merchant) async {
            initialized++;
            expect(key, 'pk_test_fixture');
          },
          supported: (params) async {
            availability = params;
            return true;
          },
          confirm: (secret, params) async {
            confirmations++;
            confirmed = params;
            expect(secret, 'seti_fixture_secret_fixture');
          },
        );
        expect(await sdk.available(), true);
        final provider = platform == TargetPlatform.android
            ? 'google_pay'
            : 'apple_pay';
        await expectLater(
          sdk.authorize(provider, 'pi_fixture_secret_fixture'),
          throwsFormatException,
        );
        await expectLater(
          sdk.authorize('unsupported', 'seti_fixture_secret_fixture'),
          throwsFormatException,
        );
        await sdk.authorize(provider, 'seti_fixture_secret_fixture');
        expect(initialized, 1);
        expect(confirmations, 1);
        final json = confirmed!.toJson();
        if (platform == TargetPlatform.android) {
          expect(availability!.testEnv, true);
          expect(availability!.existingPaymentMethodRequired, true);
          expect(json['googlePay']['testEnv'], true);
          expect(json['googlePay']['currencyCode'], 'MXN');
        } else {
          expect(availability, null);
          expect(json['applePay']['cartItems'][0]['amount'], '0.00');
        }
      },
    );
  }
  test(
    'initialization failure can retry and unavailable SDK never confirms',
    () async {
      var attempts = 0, confirmations = 0;
      final sdk = NativeWalletSdk(
        publishableKey: 'pk_test_fixture',
        enabled: true,
        platform: TargetPlatform.android,
        web: false,
        initialize: (key, merchant) async {
          if (++attempts == 1) throw StateError('fixture');
        },
        supported: (params) async => false,
        confirm: (secret, params) async {
          confirmations++;
        },
      );
      expect(await sdk.available(), false);
      await expectLater(
        sdk.authorize('google_pay', 'seti_fixture_secret_fixture'),
        throwsFormatException,
      );
      expect(attempts, 2);
      expect(confirmations, 0);
    },
  );
}
