import 'dart:async';

import 'package:dopmi_mobile/features/payments/guardian_bank_action.dart';
import 'package:dopmi_mobile/features/payments/guardian_registration.dart';
import 'package:dopmi_mobile/features/payments/native_wallet_sdk.dart';
import 'package:dopmi_mobile/features/payments/payment_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const registrationId = '72000000-0000-4000-8000-000000000001';
const attemptId = '72000000-0000-4000-8000-000000000003';
const secret = 'pi_synthetic_secret_synthetic';
GuardianRegistration state(
  GuardianRegistrationPaymentState payment, {
  String status = 'registered',
}) => GuardianRegistration(
  id: registrationId,
  key: '72000000-0000-4000-8000-000000000002',
  status: status,
  grossCents: 2000,
  revision: 1,
  registeredAt: DateTime.utc(2026, 10, 14),
  nextEvaluationAt: status == 'canceled' ? null : DateTime.utc(2026, 11, 14),
  paymentState: payment,
  attemptId: attemptId,
  allocatedCents: payment == GuardianRegistrationPaymentState.allocated
      ? 1860
      : 0,
  refundCents: 0,
  evaluationStatus: null,
  evaluationCycle: null,
);
Map<String, dynamic> receipt() => {
  'id': registrationId,
  'attempt_id': attemptId,
  'state': 'requires_action',
  'client_secret': secret,
};

