import 'dart:async';

import 'package:dopmi_mobile/features/payments/guardian_method_setup.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/independent_card_setup.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guardian_test.dart' show FakeGuardian;

const setupSecret = 'seti_synthetic_secret_synthetic';
bool currentOwner() => true;

const independentKey = '00000000-0000-4000-8000-000000000099';
const independentIntent = <String, dynamic>{
  'kind': 'add_card',
  'key': independentKey,
  'consent_version': savedCardConsent,
  'presentation': 'native_card',
};
Json independentReceipt({
  String status = 'pending',
  String presentation = 'native_card',
}) => {
  'key': independentKey,
  'status': status,
  'card_id': status == 'saved' ? 'pm_added' : null,
  'presentation': presentation,
  'add_only': true,
  'default_unchanged': true,
};

class IndependentSetupRepository extends FakeGuardian {
  final checked = <String>[];
  bool rejectCreate = false;
  Json? checkedReceipt = independentReceipt(status: 'saved');
  Json startReceipt = {
    ...independentReceipt(),
    'method_status': 'requires_payment_method',
    'setup_client_secret': setupSecret,
  };

  @override
  Future<Json> submit(Json intent) async {
    calls.add(Json.from(intent));
    if (rejectCreate) throw StateError('uncertain response');
    return startReceipt;
  }

  @override
  Future<Json?> nativeSavedCardStatus(String key) async {
    checked.add(key);
    return checkedReceipt;
  }
}

class IndependentSetupSdk implements GuardianMethodSetup {
  @override
  bool available = true;
  bool fail = false;
  int calls = 0;
  final started = Completer<void>();
  Completer<void>? gate;

  @override
  Future<void> present(
    String secret, {
    required bool Function() current,
  }) async {
    expect(secret, setupSecret);
    if (!current()) return;
    calls++;
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    if (fail) throw StateError('native cancellation or uncertainty');
  }
}

void main() {
  test('independent card setup uses the native component and confirms only the same request', () async {
    final repo = IndependentSetupRepository();
    final sdk = IndependentSetupSdk();
    final result = await IndependentCardSetup(
      repository: repo,
      sdk: sdk,
    ).run(independentIntent, current: currentOwner);
    expect(sdk.calls, 1);
    expect(repo.checked, [independentKey]);
    expect(repo.calls.single, independentIntent);
    expect(repo.opened, 0);
    expect(result!.receipt, independentReceipt(status: 'saved'));
    expect(result.receipt.containsKey('setup_client_secret'), isFalse);
    expect(result.uncertain, isFalse);
  });

  test('native cancellation retains the request and never falls back to hosted checkout', () async {
    final repo = IndependentSetupRepository()
      ..checkedReceipt = independentReceipt();
    final sdk = IndependentSetupSdk()..fail = true;
    final setup = IndependentCardSetup(repository: repo, sdk: sdk);
    final uncertain = await setup.run(independentIntent, current: currentOwner);
    expect(uncertain!.uncertain, isTrue);
    expect(repo.checked, [independentKey]);
    expect(repo.opened, 0);
    sdk.fail = false;
    repo.checkedReceipt = independentReceipt(status: 'saved');
    final confirmed = await setup.run(independentIntent, current: currentOwner);
    expect(confirmed!.receipt['status'], 'saved');
    expect(repo.calls.map((value) => value['key']), [
      independentKey,
      independentKey,
    ]);
    expect(repo.checked, [independentKey, independentKey]);
    expect(repo.opened, 0);
  });

  test('an uncertain creation response consults the same request without presenting again', () async {
    final repo = IndependentSetupRepository()..rejectCreate = true;
    final sdk = IndependentSetupSdk();
    final setup = IndependentCardSetup(repository: repo, sdk: sdk);
    final result = await setup.run(independentIntent, current: currentOwner);
    expect(repo.checked, [independentKey]);
    expect(result!.receipt['status'], 'saved');
    expect(sdk.calls, 0);
    expect(repo.opened, 0);
    repo.checkedReceipt = null;
    await expectLater(
      setup.run(independentIntent, current: currentOwner),
      throwsFormatException,
    );
    expect(repo.calls.map((value) => value['key']), [
      independentKey,
      independentKey,
    ]);
    expect(sdk.calls, 0);
  });

  test(
    'persisted native setup stays native when its SDK is unavailable',
    () async {
      final repo = IndependentSetupRepository()
        ..checkedReceipt = independentReceipt();
      final sdk = IndependentSetupSdk()..available = false;
      final result = await IndependentCardSetup(
        repository: repo,
        sdk: sdk,
      ).run(independentIntent, current: currentOwner);
      expect(result!.uncertain, isTrue);
      expect(repo.checked, [independentKey]);
      expect(repo.opened, 0);
      expect(sdk.calls, 0);
    },
  );

  test('a known legacy hosted setup preserves its channel even when native SDK is available', () async {
    final repo = IndependentSetupRepository()
      ..startReceipt = {
        ...independentReceipt(presentation: 'hosted_checkout'),
        'checkout_url': 'https://checkout.stripe.com/setup',
      };
    final sdk = IndependentSetupSdk();
    final legacy = {...independentIntent}..remove('presentation');
    await IndependentCardSetup(
      repository: repo,
      sdk: sdk,
    ).run(legacy, current: currentOwner);
    expect(repo.calls.single['key'], independentKey);
    expect(repo.opened, 1);
    expect(repo.checked, isEmpty);
    expect(sdk.calls, 0);
  });

  test(
    'changing owner during native presentation prevents later reconciliation',
    () async {
      final repo = IndependentSetupRepository();
      final sdk = IndependentSetupSdk()..gate = Completer<void>();
      var current = true;
      final result = IndependentCardSetup(
        repository: repo,
        sdk: sdk,
      ).run(independentIntent, current: () => current);
      await sdk.started.future;
      current = false;
      sdk.gate!.complete();
      expect(await result, isNull);
      expect(repo.checked, isEmpty);
      expect(repo.opened, 0);
    },
  );

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
        // Android uses this palette for both system themes, so light surfaces
        // must not inherit white labels, placeholders or close icons at night.
        expect(
          value.toJson()['appearance']['colors'],
          containsPair('secondaryText', '#FF7A655C'),
        );
        expect(
          value.toJson()['appearance']['colors'],
          containsPair('placeholderText', '#FF7A655C'),
        );
        expect(
          value.toJson()['appearance']['colors'],
          containsPair('icon', '#FF46281D'),
        );
        expect(
          value.toJson()['appearance']['colors'],
          containsPair('background', '#FFFFFFFF'),
        );
        expect(
          value.toJson()['appearance']['colors'],
          containsPair('componentBackground', '#FFFFFFFF'),
        );
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
