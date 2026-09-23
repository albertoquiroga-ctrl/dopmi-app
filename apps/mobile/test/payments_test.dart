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
  Future<void> openStripe(String url) async {}
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
    await tapButton(tester, 'Continuar a Stripe');
    await pumpUntil(tester, find.text('Continuar mi aportación'));
    expect(payments.calls.length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('dopmi-payment:one:expense-one:cents'), 10025);
    payments.fail = false;
    await tapButton(tester, 'Continuar mi aportación');
    await tester.pump(const Duration(milliseconds: 100));
    expect(payments.calls, [payments.calls.first, payments.calls.first]);
    expect(find.text('100.25'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
