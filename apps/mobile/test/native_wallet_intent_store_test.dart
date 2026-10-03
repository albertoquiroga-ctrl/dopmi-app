import 'dart:convert';

import 'package:dopmi_mobile/features/payments/native_wallet_intent_store.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = '00000000-0000-4000-8000-000000000001';
  final intent = {
    'key': key,
    'wallet_type': 'google_pay',
    'consent_version': savedCardConsent,
  };
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'owner recovery keeps stable minimal intent without SDK secrets',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final owner = NativeWalletIntentStore(prefs, 'owner');
      expect(
        await owner.reserve({
          ...intent,
          'setup_client_secret': 'must-not-store',
          'customer_id': 'private',
        }),
        intent,
      );
      expect(NativeWalletIntentStore(prefs, 'peer').read(), null);
      expect(NativeWalletIntentStore(prefs, 'owner').read(), intent);
      expect(await owner.reserve(intent), intent);
      expect(
        jsonDecode(prefs.getString('dopmi-native-wallet:owner:intent')!),
        intent,
      );
      await expectLater(
        owner.reserve({
          ...intent,
          'key': '00000000-0000-4000-8000-000000000002',
        }),
        throwsFormatException,
      );
      await expectLater(
        owner.reserve({...intent, 'wallet_type': 'apple_pay'}),
        throwsFormatException,
      );
      expect(owner.read(), intent);
    },
  );
  test(
    'sheet cancellation and late or foreign receipts retain pending intent',
    () async {
      final owner = NativeWalletIntentStore(
        await SharedPreferences.getInstance(),
        'owner',
      );
      await owner.reserve(intent);
      final receipt = {
        'key': key,
        'wallet_type': 'google_pay',
        'status': 'pending',
        'card_id': null,
      };
      for (final change in [
        <String, dynamic>{},
        {'status': 'attention'},
        {'key': '00000000-0000-4000-8000-000000000002', 'status': 'expired'},
        {'wallet_type': 'apple_pay', 'status': 'expired'},
        {'status': 'saved'},
      ]) {
        await expectLater(
          owner.finish({...receipt, ...change}),
          throwsFormatException,
        );
        expect(owner.read(), intent);
      }
      await owner.finish({
        ...receipt,
        'status': 'saved',
        'card_id': 'pm_fixture',
      });
      expect(owner.read(), null);
      await owner.reserve(intent);
      await owner.finish({...receipt, 'status': 'expired'});
      expect(owner.read(), null);
    },
  );
  test(
    'corrupted saved intent is not silently replaced with a new authorization',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dopmi-native-wallet:owner:intent', '{broken');
      final owner = NativeWalletIntentStore(prefs, 'owner');
      await expectLater(owner.reserve(intent), throwsFormatException);
      expect(prefs.getString('dopmi-native-wallet:owner:intent'), '{broken');
    },
  );
}
