import 'package:dopmi_mobile/features/payments/connect_client.dart';
import 'package:dopmi_mobile/features/payments/guardian_bank_action.dart';
import 'package:dopmi_mobile/features/payments/guardian_method_setup.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/native_wallet_sdk.dart';
import 'package:dopmi_mobile/features/payments/oneoff_payment_sheet.dart';
import 'package:dopmi_mobile/features/payments/payment_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment mode defaults to TEST and never follows a LIVE key', () {
    const mode = PaymentEnvironment(
      productionPublishableKey: 'pk_live_synthetic',
      guardianProductionEnabled: true,
    );
    expect(mode.isTest, true);
    expect(mode.isProduction, false);
    expect(mode.publishableKey, isEmpty);
    expect(mode.isValid, false);
    expect(mode.guardianEnabled, false);
    expect(mode.oneoffConsentVersion, 'oneoff-test-2026-10-15');
  });

  test('each explicit environment accepts only its selected public key', () {
    for (final production in [false, true]) {
      final environment = production ? 'production' : 'test';
      final expectedKey = production
          ? 'pk_live_synthetic'
          : 'pk_test_synthetic';
      final mode = PaymentEnvironment(
        environment: environment,
        testPublishableKey: 'pk_test_synthetic',
        productionPublishableKey: 'pk_live_synthetic',
      );
      expect(mode.publishableKey, expectedKey);
      expect(mode.isValid, true);
      for (final invalid in [
        '',
        production ? 'pk_test_synthetic' : 'pk_live_synthetic',
        'sk_test_synthetic',
        'sk_live_synthetic',
        'rk_live_synthetic',
        '$expectedKey\n',
        ' $expectedKey',
      ]) {
        expect(mode.acceptsPublishableKey(invalid), false, reason: environment);
        final crossed = PaymentEnvironment(
          environment: environment,
          testPublishableKey: invalid,
          productionPublishableKey: invalid,
        );
        expect(crossed.isValid, false, reason: environment);
      }
    }
  });

  test(
    'unknown environment disables payments, flags and consent before use',
    () {
      for (final environment in ['', 'live', 'Production', 'staging']) {
        final mode = PaymentEnvironment(
          environment: environment,
          testPublishableKey: 'pk_test_synthetic',
          productionPublishableKey: 'pk_live_synthetic',
          guardianTestEnabled: true,
          guardianProductionEnabled: true,
          nativeWalletsTestEnabled: true,
          applePayMerchantId: 'merchant.synthetic',
        );
        expect(mode.hasValidMode, false);
        expect(mode.isValid, false);
        expect(mode.publishableKey, isEmpty);
        expect(mode.guardianEnabled, false);
        expect(mode.nativeWalletsEnabled, false);
        expect(mode.merchantId, isEmpty);
        expect(() => mode.oneoffConsentVersion, throwsFormatException);
      }
    },
  );

  test('Guardian flags cannot enable the other environment', () {
    for (final environment in ['test', 'production']) {
      for (final testEnabled in [false, true]) {
        for (final productionEnabled in [false, true]) {
          final mode = PaymentEnvironment(
            environment: environment,
            guardianTestEnabled: testEnabled,
            guardianProductionEnabled: productionEnabled,
          );
          final container = ProviderContainer(
            overrides: [paymentEnvironmentProvider.overrideWithValue(mode)],
          );
          expect(
            container.read(guardianEnabledProvider),
            environment == 'test' ? testEnabled : productionEnabled,
          );
          container.dispose();
        }
      }
    }
  });

  test(
    'the embedded SDK providers all consume the same payment environment',
    () {
      for (final environment in ['test', 'production']) {
        final mode = PaymentEnvironment(
          environment: environment,
          testPublishableKey: 'pk_test_synthetic',
          productionPublishableKey: 'pk_live_synthetic',
          guardianTestEnabled: true,
          guardianProductionEnabled: true,
        );
        final container = ProviderContainer(
          overrides: [paymentEnvironmentProvider.overrideWithValue(mode)],
        );
        final connect = container.read(connectClientProvider);
        final setup = container.read(
          guardianMethodSetupProvider,
        ) as GuardianMethodSetupSdk;
        final bank = container.read(guardianBankSdkProvider);
        final oneoff =
            container.read(oneoffPaymentSheetProvider) as OneoffPaymentSheetSdk;
        expect(connect.paymentEnvironment, same(mode));
        expect(setup.paymentEnvironment, same(mode));
        expect(bank.paymentEnvironment, same(mode));
        expect(oneoff.paymentEnvironment, same(mode));
        expect(
          [
            connect.key,
            setup.publishableKey,
            bank.publishableKey,
            oneoff.publishableKey,
          ],
          everyElement(
            environment == 'production'
                ? 'pk_live_synthetic'
                : 'pk_test_synthetic',
          ),
        );
        expect(connect.enabled, true);
        expect(setup.enabled, true);
        expect(bank.enabled, true);
        container.dispose();
      }
    },
  );

  test(
    'production keeps wallets and merchant configuration disabled',
    () async {
      const mode = PaymentEnvironment(
        environment: 'production',
        productionPublishableKey: 'pk_live_synthetic',
        guardianProductionEnabled: true,
        nativeWalletsTestEnabled: true,
        applePayMerchantId: 'merchant.synthetic',
      );
      final container = ProviderContainer(
        overrides: [paymentEnvironmentProvider.overrideWithValue(mode)],
      );
      addTearDown(container.dispose);
      expect(mode.isValid, true);
      expect(mode.merchantId, isEmpty);
      expect(mode.nativeWalletsEnabled, false);
      expect(mode.oneoffConsentVersion, 'oneoff-live-2026-10-28');
      final wallet = container.read(nativeWalletSdkProvider);
      expect(wallet.publishableKey, 'pk_live_synthetic');
      expect(wallet.enabled, false);
      expect(wallet.provider, isNull);
      expect(await wallet.available(), false);
    },
  );
}
