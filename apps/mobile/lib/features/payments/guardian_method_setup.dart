import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/ui.dart';
import 'guardian_repository.dart';
import 'native_wallet_sdk.dart';

final guardianMethodSetupProvider = Provider<GuardianMethodSetup>(
  (ref) => GuardianMethodSetupSdk(
    publishableKey: const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY_TEST'),
    merchantId: const String.fromEnvironment('APPLE_PAY_MERCHANT_ID'),
    enabled: ref.watch(guardianEnabledProvider),
  ),
);

abstract interface class GuardianMethodSetup {
  bool get available;
  Future<void> present(String secret, {required bool Function() current});
}

// PaymentSheet handles card details inside Stripe's native component. Its
// completion is never a registration receipt; the caller reloads the server.
class GuardianMethodSetupSdk implements GuardianMethodSetup {
  GuardianMethodSetupSdk({
    required this.publishableKey,
    this.merchantId = '',
    this.enabled = false,
    TargetPlatform? platform,
    bool? web,
    Future<void> Function(String, String)? initialize,
    Future<void> Function(SetupPaymentSheetParameters)? prepare,
    Future<void> Function()? show,
  }) : platform = platform ?? defaultTargetPlatform,
       web = web ?? kIsWeb,
       _initialize = initialize ?? initializeDopmiStripeTest,
       _prepare = prepare ?? _prepareStripe,
       _show = show ?? _showStripe;

  final String publishableKey, merchantId;
  final bool enabled, web;
  final TargetPlatform platform;
  final Future<void> Function(String, String) _initialize;
  final Future<void> Function(SetupPaymentSheetParameters) _prepare;
  final Future<void> Function() _show;
  Future<void>? _initialization;
  bool _pending = false;

  @override
  bool get available =>
      enabled &&
      !web &&
      [TargetPlatform.android, TargetPlatform.iOS].contains(platform) &&
      RegExp(r'^pk_test_[A-Za-z0-9]+$').stringMatch(publishableKey) ==
          publishableKey;

  @override
  Future<void> present(
    String secret, {
    required bool Function() current,
  }) async {
    if (!current()) return;
    if (!available ||
        _pending ||
        RegExp(r'^seti_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$')
                .stringMatch(secret) !=
            secret) {
      throw const FormatException('El método de pago no está disponible.');
    }
    _pending = true;
    try {
      try {
        await (_initialization ??= _initialize(publishableKey, merchantId));
      } catch (_) {
        _initialization = null;
        rethrow;
      }
      // These SDK awaits can outlive the route or authenticated owner. Never
      // present a secret from the previous UI operation after either changes.
      if (!current()) return;
      await _prepare(
        SetupPaymentSheetParameters(
          setupIntentClientSecret: secret,
          merchantDisplayName: 'Dopmi',
          primaryButtonLabel: 'Guardar método de pago',
          returnURL: 'io.dopmi.app://payments/return',
          style: ThemeMode.light,
          // Android also applies these light surfaces in system dark mode.
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: purple,
              background: cream,
              componentBackground: Colors.white,
              componentText: ink,
              primaryText: ink,
              secondaryText: muted,
              placeholderText: muted,
              icon: ink,
            ),
          ),
        ),
      );
      if (!current()) return;
      await _show();
    } finally {
      _pending = false;
    }
  }
}

Future<void> _prepareStripe(SetupPaymentSheetParameters parameters) async {
  await Stripe.instance.initPaymentSheet(paymentSheetParameters: parameters);
}

Future<void> _showStripe() async {
  await Stripe.instance.presentPaymentSheet();
}
