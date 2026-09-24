import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'payments_test.dart' show pumpUntil, tapButton;

class FakeGuardian extends GuardianRepository {
  FakeGuardian()
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  Json value = {'plan': null, 'activation': null};
  final calls = <Json>[];
  int reads = 0, opened = 0;
  bool available = true, fail = false;
  bool conflict = false;
  @override
  Future<Json> state() async {
    reads++;
    return value;
  }

  @override
  Future<bool> capacity(int cents) async => available;
  @override
  Future<void> openCheckout(String url) async {
    opened++;
  }

  @override
  Future<Json> submit(Json intent) async {
    calls.add(Json.from(intent));
    if (fail) throw Exception('lost response');
    if (conflict) {
      throw const PostgrestException(
        message: 'revision changed',
        code: '40001',
      );
    }
    if (intent['kind'] == 'checkout') {
      value = {
        'plan': null,
        'activation': {
          'status': 'pending',
          'key': intent['key'],
          'gross_cents': intent['cents'],
          'consent_version': guardianConsent,
        },
      };
      return {
        'status': 'pending',
        'checkout_url': 'https://checkout.stripe.com/test',
      };
    }
    final p = Json.from(value['plan']);
    p['revision'] = (p['revision'] as int) + 1;
    p['pending_request'] = {
      'kind': intent['kind'],
      'new_gross_cents': intent['cents'],
    };
    if (intent['kind'] == 'cancel') p['status'] = 'cancel_requested';
    value = {...value, 'plan': p};
    return p;
  }
}

Json activePlan() => {
  'gross_cents': 5000,
  'revision': 2,
  'status': 'active',
  'pending_request': null,
  'payment_in_flight': false,
  'requests': <Json>[],
};

