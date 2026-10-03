import 'dart:convert';
import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_payment_card.dart';
import 'package:dopmi_mobile/features/payments/native_wallet_repository.dart';
import 'package:dopmi_mobile/features/payments/native_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'guardian_test.dart' show FakeGuardian;
import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class FakeWallet extends NativeWalletRepository {
  FakeWallet()
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  Json? receipt;
  bool fail = false;
  Completer<Json>? response;
  final calls = <Json>[];
  @override
  Future<Json?> state() async => receipt;
  @override
  Future<Json> submit(Json intent) async {
    calls.add(Json.from(intent));
    receipt = {
      'key': intent['key'],
      'wallet_type': intent['wallet_type'],
      'status': 'pending',
      'card_id': null,
    };
    if (response != null) return response!.future;
    if (fail) throw StateError('lost reply');
    return {...receipt!, 'setup_client_secret': 'seti_fixture_secret_fixture'};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<FakeIdentityRepository> start(
    WidgetTester tester,
    FakeGuardian cards,
    FakeWallet wallet, {
    List<String>? sdkCalls,
    bool nativeSucceeds = false,
  }) async {
    final identity = FakeIdentityRepository()
      ..user = Identity('one', 'one@example.test', verified: true);
    final sdk = NativeWalletSdk(
      publishableKey: 'pk_test_fixture',
      enabled: true,
      platform: TargetPlatform.android,
      web: false,
      initialize: (key, merchant) async {},
      supported: (params) async => true,
      confirm: (secret, params) async {
        sdkCalls?.add(secret);
        if (nativeSucceeds) return;
        throw StateError('native sheet canceled');
      },
    );
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        guardianRepositoryProvider.overrideWithValue(cards),
        guardianEnabledProvider.overrideWithValue(true),
        nativeWalletRepositoryProvider.overrideWithValue(wallet),
        nativeWalletSdkProvider.overrideWithValue(sdk),
        routerInitialLocationProvider.overrideWithValue(
          '/settings/payment-methods',
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    return identity;
  }

  for (final lost in [false, true]) {
    testWidgets(
      'wallet ${lost ? 'lost response' : 'native cancel'} retains same intent and blocks card changes',
      (tester) async {
        final cards = FakeGuardian();
        final wallet = FakeWallet()..fail = lost;
        await start(tester, cards, wallet);
        await tester.ensureVisible(find.text('Google Pay'));
        await tester.tap(find.text('Google Pay'));
        await tester.pumpAndSettle();
        expect(wallet.calls, isEmpty);
        await tester.tap(find.text('Guardar y continuar'));
        await tester.pumpAndSettle();
        expect(wallet.calls, hasLength(1));
        final original = Json.from(wallet.calls.single);
        final prefs = await SharedPreferences.getInstance();
        expect(
          jsonDecode(prefs.getString('dopmi-native-wallet:one:intent')!),
          original,
        );
        expect(find.text('Google Pay vinculado'), findsNothing);
        final add = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Agregar tarjeta'),
        );
        expect(add.onPressed, null);
        await tester.ensureVisible(find.text('Continuar autorización'));
        await tester.tap(find.text('Continuar autorización'));
        await tester.pumpAndSettle();
        expect(wallet.calls, hasLength(2));
        expect(wallet.calls.last, original);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }
  testWidgets(
    'native return waits for server confirmation with the same intent',
    (tester) async {
      final wallet = FakeWallet();
      final sdkCalls = <String>[];
      await start(
        tester,
        FakeGuardian(),
        wallet,
        sdkCalls: sdkCalls,
        nativeSucceeds: true,
      );
      await tester.ensureVisible(find.text('Google Pay'));
      await tester.tap(find.text('Google Pay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar y continuar'));
      await tester.pumpAndSettle();
      expect(sdkCalls, ['seti_fixture_secret_fixture']);
      expect(wallet.calls, hasLength(2));
      expect(wallet.calls.last, wallet.calls.first);
      expect(find.text('Google Pay vinculado'), findsNothing);
      expect(find.text('Continuar autorización'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('dopmi-native-wallet:one:intent')!),
        wallet.calls.first,
      );
    },
  );
  testWidgets('saved wallet waits for fresh matching card and announces once', (
    tester,
  ) async {
    const key = '00000000-0000-4000-8000-000000000001';
    SharedPreferences.setMockInitialValues({
      'dopmi-native-wallet:one:intent': jsonEncode({
        'key': key,
        'wallet_type': 'google_pay',
        'consent_version': savedCardConsent,
      }),
    });
    final cards = FakeGuardian();
    final wallet = FakeWallet()
      ..receipt = {
        'key': key,
        'wallet_type': 'google_pay',
        'status': 'saved',
        'card_id': 'pm_fixture',
      };
    await start(tester, cards, wallet);
    expect(find.text('Google Pay vinculado'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dopmi-native-wallet:one:intent'), isNotNull);
    cards.cards = [
      const GuardianPaymentCard(
        id: 'pm_fixture',
        brand: 'visa',
        last4: '4242',
        wallet: 'google_pay',
        isDefault: false,
      ),
    ];
    await tester.ensureVisible(find.text('Actualizar estado'));
    await tester.tap(find.text('Actualizar estado'));
    await tester.pumpAndSettle();
    expect(prefs.getString('dopmi-native-wallet:one:intent'), null);
    expect(find.text('Google Pay vinculado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Actualizar estado'));
    await tester.tap(find.text('Actualizar estado'));
    await tester.pumpAndSettle();
    expect(find.text('Google Pay vinculado'), findsNothing);
  });
  testWidgets(
    'attention restores one intent and disables native authorization',
    (tester) async {
      const key = '00000000-0000-4000-8000-000000000001';
      final wallet = FakeWallet()
        ..receipt = {
          'key': key,
          'wallet_type': 'google_pay',
          'status': 'attention',
          'card_id': null,
        };
      await start(tester, FakeGuardian(), wallet);
      expect(
        find.text(
          'La autorización de tu billetera requiere revisión. Conservamos tu solicitud.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continuar autorización'), findsNothing);
      final google = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Google Pay'),
      );
      expect(google.onPressed, null);
      expect(wallet.calls, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('dopmi-native-wallet:one:intent')!)['key'],
        key,
      );
    },
  );
  testWidgets(
    'sign-out while wallet reply is in flight prevents SDK and keeps owner intent',
    (tester) async {
      final wallet = FakeWallet()..response = Completer<Json>();
      final sdkCalls = <String>[];
      final identity = await start(
        tester,
        FakeGuardian(),
        wallet,
        sdkCalls: sdkCalls,
      );
      await tester.ensureVisible(find.text('Google Pay'));
      await tester.tap(find.text('Google Pay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar y continuar'));
      await tester.pump();
      expect(wallet.calls, hasLength(1));
      identity.emit(const IdentityEvent(null));
      await tester.pump();
      wallet.response!.complete({
        ...wallet.receipt!,
        'setup_client_secret': 'seti_fixture_secret_fixture',
      });
      await tester.pumpAndSettle();
      expect(sdkCalls, isEmpty);
      expect(find.text('Google Pay vinculado'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dopmi-native-wallet:one:intent'), isNotNull);
      expect(prefs.getString('dopmi-native-wallet:peer:intent'), null);
    },
  );
}
