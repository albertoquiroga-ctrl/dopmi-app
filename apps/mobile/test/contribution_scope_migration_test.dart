import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/oneoff_payment_sheet.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'payments_test.dart' show FakePayments, FakeOneoffSheet, tapButton;
import 'rescue_test.dart' show FakeRescue;

class AliasRescue extends FakeRescue {
  int resolutions = 0;
  bool withdrawn = false;
  @override
  Future<RescueRecord?> publicCaseRecordForExpense(String expense) async {
    resolutions++;
    if (withdrawn) {
      throw StateError('Public history must not gate an old payment');
    }
    return super.publicCaseRecordForExpense(expense);
  }
}

class AliasPayments extends FakePayments {
  final legacy = <(String, int, String)>[];
  bool historicalConfirmed = false, visibleReceipt = false;
  String receiptOwner = 'one', receiptExpense = 'expense-one';
  Completer<Json?>? pendingReceipt;
  int fundingReads = 0;
  Json? checkoutReply;
  @override
  Future<Json> funding(String expense) {
    fundingReads++;
    return super.funding(expense);
  }

  @override
  Future<Json> checkout(String expense, int cents, String key) async {
    legacy.add((expense, cents, key));
    if (checkoutReply != null) return checkoutReply!;
    throw StateError('Lost response');
  }

  @override
  Future<Json> caseCheckout(String caseId, int cents, String key) async {
    caseCalls.add((caseId, cents, key));
    throw StateError('Lost response');
  }

  @override
  Future<Json?> outcome(String expense, String key) async {
    if (pendingReceipt != null) return pendingReceipt!.future;
    return historicalConfirmed || visibleReceipt
        ? {
            'id': 'donation-one',
            'donor_id': receiptOwner,
            'expense_id': receiptExpense,
            'contribution_scope': 'expense',
            'currency': 'mxn',
            'idempotency_key': key,
            'payment_status': historicalConfirmed ? 'confirmed' : 'pending',
            'payment_state': 'requires_action',
            'gross_cents': 7525,
            'allocated_cents': historicalConfirmed ? 7000 : 0,
            'transfer_status': 'pending',
          }
        : null;
  }
}