void main() {
  Future<void> start(
    WidgetTester tester,
    FakeGuardian repo, {
    bool enabled = true,
    String owner = 'one',
    bool verified = true,
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = Identity(owner, '$owner@example.test', verified: verified);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        guardianRepositoryProvider.overrideWithValue(repo),
        guardianEnabledProvider.overrideWithValue(enabled),
        routerInitialLocationProvider.overrideWithValue('/guardian'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await pumpUntil(tester, find.text('Tu ayuda, mes a mes.'));
    await tester.pumpAndSettle();
  }

  Future<void> consent(WidgetTester tester) async {
    final checkbox = find.byType(CheckboxListTile);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Guardian is hidden by default and a disabled route performs no reads',
    (tester) async {
      final repo = FakeGuardian();
      await start(tester, repo, enabled: false);
      expect(find.text('Activar en Stripe'), findsNothing);
      expect(repo.reads, 0);
      expect(find.textContaining('todavía no está disponible'), findsOneWidget);
    },
  );
  testWidgets('explicit consent and available capacity precede any Checkout', (
    tester,
  ) async {
    final repo = FakeGuardian()..available = false;
    await start(tester, repo);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Activar en Stripe'),
          )
          .onPressed,
      isNull,
    );
    await consent(tester);
    await tapButton(tester, 'Activar en Stripe');
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(repo.opened, 0);
    expect(
      find.textContaining('no hay gastos aprobados suficientes'),
      findsOneWidget,
    );
  });
  testWidgets('changing an amount revokes the checkbox authorization', (
    tester,
  ) async {
    await start(tester, FakeGuardian());
    await consent(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Importe mensual en MXN'),
      '200',
    );
    await tester.pump();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Activar en Stripe'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'lost Checkout response survives reopening with the same key and amount',
    (tester) async {
      final repo = FakeGuardian()..fail = true;
      await start(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextField, 'Importe mensual en MXN'),
        '100.25',
      );
      await consent(tester);
      await tapButton(tester, 'Activar en Stripe');
      await tester.pumpAndSettle();
      expect(repo.calls.single['cents'], 10025);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      repo.fail = false;
      await start(tester, repo);
      expect(find.text('100.25'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      await tapButton(tester, 'Reintentar mi solicitud');
      await tester.pumpAndSettle();
      expect(repo.calls[1], repo.calls[0]);
      expect(repo.opened, 1);
      expect(find.text('Alta pendiente de confirmación'), findsOneWidget);
      expect(find.text('Plan activo'), findsNothing);
    },
  );
  testWidgets('stored attempts are isolated by account', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dopmi-guardian:one:intent':
          '{"kind":"checkout","key":"one-key","cents":20000}',
    });
    final repo = FakeGuardian();
    await start(tester, repo, owner: 'two');
    expect(find.text('Reintentar mi solicitud'), findsNothing);
    expect(repo.calls, isEmpty);
  });
  testWidgets(
    'server state restores a pending Checkout after local storage is lost',
    (tester) async {
      final repo = FakeGuardian()
        ..value = {
          'plan': null,
          'activation': {
            'key': 'saved-key',
            'gross_cents': 20000,
            'status': 'pending',
            'consent_version': guardianConsent,
          },
        };
      await start(tester, repo);
      expect(find.text('200.00'), findsOneWidget);
      await tapButton(tester, 'Reintentar mi solicitud');
      await tester.pumpAndSettle();
      expect(repo.calls.single['key'], 'saved-key');
      expect(repo.calls.single['cents'], 20000);
    },
  );
  testWidgets(
    'amount request stays pending without optimistically replacing the confirmed amount',
    (tester) async {
      final repo = FakeGuardian()
        ..value = {'plan': activePlan(), 'activation': null};
      await start(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextField, 'Importe mensual en MXN'),
        '200',
      );
      await consent(tester);
      await tapButton(tester, 'Solicitar cambio de monto');
      await tester.pumpAndSettle();
      expect(repo.calls.single['revision'], 2);
      expect(find.text('Monto autorizado: \$50.00 MXN al mes'), findsOneWidget);
      expect(
        find.textContaining('Cambio a \$200.00 MXN solicitado'),
        findsOneWidget,
      );
      expect(find.text('Solicitar cambio de monto'), findsNothing);
      expect(find.text('Cancelar mi plan'), findsOneWidget);
    },
  );
  testWidgets(
    'unconfirmed owner can confirm cancellation while an earlier payment is in flight',
    (tester) async {
      final repo = FakeGuardian()
        ..value = {
          'plan': {...activePlan(), 'payment_in_flight': true},
          'activation': null,
        };
      await start(tester, repo, verified: false);
      await tester.ensureVisible(find.text('Cancelar mi plan'));
      await tester.tap(find.text('Cancelar mi plan'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['kind'], 'cancel');
      expect(repo.calls.single['revision'], 2);
      expect(
        find.text('Cancelación solicitada: futuros cobros detenidos'),
        findsOneWidget,
      );
      expect(find.textContaining('pago previamente iniciado'), findsOneWidget);
      expect(find.text('Plan cancelado'), findsNothing);
    },
  );
  testWidgets(
    'confirmed history displays the effective date and a canceled plan offers no activation',
    (tester) async {
      final repo = FakeGuardian()
        ..value = {
          'plan': {
            ...activePlan(),
            'status': 'canceled',
            'requests': [
              {
                'kind': 'amount',
                'new_gross_cents': 20000,
                'status': 'applied',
                'effective_at': '2026-10-24T12:00:00Z',
              },
            ],
          },
          'activation': null,
        };
      await start(tester, repo);
      expect(find.textContaining('Aplica desde 24/10/2026'), findsOneWidget);
      expect(find.text('Plan cancelado'), findsOneWidget);
      expect(find.text('Activar en Stripe'), findsNothing);
    },
  );
  test('estimated next month clamps month end and leap years', () {
    expect(guardianNextBilling(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    expect(guardianNextBilling(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    expect(guardianNextBilling(DateTime(2026, 12, 24)), DateTime(2027, 1, 24));
  });
  testWidgets(
    'revision conflict releases the rejected intent and requires fresh consent',
    (tester) async {
      final repo = FakeGuardian()
        ..conflict = true
        ..value = {'plan': activePlan(), 'activation': null};
      await start(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextField, 'Importe mensual en MXN'),
        '200',
      );
      await consent(tester);
      await tapButton(tester, 'Solicitar cambio de monto');
      await tester.pumpAndSettle();
      expect(find.text('Reintentar mi solicitud'), findsNothing);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(find.textContaining('otro dispositivo'), findsOneWidget);
    },
  );

  testWidgets('lost cancellation response reuses its original request key', (
    tester,
  ) async {
    final repo = FakeGuardian()
      ..fail = true
      ..value = {'plan': activePlan(), 'activation': null};
    await start(tester, repo);
    await tester.ensureVisible(find.text('Cancelar mi plan'));
    await tester.tap(find.text('Cancelar mi plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar cancelación'));
    await tester.pumpAndSettle();
    repo.fail = false;
    await tapButton(tester, 'Reintentar mi solicitud');
    await tester.pumpAndSettle();
    expect(repo.calls.length, 2);
    expect(repo.calls[0], repo.calls[1]);
    expect(
      find.text('Cancelación solicitada: futuros cobros detenidos'),
      findsOneWidget,
    );
  });
}