void main() {
  test('bank SDK accepts LIVE mode without enabling a merchant or changing the action', () async {
    var initialized = 0, handled = 0;
    final sdk = GuardianBankSdk(
      publishableKey: 'pk_live_synthetic',
      paymentEnvironment: const PaymentEnvironment(environment: 'production'),
      merchantId: 'merchant.synthetic',
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      initialize: (key, merchant) async {
        expect(key, 'pk_live_synthetic');
        expect(merchant, isEmpty);
        initialized++;
      },
      handle: (value) async {
        expect(value, secret);
        handled++;
      },
    );
    expect(sdk.available, true);
    await sdk.authenticate(secret);
    await sdk.authenticate(secret);
    expect(initialized, 1);
    expect(handled, 2);
  });
  test('bank SDK and shared initializer reject crossed, missing, secret and unknown configuration', () async {
    for (final config in [
      (mode: 'production', key: 'pk_test_synthetic'),
      (mode: 'production', key: ''),
      (mode: 'production', key: 'sk_live_synthetic'),
      (mode: 'unknown', key: 'pk_live_synthetic'),
    ]) {
      final mode = PaymentEnvironment(environment: config.mode);
      final sdk = GuardianBankSdk(
        publishableKey: config.key,
        paymentEnvironment: mode,
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        initialize: (_, _) async => fail('must not initialize'),
        handle: (_) async => fail('must not handle an action'),
      );
      expect(sdk.available, false);
      await expectLater(sdk.authenticate(secret), throwsFormatException);
      await expectLater(
        initializeDopmiStripe(config.key, '', paymentEnvironment: mode),
        throwsFormatException,
      );
    }
  });
  test(
    'shared initializer refuses a live key before platform SDK work',
    () async {
      await expectLater(
        initializeDopmiStripeTest('pk_live_synthetic', ''),
        throwsFormatException,
      );
    },
  );
  test('bank SDK rejects disabled live web and unsupported platform without initialization', () async {
    var calls = 0;
    for (final config in [
      (
        key: 'pk_test_synthetic',
        enabled: false,
        web: false,
        platform: TargetPlatform.android,
      ),
      (
        key: 'pk_live_synthetic',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
      ),
      (
        key: 'pk_test_synthetic',
        enabled: true,
        web: true,
        platform: TargetPlatform.android,
      ),
      (
        key: 'pk_test_synthetic',
        enabled: true,
        web: false,
        platform: TargetPlatform.windows,
      ),
    ]) {
      final sdk = GuardianBankSdk(
        publishableKey: config.key,
        enabled: config.enabled,
        web: config.web,
        platform: config.platform,
        initialize: (_, _) async {
          calls++;
        },
        handle: (_) async {
          calls++;
        },
      );
      expect(sdk.available, false);
      await expectLater(sdk.authenticate(secret), throwsFormatException);
    }
    expect(calls, 0);
  });
  test('bank SDK uses safe test initialization and handles only PaymentIntent action', () async {
    var initialized = 0, handled = 0;
    final sdk = GuardianBankSdk(
      publishableKey: 'pk_test_synthetic',
      merchantId: 'merchant.synthetic',
      enabled: true,
      web: false,
      platform: TargetPlatform.android,
      initialize: (key, merchant) async {
        expect(key, 'pk_test_synthetic');
        expect(merchant, 'merchant.synthetic');
        initialized++;
      },
      handle: (value) async {
        expect(value, secret);
        handled++;
      },
    );
    await expectLater(
      sdk.authenticate('seti_synthetic_secret_synthetic'),
      throwsFormatException,
    );
    await sdk.authenticate(secret);
    await sdk.authenticate(secret);
    expect(initialized, 1);
    expect(handled, 2);
  });
  test('bank sheet completion only returns reloaded server state', () async {
    var handled = 0, reads = 0;
    final action = GuardianBankAction(
      request: (id, attempt) async {
        expect(id, registrationId);
        expect(attempt, attemptId);
        return receipt();
      },
      authenticate: (_) async {
        handled++;
      },
      reload: () async {
        reads++;
        return state(GuardianRegistrationPaymentState.processing);
      },
    );
    final result = await action.run(
      state(GuardianRegistrationPaymentState.requiresAction),
    );
    expect(handled, 1);
    expect(reads, 1);
    expect(result!.hasConfirmedImpact, false);
    expect(result.paymentState, GuardianRegistrationPaymentState.processing);
  });
  test('SDK cancellation or lost request rechecks server without a retry or payment failure', () async {
    for (final loseRequest in [true, false]) {
      var requests = 0, handled = 0, reads = 0;
      final action = GuardianBankAction(
        request: (_, _) async {
          requests++;
          if (loseRequest) throw StateError('synthetic loss');
          return receipt();
        },
        authenticate: (_) async {
          handled++;
          throw StateError('synthetic close');
        },
        reload: () async {
          reads++;
          return state(GuardianRegistrationPaymentState.processing);
        },
      );
      final result = await action.run(
        state(GuardianRegistrationPaymentState.requiresAction),
      );
      expect(result!.paymentState, GuardianRegistrationPaymentState.processing);
      expect(requests, 1);
      expect(handled, loseRequest ? 0 : 1);
      expect(reads, 1);
    }
  });
  test('mismatched receipt never opens bank SDK and stale canceled registration is refused', () async {
    var handled = 0, requests = 0;
    final action = GuardianBankAction(
      request: (_, _) async {
        requests++;
        return {...receipt(), 'attempt_id': 'foreign'};
      },
      authenticate: (_) async {
        handled++;
      },
      reload: () async => state(GuardianRegistrationPaymentState.processing),
    );
    await action.run(state(GuardianRegistrationPaymentState.requiresAction));
    expect(handled, 0);
    expect(requests, 1);
    await expectLater(
      action.run(
        state(
          GuardianRegistrationPaymentState.requiresAction,
          status: 'canceled',
        ),
      ),
      throwsFormatException,
    );
    expect(requests, 1);
  });
  test('double tap shares one request and one SDK action, impact only from server allocation', () async {
    final gate = Completer<void>();
    var requests = 0, handled = 0;
    final action = GuardianBankAction(
      request: (_, _) async {
        requests++;
        await gate.future;
        return receipt();
      },
      authenticate: (_) async {
        handled++;
      },
      reload: () async => state(GuardianRegistrationPaymentState.allocated),
    );
    final registration = state(GuardianRegistrationPaymentState.requiresAction);
    final first = action.run(registration), second = action.run(registration);
    expect(identical(first, second), true);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(requests, 1);
    expect(handled, 1);
    expect(results.first!.hasConfirmedImpact, true);
  });
}
