import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue;

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

import 'fake_identity_repository.dart';

class FakePayments extends PaymentRepository {
  FakePayments()
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final calls = <String>[];
  bool fail = true;
  @override
  Future<Json> funding(String expense) async => {
    'title': 'Medicamentos para Luna',
    'reimbursable_cents': 12000,
    'funded_cents': 0,
    'available_cents': 12000,
    'payable': true,
  };
  @override
  Future<Json> checkout(String expense, int cents, String key) async {
    calls.add(key);
    if (fail) throw Exception('lost connection');
    return {'url': 'https://checkout.stripe.com/test'};
  }

  @override
  Future<DataPage<Json>> history(int page, {bool received = false}) async =>
      calls.isEmpty
      ? const DataPage([], 0)
      : DataPage([
          {
            'idempotency_key': calls.last,
            'payment_status': 'pending',
            'allocated_cents': 0,
            'transfer_status': 'not_started',
          },
        ], 1);

  @override
  Future<Json?> outcome(String expense, String key) async {
    final page = await history(1);
    final matches = page.items.where((row) => row['idempotency_key'] == key);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<void> openStripe(String url) async {}
}

class WaitingCheckoutPayments extends FakePayments {
  final response = Completer<Json>();
  @override
  Future<Json> checkout(String expense, int cents, String key) async {
    calls.add(key);
    return response.future;
  }
}

class ResultPayments extends FakePayments {
  ResultPayments(this.status) {
    this.fail = false;
  }
  final String status;
  @override
  Future<DataPage<Json>> history(int page, {bool received = false}) async =>
      calls.isEmpty
      ? const DataPage([], 0)
      : DataPage([
          {
            'idempotency_key': calls.last,
            'payment_status': status,
            'gross_cents': 10025,
            'allocated_cents': status == 'confirmed' ? 9200 : 0,
            'transfer_status': status == 'confirmed'
                ? 'pending'
                : 'not_started',
          },
        ], 1);
}

class OldResultPayments extends FakePayments {
  final lookups = <(String, String)>[];
  @override
  Future<DataPage<Json>> history(int page, {bool received = false}) async =>
      DataPage([
        for (var i = 0; i < 20; i++)
          {'idempotency_key': 'recent-$i', 'payment_status': 'pending'},
      ], 21);
  @override
  Future<Json?> outcome(String expense, String key) async {
    lookups.add((expense, key));
    return {
      'idempotency_key': key,
      'payment_status': 'confirmed',
      'gross_cents': 7525,
      'allocated_cents': 7000,
      'transfer_status': 'pending',
    };
  }
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 100,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await pumpUntil(tester, button);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets(
    'enlarged checkout retains its target while pending and avoids a second attempt',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final payments = WaitingCheckoutPayments();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          paymentRepositoryProvider.overrideWithValue(payments),
          routerInitialLocationProvider.overrideWithValue(
            '/contribute/expense-one?amount_cents=10025',
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await pumpUntil(tester, find.text('Resumen'));
      final button = find.widgetWithText(FilledButton, 'Confirmar en Stripe');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(button);
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(payments.calls, hasLength(1));
      final pending = find.widgetWithText(FilledButton, 'Confirmar en Stripe');
      expect(tester.getSize(pending), bounds.size);
      expect(tester.widget<FilledButton>(pending).onPressed, isNull);
      await tester.ensureVisible(pending);
      await tester.pump();
      await tester.tapAt(tester.getRect(pending).center);
      await tester.pump(const Duration(milliseconds: 300));
      expect(payments.calls, hasLength(1));
      expect(find.text('¡Eres mi héroe, choca esas huellitas!'), findsNothing);
      payments.response.completeError(Exception('lost connection'));
      await tester.pumpAndSettle();
      expect(find.text('¡Eres mi héroe, choca esas huellitas!'), findsNothing);
      expect(find.text('Continuar mi aportación'), findsOneWidget);
      expect(payments.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'payment errors distinguish account permissions from Stripe configuration',
    () {
      String message(String code) => paymentError(
        FunctionException(status: 403, details: {'error': code}),
      );
      expect(
        message('rescuer_verification_required'),
        contains('verificación'),
      );
      expect(message('access_denied'), contains('no tiene acceso'));
      expect(
        message('stripe_permission_denied'),
        contains('conexión de Dopmi'),
      );
      expect(
        message('stripe_authentication_failed'),
        contains('No vuelvas a pagar'),
      );
      expect(message('processor_busy'), contains('no vuelvas a pagar'));
    },
  );
  test(
    'payment pages require a confirmed session and respect recovery',
    () async {
      final repo = FakeIdentityRepository();
      final controller = IdentityController(repo);
      await controller.initialize();
      for (final path in ['/payments', '/connect', '/contribute/one']) {
        expect(controller.redirect(path), '/welcome');
      }
      repo.user = const Identity('one', 'ana@example.test', verified: true);
      await controller.initialize();
      expect(controller.redirect('/payments'), isNull);
      expect(controller.redirect('/connect'), isNull);
      controller.dispose();
      await repo.changes.close();
    },
  );
  for (final caseId in ['case-one', 'different-case']) {
    testWidgets(
      'seed review only shows a public case matching the expense: $caseId',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final payments = FakePayments();
        final rescue = FakeRescue();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            paymentRepositoryProvider.overrideWithValue(payments),
            rescueRepositoryProvider.overrideWithValue(rescue),
            routerInitialLocationProvider.overrideWithValue(
              '/contribute/expense-one?case=$caseId&amount_cents=10025',
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        );
        await pumpUntil(tester, find.text('Resumen'));
        expect(
          find.text(rescue.caseRecord.title),
          caseId == 'case-one' ? findsNWidgets(2) : findsNothing,
        );
        expect(find.text('En Stripe'), findsOneWidget);
        expect(find.text('\$100.25 MXN'), findsOneWidget);
        expect(payments.calls, isEmpty);
        await tester.ensureVisible(find.text('Cambiar monto'));
        await tester.tap(find.text('Cambiar monto'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, 'Tu aportación en MXN'),
          findsOneWidget,
        );
        expect(find.text('Resumen'), findsNothing);
        expect(payments.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
  for (final status in ['confirmed', 'pending', 'canceled', 'refunded']) {
    testWidgets('result follows server evidence and limits actions: $status', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final payments = ResultPayments(status);
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          paymentRepositoryProvider.overrideWithValue(payments),
          routerInitialLocationProvider.overrideWithValue(
            '/contribute/expense-one?amount_cents=10025',
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await pumpUntil(tester, find.text('Resumen'));
      expect(payments.calls, isEmpty);
      await tapButton(tester, 'Confirmar en Stripe');
      await tester.pumpAndSettle();
      expect(payments.calls.length, 1);
      expect(
        find.text('¡Eres mi héroe, choca esas huellitas!'),
        status == 'confirmed' ? findsOneWidget : findsNothing,
      );
      if (status == 'confirmed') {
        expect(
          find.text('Asignado: ${String.fromCharCode(36)}92 MXN'),
          findsOneWidget,
        );
        expect(find.text('Transferencia en proceso'), findsOneWidget);
      }
      expect(
        find.text('Intentar de nuevo'),
        status == 'canceled' ? findsOneWidget : findsNothing,
      );
      if (status == 'pending') {
        await tapButton(tester, 'Consultar resultado');
        await tester.pumpAndSettle();
        expect(payments.calls.length, 1);
      }
      if (status == 'canceled') {
        await tapButton(tester, 'Intentar de nuevo');
        await tester.pumpAndSettle();
        expect(find.text('Resumen'), findsOneWidget);
        expect(payments.calls.length, 1);
        await tapButton(tester, 'Confirmar en Stripe');
        await tester.pumpAndSettle();
        expect(payments.calls.length, 2);
        expect(payments.calls[0], isNot(payments.calls[1]));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets(
    'old stored attempt resolves outside first history page without another checkout',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dopmi-payment:one:expense-one:key': 'historical-attempt',
        'dopmi-payment:one:expense-one:cents': 7525,
      });
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final payments = OldResultPayments();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          paymentRepositoryProvider.overrideWithValue(payments),
          routerInitialLocationProvider.overrideWithValue(
            '/contribute/expense-one',
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await pumpUntil(tester, find.text('Resumen'));
      final lookup = find.widgetWithText(TextButton, 'Consultar resultado');
      await tester.ensureVisible(lookup);
      await tester.tap(lookup);
      await tester.pumpAndSettle();
      expect(payments.lookups, [('expense-one', 'historical-attempt')]);
      expect(payments.calls, isEmpty);
      expect(
        find.text('¡Eres mi héroe, choca esas huellitas!'),
        findsOneWidget,
      );
      expect(
        find.text('Asignado: ${String.fromCharCode(36)}70 MXN'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('dopmi-payment:one:expense-one:key'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'selected amount opens review without checkout and stored attempt takes precedence',
    (tester) async {
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'dopmi-payment:one:expense-one:key': 'existing-attempt',
        'dopmi-payment:one:expense-one:cents': 7525,
      });
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true);
      final payments = FakePayments();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          paymentRepositoryProvider.overrideWithValue(payments),
          routerInitialLocationProvider.overrideWithValue(
            '/contribute/expense-one?amount_cents=120025',
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await pumpUntil(tester, find.text('Resumen'));
      expect(find.text('\$75.25 MXN'), findsOneWidget);
      expect(find.text('Continuar mi aportación'), findsOneWidget);
      expect(payments.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets('lost response preserves amount and idempotency key for retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    final payments = FakePayments();
    final community = FakeCommunity();
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(community),
        paymentRepositoryProvider.overrideWithValue(payments),
        routerInitialLocationProvider.overrideWithValue(
          '/contribute/expense-one',
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
    await pumpUntil(tester, find.text('Medicamentos para Luna'));
    expect(find.text('Medicamentos para Luna'), findsOneWidget);
    expect(find.text('Neto asignado: \$0.00 MXN'), findsOneWidget);
    expect(find.text('Transferido a Stripe: \$0.00 MXN'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Tu aportación en MXN'),
      '100.25',
    );
    await tapButton(tester, 'Revisar aportación');
    expect(find.text('Resumen'), findsOneWidget);
    await tapButton(tester, 'Confirmar en Stripe');
    await pumpUntil(tester, find.text('Continuar mi aportación'));
    expect(payments.calls.length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('dopmi-payment:one:expense-one:cents'), 10025);
    payments.fail = false;
    await tapButton(tester, 'Continuar mi aportación');
    await tester.pump(const Duration(milliseconds: 100));
    expect(payments.calls, [payments.calls.first, payments.calls.first]);
    expect(find.text('Pago en procesamiento'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
