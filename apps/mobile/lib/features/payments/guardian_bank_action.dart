import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'guardian_registration.dart';
import 'guardian_repository.dart';
import 'native_wallet_sdk.dart';
import 'payment_environment.dart';

final guardianBankSdkProvider = Provider<GuardianBankSdk>(
  (ref) => GuardianBankSdk(
    publishableKey: ref.watch(paymentEnvironmentProvider).publishableKey,
    merchantId: ref.watch(paymentEnvironmentProvider).merchantId,
    paymentEnvironment: ref.watch(paymentEnvironmentProvider),
    enabled: ref.watch(guardianEnabledProvider),
  ),
);

final guardianBankActionProvider = Provider<GuardianBankAction>((ref) {
  final repository = ref.watch(guardianRepositoryProvider);
  final sdk = ref.watch(guardianBankSdkProvider);
  return GuardianBankAction(
    request: repository.registrationBankAction,
    authenticate: sdk.authenticate,
    reload: repository.registrationState,
  );
});

class GuardianBankSdk {
  GuardianBankSdk({
    required this.publishableKey,
    this.merchantId = '',
    this.enabled = false,
    this.paymentEnvironment = const PaymentEnvironment(),
    TargetPlatform? platform,
    bool? web,
    Future<void> Function(String, String)? initialize,
    Future<void> Function(String)? handle,
  }) : platform = platform ?? defaultTargetPlatform,
       web = web ?? kIsWeb,
       _initialize =
           initialize ??
           ((key, merchant) => initializeDopmiStripe(
             key,
             merchant,
             paymentEnvironment: paymentEnvironment,
           )),
       _handle = handle ?? _handleStripe;

  final String publishableKey;
  final String merchantId;
  final PaymentEnvironment paymentEnvironment;
  final bool enabled, web;
  final TargetPlatform platform;
  final Future<void> Function(String, String) _initialize;
  final Future<void> Function(String) _handle;
  Future<void>? _initialization;

  bool get available =>
      enabled &&
      !web &&
      [TargetPlatform.android, TargetPlatform.iOS].contains(platform) &&
      paymentEnvironment.acceptsPublishableKey(publishableKey);

  Future<void> authenticate(String secret) async {
    if (!available ||
        !RegExp(r'^pi_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$').hasMatch(secret)) {
      throw const FormatException('La acción bancaria no está disponible.');
    }
    try {
      await (_initialization ??= _initialize(
        publishableKey,
        paymentEnvironment.isTest ? merchantId : '',
      ));
    } catch (_) {
      _initialization = null;
      rethrow;
    }
    await _handle(secret);
  }
}

Future<void> _handleStripe(String secret) async {
  await Stripe.instance.handleNextAction(secret);
}

// No secret or SDK result is persisted. Every outcome (including closing the
// bank sheet and a lost response) re-reads the server's same registration.
class GuardianBankAction {
  GuardianBankAction({
    required this.request,
    required this.authenticate,
    required this.reload,
  });
  final Future<Object?> Function(String registration, String attempt) request;
  final Future<void> Function(String secret) authenticate;
  final Future<GuardianRegistration?> Function() reload;
  Future<GuardianRegistration?>? _pending;
  String? _pendingKey;

  Future<GuardianRegistration?> run(GuardianRegistration registration) {
    final attempt = registration.attemptId;
    if (registration.status != 'registered' ||
        attempt == null ||
        registration.paymentState !=
            GuardianRegistrationPaymentState.requiresAction) {
      return Future.error(
        const FormatException('La acción bancaria no está disponible.'),
      );
    }
    final key = '${registration.id}/$attempt';
    if (_pending != null) {
      if (_pendingKey == key) return _pending!;
      return Future.error(
        const FormatException('Hay una confirmación en proceso.'),
      );
    }
    _pendingKey = key;
    final operation = _run(registration.id, attempt);
    _pending = operation.whenComplete(() {
      _pending = null;
      _pendingKey = null;
    });
    return _pending!;
  }

  Future<GuardianRegistration?> _run(
    String registration,
    String attempt,
  ) async {
    try {
      final result = await request(registration, attempt);
      if (result is! Map ||
          result['id'] != registration ||
          result['attempt_id'] != attempt ||
          !['processing', 'requires_action'].contains(result['state'])) {
        throw const FormatException('Confirmación bancaria no disponible.');
      }
      if (result['state'] == 'requires_action') {
        final secret = result['client_secret'];
        if (secret is! String ||
            !RegExp(r'^pi_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$')
                .hasMatch(secret)) {
          throw const FormatException('Confirmación bancaria no disponible.');
        }
        await authenticate(secret);
      }
    } catch (_) {
      // A transport/SDK exception is not a confirmed charge failure. Never
      // retain its message (it may contain processor data) or start a retry.
    }
    final state = await reload();
    if (state == null || state.id != registration) {
      throw const FormatException(
        'No se pudo confirmar el estado del registro.',
      );
    }
    return state;
  }
}
