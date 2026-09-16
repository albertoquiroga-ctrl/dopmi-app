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

void main() {
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
      await payments.client.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Medicamentos para Luna'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Tu aportación en MXN'),
      '100.25',
    );
    await tester.tap(find.text('Continuar a Stripe'));
    await tester.pumpAndSettle();
    expect(payments.calls.length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('dopmi-payment:one:expense-one:cents'), 10025);
    payments.fail = false;
    await tester.tap(find.text('Continuar mi aportación'));
    await tester.pumpAndSettle();
    expect(payments.calls, [payments.calls.first, payments.calls.first]);
    expect(find.text('100.25'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
