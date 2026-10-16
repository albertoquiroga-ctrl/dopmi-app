import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/ui.dart';
import 'native_wallet_sdk.dart';

final oneoffPaymentSheetProvider = Provider<OneoffPaymentSheet>(
  (ref) => OneoffPaymentSheetSdk(
    publishableKey: const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY_TEST'),
    merchantId: const String.fromEnvironment('APPLE_PAY_MERCHANT_ID'),
  ),
);

abstract interface class OneoffPaymentSheet {
  bool get available;
  Future<void> present(String secret, {required bool Function() current});
}

// Card data and bank authentication stay in Stripe's native UI; no card fields,
// client secrets or SDK return values are persisted in Dopmi preferences.
class OneoffPaymentSheetSdk implements OneoffPaymentSheet {
  OneoffPaymentSheetSdk({
    required this.publishableKey,
    this.merchantId = '',
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
  final TargetPlatform platform;
  final bool web;
  final Future<void> Function(String, String) _initialize;
  final Future<void> Function(SetupPaymentSheetParameters) _prepare;
  final Future<void> Function() _show;
  Future<void>? _initialization;
  bool _pending = false;

  @override
  bool get available =>
      !web &&
      [TargetPlatform.android, TargetPlatform.iOS].contains(platform) &&
      RegExp(r'^pk_test_[A-Za-z0-9]+$').hasMatch(publishableKey);

  @override
  Future<void> present(
    String secret, {
    required bool Function() current,
  }) async {
    if (!current()) return;
    if (!available ||
        _pending ||
        !RegExp(r'^pi_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$').hasMatch(secret)) {
      throw const FormatException(
        'El pago seguro no está disponible en este dispositivo.',
      );
    }
    _pending = true;
    try {
      try {
        await (_initialization ??= _initialize(publishableKey, merchantId));
      } catch (_) {
        _initialization = null;
        rethrow;
      }
      // Initialization/preparation can finish after navigation or sign-out.
      // Revalidate the original caller before handing its secret to native UI.
      if (!current()) return;
      await _prepare(
        SetupPaymentSheetParameters(
          paymentIntentClientSecret: secret,
          merchantDisplayName: 'Dopmi',
          primaryButtonLabel: 'Confirmar aportación',
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

Future<void> _showStripe() => Stripe.instance.presentPaymentSheet();
