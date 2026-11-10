import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/adoption_only_build.dart';

final paymentEnvironmentProvider = Provider<PaymentEnvironment>(
  (ref) => const PaymentEnvironment.compiled(),
);

// The compiled environment selects the payment mode. A key prefix validates
// that selection; it never selects LIVE mode or enables another environment.
class PaymentEnvironment {
  const PaymentEnvironment({
    this.environment = 'test',
    this.testPublishableKey = '',
    this.productionPublishableKey = '',
    this.guardianTestEnabled = false,
    this.guardianProductionEnabled = false,
    this.nativeWalletsTestEnabled = false,
    this.applePayMerchantId = '',
    this.adoptionOnly = adoptionOnlyBuild,
  });

  const PaymentEnvironment.compiled()
    : this(
        environment: const String.fromEnvironment(
          'DOPMI_ENVIRONMENT',
          defaultValue: 'test',
        ),
        testPublishableKey: const String.fromEnvironment(
          'STRIPE_PUBLISHABLE_KEY_TEST',
        ),
        productionPublishableKey: const String.fromEnvironment(
          'STRIPE_PUBLISHABLE_KEY',
        ),
        guardianTestEnabled: const bool.fromEnvironment('ENABLE_GUARDIAN_TEST'),
        guardianProductionEnabled: const bool.fromEnvironment(
          'ENABLE_GUARDIAN',
        ),
        nativeWalletsTestEnabled: const bool.fromEnvironment(
          'ENABLE_NATIVE_WALLETS_TEST',
        ),
        applePayMerchantId: const String.fromEnvironment(
          'APPLE_PAY_MERCHANT_ID',
        ),
      );

  final String environment, testPublishableKey, productionPublishableKey;
  final String applePayMerchantId;
  final bool guardianTestEnabled, guardianProductionEnabled;
  final bool nativeWalletsTestEnabled;
  final bool adoptionOnly;

  bool get isTest => environment == 'test';
  bool get isProduction => environment == 'production';
  bool get hasValidMode => isTest || isProduction;
  String get publishableKey => switch (adoptionOnly ? '' : environment) {
    'test' => testPublishableKey,
    'production' => productionPublishableKey,
    _ => '',
  };
  bool get isValid => acceptsPublishableKey(publishableKey);

  bool acceptsPublishableKey(String key) {
    if (adoptionOnly || !hasValidMode) return false;
    final prefix = isProduction ? 'pk_live_' : 'pk_test_';
    return RegExp('^$prefix[A-Za-z0-9]+\$').stringMatch(key) == key;
  }

  bool get guardianEnabled => switch (adoptionOnly ? '' : environment) {
    'test' => guardianTestEnabled,
    'production' => guardianProductionEnabled,
    _ => false,
  };
  bool get nativeWalletsEnabled =>
      !adoptionOnly && isTest && nativeWalletsTestEnabled;
  String get merchantId => isTest ? applePayMerchantId : '';

  void requireFinancialActions() {
    if (adoptionOnly) {
      throw const FormatException(
        'Esta función no está disponible en esta versión.',
      );
    }
  }

  String get oneoffConsentVersion => switch (environment) {
    'test' => 'oneoff-test-2026-10-15',
    'production' => 'oneoff-live-2026-10-28',
    _ => throw const FormatException('El entorno de pagos no está disponible.'),
  };
}
