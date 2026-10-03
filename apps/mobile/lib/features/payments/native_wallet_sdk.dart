import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

final nativeWalletSdkProvider = Provider<NativeWalletSdk>(
  (ref) => NativeWalletSdk(
    publishableKey: const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY_TEST'),
    merchantId: const String.fromEnvironment('APPLE_PAY_MERCHANT_ID'),
    enabled: const bool.fromEnvironment('ENABLE_NATIVE_WALLETS_TEST'),
  ),
);

class NativeWalletSdk {
  NativeWalletSdk({
    required this.publishableKey,
    this.merchantId = '',
    this.enabled = false,
    TargetPlatform? platform,
    bool? web,
    Future<void> Function(String key, String merchant)? initialize,
    Future<bool> Function(IsGooglePaySupportedParams? params)? supported,
    Future<void> Function(String secret, PlatformPayConfirmParams params)?
    confirm,
  }) : platform = platform ?? defaultTargetPlatform,
       web = web ?? kIsWeb,
       _initialize = initialize ?? _initializeStripe,
       _supported = supported ?? _supportedStripe,
       _confirm = confirm ?? _confirmStripe;

  final String publishableKey, merchantId;
  final bool enabled, web;
  final TargetPlatform platform;
  final Future<void> Function(String, String) _initialize;
  final Future<bool> Function(IsGooglePaySupportedParams?) _supported;
  final Future<void> Function(String, PlatformPayConfirmParams) _confirm;
  Future<void>? _initialization;

  String? get provider {
    if (!enabled ||
        web ||
        !RegExp(r'^pk_test_[A-Za-z0-9]+$').hasMatch(publishableKey)) {
      return null;
    }
    if (platform == TargetPlatform.android) return 'google_pay';
    if (platform == TargetPlatform.iOS &&
        RegExp(r'^merchant\.[A-Za-z0-9.-]+$').hasMatch(merchantId)) {
      return 'apple_pay';
    }
    return null;
  }

  Future<bool> available() async {
    if (provider == null) return false;
    try {
      await (_initialization ??= _initialize(publishableKey, merchantId));
      return await _supported(
        platform == TargetPlatform.android
            ? const IsGooglePaySupportedParams(
                testEnv: true,
                existingPaymentMethodRequired: true,
              )
            : null,
      );
    } catch (_) {
      _initialization = null;
      return false;
    }
  }

  // This only authorizes a SetupIntent. The caller must retrieve the server
  // receipt and fresh card list afterward; SDK completion is not a saved receipt.
  Future<void> authorize(String walletType, String secret) async {
    if (walletType != provider ||
        !RegExp(r'^seti_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$').hasMatch(secret) ||
        !await available()) {
      throw const FormatException(
        'La billetera no está disponible en este dispositivo.',
      );
    }
    final params = walletType == 'google_pay'
        ? const PlatformPayConfirmParams.googlePay(
            googlePay: GooglePayParams(
              testEnv: true,
              merchantCountryCode: 'MX',
              currencyCode: 'MXN',
              merchantName: 'Dopmi',
            ),
          )
        : const PlatformPayConfirmParams.applePay(
            applePay: ApplePayParams(
              merchantCountryCode: 'MX',
              currencyCode: 'MXN',
              cartItems: [
                ApplePayCartSummaryItem.immediate(
                  label: 'Dopmi · Guardar tarjeta sin cobro',
                  amount: '0.00',
                ),
              ],
            ),
          );
    await _confirm(secret, params);
  }
}

Future<void> _initializeStripe(String key, String merchant) async {
  Stripe.publishableKey = key;
  Stripe.merchantIdentifier = merchant.isEmpty ? null : merchant;
  Stripe.urlScheme = 'io.dopmi.app';
  await Stripe.instance.applySettings();
}

Future<bool> _supportedStripe(IsGooglePaySupportedParams? params) =>
    Stripe.instance.isPlatformPaySupported(googlePay: params);

Future<void> _confirmStripe(
  String secret,
  PlatformPayConfirmParams params,
) async {
  await Stripe.instance.confirmPlatformPaySetupIntent(
    clientSecret: secret,
    confirmParams: params,
  );
}
