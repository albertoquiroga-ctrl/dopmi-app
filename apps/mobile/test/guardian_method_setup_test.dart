import 'dart:async';

import 'package:dopmi_mobile/features/payments/guardian_method_setup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';

const setupSecret = 'seti_synthetic_secret_synthetic';
bool currentOwner() => true;

void main() {
  test(
    'native setup refuses live, disabled, web and unsupported platforms',
    () async {
      var calls = 0;
      for (final config in [
        (
          key: 'pk_live_synthetic',
          enabled: true,
          web: false,
          platform: TargetPlatform.android,
        ),
        (
          key: 'pk_test_synthetic',
          enabled: false,
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
        final sdk = GuardianMethodSetupSdk(
          publishableKey: config.key,
          enabled: config.enabled,
          web: config.web,
          platform: config.platform,
          initialize: (_, _) async {
            calls++;
          },
          prepare: (_) async {
            calls++;
          },
          show: () async {
            calls++;
          },
        );
        expect(sdk.available, false);
        await expectLater(
          sdk.present(setupSecret, current: currentOwner),
          throwsFormatException,
        );
      }
      expect(calls, 0);
    },
  );

  test(
    'native setup accepts only SetupIntent and configures Dopmi secure sheet',
    () async {
      var initializations = 0, shown = 0;
      final parameters = <SetupPaymentSheetParameters>[];
      final sdk = GuardianMethodSetupSdk(
        publishableKey: 'pk_test_synthetic',
        merchantId: 'merchant.synthetic',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        initialize: (key, merchant) async {
          expect(key, 'pk_test_synthetic');
          expect(merchant, 'merchant.synthetic');
          initializations++;
        },
        prepare: (value) async {
          parameters.add(value);
        },
        show: () async {
          shown++;
        },
      );
      for (final invalid in [
        'secret',
        'pi_synthetic_secret_synthetic',
        '$setupSecret\n',
      ]) {
        await expectLater(
          sdk.present(invalid, current: currentOwner),
          throwsFormatException,
        );
      }
      await sdk.present(setupSecret, current: currentOwner);
      await sdk.present(setupSecret, current: currentOwner);
      expect(initializations, 1);
      expect(shown, 2);
      for (final value in parameters) {
        expect(value.setupIntentClientSecret, setupSecret);
        expect(value.paymentIntentClientSecret, isNull);
        expect(value.customerId, isNull);
        expect(value.customerEphemeralKeySecret, isNull);
        expect(value.customFlow, false);
        expect(value.allowsDelayedPaymentMethods, false);
        expect(value.merchantDisplayName, 'Dopmi');
        expect(value.returnURL, 'io.dopmi.app://payments/return');
      }
    },
  );

  test(
    'one sheet at a time and close releases only the local SDK lock',
    () async {
      final gate = Completer<void>();
      var sheets = 0;
      final sdk = GuardianMethodSetupSdk(
        publishableKey: 'pk_test_synthetic',
        enabled: true,
        web: false,
        platform: TargetPlatform.iOS,
        initialize: (_, _) async {},
        prepare: (_) async {},
        show: () {
          sheets++;
          return gate.future;
        },
      );
      final first = sdk.present(setupSecret, current: currentOwner);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        sdk.present(setupSecret, current: currentOwner),
        throwsFormatException,
      );
      expect(sheets, 1);
      final stopped = expectLater(first, throwsStateError);
      gate.completeError(StateError('synthetic sheet closed'));
      await stopped;
      expect(sdk.available, true);
    },
  );

  for (final boundary in [
    'before initialization',
    'initialization',
    'prepare',
  ]) {
    test('owner or route loss at $boundary never opens the setup sheet', () async {
      final initialized = Completer<void>();
      final prepared = Completer<void>();
      var current = boundary != 'before initialization';
      var initializations = 0, preparations = 0, shown = 0;
      final sdk = GuardianMethodSetupSdk(
        publishableKey: 'pk_test_synthetic',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        initialize: (_, _) {
          initializations++;
          return initialized.future;
        },
        prepare: (_) {
          preparations++;
          return prepared.future;
        },
        show: () async {
          shown++;
        },
      );
      final presentation = sdk.present(setupSecret, current: () => current);
      if (boundary == 'prepare') {
        initialized.complete();
        await Future<void>.delayed(Duration.zero);
        expect(preparations, 1);
      }
      current = false;
      if (!initialized.isCompleted) initialized.complete();
      prepared.complete();
      await presentation;
      expect(initializations, boundary == 'before initialization' ? 0 : 1);
      expect(preparations, boundary == 'prepare' ? 1 : 0);
      expect(shown, 0);
      // An abandoned UI operation must release its SDK lock for a later owner.
      await sdk.present(setupSecret, current: currentOwner);
      expect(shown, 1);
    });
  }
}
