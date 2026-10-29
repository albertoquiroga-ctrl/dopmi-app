import 'package:dopmi_mobile/features/payments/native_wallet_sdk.dart';
import 'package:dopmi_mobile/features/payments/payment_environment.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('shared initialization applies explicit TEST and LIVE settings and clears the TEST merchant', () async {
    const channel = MethodChannel('flutter.stripe/payments', JSONMethodCodec());
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'initialise');
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await initializeDopmiStripeTest('pk_test_synthetic', 'merchant.synthetic');
    expect(
      (calls.single.arguments as Map)['publishableKey'],
      'pk_test_synthetic',
    );
    expect(
      (calls.single.arguments as Map)['merchantIdentifier'],
      'merchant.synthetic',
    );
    await initializeDopmiStripe(
      'pk_live_synthetic',
      'merchant.synthetic',
      paymentEnvironment: const PaymentEnvironment(environment: 'production'),
    );
    expect(calls, hasLength(2));
    final live = calls.last.arguments as Map;
    expect(live['publishableKey'], 'pk_live_synthetic');
    expect(live['merchantIdentifier'], isNull);
    expect(live['urlScheme'], 'io.dopmi.app');
  });
  test('LIVE wallets remain disabled even with TEST flags and an injected merchant', () async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final sdk = NativeWalletSdk(
        publishableKey: 'pk_live_synthetic',
        paymentEnvironment: const PaymentEnvironment(
          environment: 'production',
          nativeWalletsTestEnabled: true,
        ),
        enabled: true,
        merchantId: 'merchant.synthetic',
        web: false,
        platform: platform,
        initialize: (_, _) async => fail('LIVE wallet must not initialize'),
        supported: (_) async => fail('LIVE wallet must not query the SDK'),
        confirm: (_, _) async => fail('LIVE wallet must not confirm'),
      );
      expect(sdk.provider, isNull);
      expect(await sdk.available(), false);
      await expectLater(
        sdk.authorize('google_pay', 'seti_synthetic_secret_synthetic'),
        throwsFormatException,
      );
    }
  });
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