class GateSheet extends FakeOneoffSheet {
  final gate = Completer<void>();
  @override
  Future<void> present(
    String secret, {
    required bool Function() current,
  }) async {
    await gate.future;
  }
}

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    AliasPayments payments,
    AliasRescue rescue, {
    Map<String, Object> stored = const {},
    Json? attempt,
    bool settle = true,
    FakeOneoffSheet? sheet,
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        paymentRepositoryProvider.overrideWithValue(payments),
        rescueRepositoryProvider.overrideWithValue(rescue),
        oneoffPaymentSheetProvider.overrideWithValue(
          sheet ?? FakeOneoffSheet(),
        ),
        routerInitialLocationProvider.overrideWithValue(
          attempt == null
              ? '/contribute/expense-one?case=forged&amount_cents=1234'
              : '/payments',
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
    if (attempt != null) {
      container
          .read(routerProvider)
          .push(
            '/contribute/expense-one?case=retired&amount_cents=99999',
            extra: attempt,
          );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }
    return container;
  }

  testWidgets(
    'fresh expense alias resolves real case and amount without creating or charging an expense attempt',
    (tester) async {
      final payments = AliasPayments();
      final rescue = AliasRescue();
      final container = await start(tester, payments, rescue);
      expect(
        container.read(routerProvider).state.uri.path,
        '/contribute-case/case-one',
      );
      expect(
        container
            .read(routerProvider)
            .state
            .uri
            .queryParameters['amount_cents'],
        '1234',
      );
      expect(rescue.resolutions, 1);
      expect(payments.caseCalls, isEmpty);
      expect(payments.legacy, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('dopmi-payment:one:expense-one:key'), isFalse);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pumpAndSettle();
      expect(payments.caseCalls.single.$1, 'case-one');
      expect(payments.caseCalls.single.$2, 1234);
      expect(payments.legacy, isEmpty);
    },
  );
  testWidgets(
    'partial durable legacy state blocks migration and preserves its uncertain key',
    (tester) async {
      final payments = AliasPayments();
      final rescue = AliasRescue();
      final container = await start(
        tester,
        payments,
        rescue,
        stored: {'dopmi-payment:one:expense-one:key': 'prior-request-key'},
      );
      expect(
        container.read(routerProvider).state.uri.path,
        '/contribute/expense-one',
      );
      expect(rescue.resolutions, 0);
      expect(payments.caseCalls, isEmpty);
      expect(payments.legacy, isEmpty);
      expect(find.text('Ir al historial'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-payment:one:expense-one:key',
        ),
        'prior-request-key',
      );
    },
  );
  for (final useUrl in [false, true]) {
    testWidgets(
      'withdrawn public case retains historical expense key and gross; url=$useUrl',
      (tester) async {
        final payments = AliasPayments()..visibleReceipt = useUrl;
        final rescue = AliasRescue()..withdrawn = true;
        final attempt = <String, dynamic>{
          'id': 'donation-one',
          'idempotency_key': 'historical-request-key',
          'gross_cents': 99999,
        };
        final container = await start(
          tester,
          payments,
          rescue,
          stored: useUrl
              ? {}
              : {
                  'dopmi-payment:one:expense-one:key': 'historical-request-key',
                  'dopmi-payment:one:expense-one:cents': 7525,
                },
          attempt: useUrl ? attempt : null,
        );
        expect(
          container.read(routerProvider).state.uri.path,
          '/contribute/expense-one',
        );
        expect(rescue.resolutions, 0);
        expect(payments.fundingReads, 0);
        await tapButton(
          tester,
          useUrl ? 'Continuar la misma aportación' : 'Continuar mi aportación',
        );
        await tester.pumpAndSettle();
        expect(payments.legacy.single, (
          'expense-one',
          7525,
          'historical-request-key',
        ));
        expect(payments.caseCalls, isEmpty);
        payments.historicalConfirmed = true;
        await tester.tap(find.text('Consultar resultado'));
        await tester.pumpAndSettle();
        expect(find.text('Pago exitoso'), findsOneWidget);
        expect(rescue.resolutions, 0);
      },
    );
  }
  for (final invalid in ['owner', 'target', 'absent']) {
    testWidgets(
      'URL history extra requires an owned financial receipt: $invalid',
      (tester) async {
        final payments = AliasPayments()..visibleReceipt = invalid != 'absent';
        if (invalid == 'owner') payments.receiptOwner = 'previous-actor';
        if (invalid == 'target') payments.receiptExpense = 'another-expense';
        final rescue = AliasRescue()..withdrawn = true;
        await start(
          tester,
          payments,
          rescue,
          attempt: {
            'id': 'donation-one',
            'idempotency_key': 'old-extra-key',
            'gross_cents': 1234,
          },
        );
        expect(find.text('Ir al historial'), findsOneWidget);
        expect(find.text('Continuar mi aportación'), findsNothing);
        expect(find.text('Continuar la misma aportación'), findsNothing);
        expect(payments.caseCalls, isEmpty);
        expect(payments.legacy, isEmpty);
        expect(rescue.resolutions, 0);
        expect(payments.fundingReads, 0);
        expect(
          (await SharedPreferences.getInstance()).getKeys().where(
            (key) => key.startsWith('dopmi-payment:'),
          ),
          isEmpty,
        );
      },
    );
  }
  testWidgets(
    'late receipt for previous actor cannot authorize reused route extra after identity changes',
    (tester) async {
      final pending = Completer<Json?>();
      final payments = AliasPayments()..pendingReceipt = pending;
      final rescue = AliasRescue()..withdrawn = true;
      final container = await start(
        tester,
        payments,
        rescue,
        settle: false,
        attempt: {
          'id': 'donation-one',
          'idempotency_key': 'old-extra-key',
          'gross_cents': 1234,
        },
      );
      final identity =
          container.read(identityRepositoryProvider) as FakeIdentityRepository;
      identity.profile = const Profile(
        id: 'two',
        name: 'Segunda',
        phone: '',
        city: '',
        mode: 'donor',
        intent: 'adopt',
        status: 'active',
        termsVersion: currentTermsVersion,
        privacyVersion: currentPrivacyVersion,
        adultConfirmed: true,
      );
      identity.emit(
        const IdentityEvent(
          Identity('two', 'second@example.test', verified: true),
        ),
      );
      // The app resets its navigation session on identity change and may mount
      // the old path as a fresh link without extras. That new owner's public
      // lookup is independent of authorizing the old receipt. Replay the same
      // historical extra explicitly under the new identity to test that seam.
      await tester.pumpAndSettle();
      final freshReads = rescue.resolutions;
      container
          .read(routerProvider)
          .replace(
            '/contribute/expense-one?case=retired&resume=old-extra-key',
            extra: {
              'id': 'donation-one',
              'idempotency_key': 'old-extra-key',
              'gross_cents': 1234,
            },
          );
      await tester.pump();
      pending.complete({
        'id': 'donation-one',
        'donor_id': 'one',
        'expense_id': 'expense-one',
        'contribution_scope': 'expense',
        'currency': 'mxn',
        'idempotency_key': 'old-extra-key',
        'gross_cents': 7525,
        'payment_status': 'pending',
        'payment_state': 'requires_action',
      });
      await tester.pumpAndSettle();
      expect(find.text('Continuar mi aportación'), findsNothing);
      expect(find.text('Continuar la misma aportación'), findsNothing);
      expect(payments.caseCalls, isEmpty);
      expect(payments.legacy, isEmpty);
      expect(rescue.resolutions, freshReads);
    },
  );

  testWidgets(
    'partial URL extra never falls back to complete durable evidence',
    (tester) async {
      final payments = AliasPayments()..visibleReceipt = true;
      final rescue = AliasRescue()..withdrawn = true;
      await start(
        tester,
        payments,
        rescue,
        stored: {
          'dopmi-payment:one:expense-one:key': 'separate-durable-key',
          'dopmi-payment:one:expense-one:cents': 7525,
        },
        attempt: {'idempotency_key': 'partial-extra-key'},
      );
      expect(find.text('Continuar mi aportación'), findsNothing);
      expect(find.text('Continuar la misma aportación'), findsNothing);
      expect(payments.legacy, isEmpty);
      expect(payments.caseCalls, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-payment:one:expense-one:key',
        ),
        'separate-durable-key',
      );
    },
  );
  testWidgets(
    'owned URL receipt cannot overwrite or clear another uncertain durable attempt',
    (tester) async {
      final payments = AliasPayments()..visibleReceipt = true;
      final rescue = AliasRescue()..withdrawn = true;
      await start(
        tester,
        payments,
        rescue,
        stored: {
          'dopmi-payment:one:expense-one:key': 'other-durable-key',
          'dopmi-payment:one:expense-one:cents': 1234,
        },
        attempt: {
          'id': 'donation-one',
          'idempotency_key': 'owned-url-key',
          'gross_cents': 99999,
        },
      );
      await tapButton(tester, 'Continuar la misma aportación');
      await tester.pumpAndSettle();
      expect(payments.legacy, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('dopmi-payment:one:expense-one:key'),
        'other-durable-key',
      );
      payments.historicalConfirmed = true;
      await tester.tap(find.text('Consultar resultado'));
      await tester.pumpAndSettle();
      expect(find.text('Pago exitoso'), findsOneWidget);
      expect(
        prefs.getString('dopmi-payment:one:expense-one:key'),
        'other-durable-key',
      );
      expect(prefs.getInt('dopmi-payment:one:expense-one:cents'), 1234);
    },
  );
  testWidgets(
    'Android Back remains blocked while recovered expense attempt initializes SDK',
    (tester) async {
      final payments = AliasPayments()
        ..checkoutReply = {
          'payment_client_secret': 'pi_fixture_secret_fixture',
        };
      final sheet = GateSheet();
      final container = await start(
        tester,
        payments,
        AliasRescue()..withdrawn = true,
        sheet: sheet,
        stored: {
          'dopmi-payment:one:expense-one:key': 'historical-request-key',
          'dopmi-payment:one:expense-one:cents': 7525,
        },
      );
      await tapButton(tester, 'Continuar mi aportación');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        container.read(routerProvider).state.uri.path,
        '/contribute/expense-one',
      );
      expect(payments.legacy, [
        ('expense-one', 7525, 'historical-request-key'),
      ]);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-payment:one:expense-one:key',
        ),
        'historical-request-key',
      );
      sheet.gate.complete();
      await tester.pumpAndSettle();
      expect(payments.legacy, hasLength(1));
    },
  );

  testWidgets(
    'session token change discards a late URL receipt before checkout or SDK',
    (tester) async {
      final pending = Completer<Json?>();
      final payments = AliasPayments()..pendingReceipt = pending;
      await start(
        tester,
        payments,
        AliasRescue()..withdrawn = true,
        settle: false,
        attempt: {
          'id': 'donation-one',
          'idempotency_key': 'old-extra-key',
          'gross_cents': 1234,
        },
      );
      await payments.client.auth.recoverSession(
        jsonEncode({
          'access_token': 'synthetic-replacement-token',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': 2208988800,
          'user': {
            'id': 'one',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'fixture@example.test',
            'created_at': '2026-10-17T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        }),
      );
      pending.complete({
        'id': 'donation-one',
        'donor_id': 'one',
        'expense_id': 'expense-one',
        'contribution_scope': 'expense',
        'currency': 'mxn',
        'idempotency_key': 'old-extra-key',
        'gross_cents': 7525,
        'payment_status': 'pending',
        'payment_state': 'requires_action',
      });
      await tester.pump();
      await tester.pump();
      expect(payments.caseCalls, isEmpty);
      expect(payments.legacy, isEmpty);
      expect(find.text('Continuar la misma aportación'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getKeys().where(
          (key) => key.startsWith('dopmi-payment:'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
