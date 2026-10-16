import 'dart:async';

import 'package:dopmi_mobile/features/payments/oneoff_payment_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';

bool currentOwner() => true;

void main() {
  const secret = 'pi_synthetic_secret_synthetic';
  test(
    'oneoff sheet accepts only test native PaymentIntent and keeps saving off',
    () async {
      final prepared = <SetupPaymentSheetParameters>[];
      var initialized = 0, shown = 0;
      final sheet = OneoffPaymentSheetSdk(
        publishableKey: 'pk_test_synthetic',
        platform: TargetPlatform.android,
        web: false,
        initialize: (_, _) async {
          initialized++;
        },
        prepare: (value) async {
          prepared.add(value);
        },
        show: () async {
          shown++;
        },
      );
      await expectLater(
        sheet.present('seti_synthetic_secret_synthetic', current: currentOwner),
        throwsFormatException,
      );
      await sheet.present(secret, current: currentOwner);
      await sheet.present(secret, current: currentOwner);
      expect(initialized, 1);
      expect(shown, 2);
      for (final parameters in prepared) {
        expect(parameters.paymentIntentClientSecret, secret);
        expect(parameters.setupIntentClientSecret, isNull);
        expect(parameters.customerId, isNull);
        expect(parameters.customerEphemeralKeySecret, isNull);
        expect(parameters.allowsDelayedPaymentMethods, false);
        expect(parameters.merchantDisplayName, 'Dopmi');
        expect(parameters.returnURL, 'io.dopmi.app://payments/return');
        // The same native palette must stay legible in Android night mode.
        expect(
          parameters.toJson()['appearance']['colors'],
          containsPair('secondaryText', '#FF554E48'),
        );
        expect(
          parameters.toJson()['appearance']['colors'],
          containsPair('placeholderText', '#FF554E48'),
        );
        expect(
          parameters.toJson()['appearance']['colors'],
          containsPair('icon', '#FF15110D'),
        );
        expect(
          parameters.toJson()['appearance']['colors'],
          containsPair('background', '#FFFFFFFF'),
        );
        expect(
          parameters.toJson()['appearance']['colors'],
          containsPair('componentBackground', '#FFFFFFFF'),
        );
      }
    },
  );
  test('live keys, web and desktop cannot open a payment sheet', () async {
    for (final config in [
      (key: 'pk_live_synthetic', platform: TargetPlatform.android, web: false),
      (key: 'pk_test_synthetic', platform: TargetPlatform.android, web: true),
      (key: 'pk_test_synthetic', platform: TargetPlatform.windows, web: false),
    ]) {
      final sheet = OneoffPaymentSheetSdk(
        publishableKey: config.key,
        platform: config.platform,
        web: config.web,
      );
      expect(sheet.available, false);
      await expectLater(
        sheet.present(secret, current: currentOwner),
        throwsFormatException,
      );
    }
  });
  test('one payment sheet at a time; close does not create a second local authorization', () async {
    final gate = Completer<void>();
    var shown = 0;
    final sheet = OneoffPaymentSheetSdk(
      publishableKey: 'pk_test_synthetic',
      platform: TargetPlatform.iOS,
      web: false,
      initialize: (_, _) async {},
      prepare: (_) async {},
      show: () {
        shown++;
        return gate.future;
      },
    );
    final first = sheet.present(secret, current: currentOwner);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      sheet.present(secret, current: currentOwner),
      throwsFormatException,
    );
    expect(shown, 1);
    gate.complete();
    await first;
  });

  for (final boundary in [
    'before initialization',
    'initialization',
    'prepare',
  ]) {
    test(
      'owner or route loss at $boundary never opens the payment sheet',
      () async {
        final initialized = Completer<void>();
        final prepared = Completer<void>();
        var current = boundary != 'before initialization';
        var initializations = 0, preparations = 0, shown = 0;
        final sdk = OneoffPaymentSheetSdk(
          publishableKey: 'pk_test_synthetic',
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
        final presentation = sdk.present(secret, current: () => current);
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
        await sdk.present(secret, current: currentOwner);
        expect(shown, 1);
      },
    );
  }
}
