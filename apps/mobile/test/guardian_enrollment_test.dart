import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian, activePlan;
import 'rescue_test.dart' show FakeRescue;

class PendingCapacityGuardian extends FakeGuardian {
  final pendingCapacity = Completer<bool>();
  @override
  Future<bool> capacity(int cents) => pendingCapacity.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> start(
    WidgetTester tester,
    FakeGuardian repo, {
    bool enabled = true,
    String location = '/guardian',
  }) async {
    tester.view.physicalSize = const Size(377, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        guardianRepositoryProvider.overrideWithValue(repo),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        guardianEnabledProvider.overrideWithValue(enabled),
        routerInitialLocationProvider.overrideWithValue(location),
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
  }

  testWidgets(
    'Matching server activation welcomes its owner without another charge',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dopmi-guardian:one:intent': jsonEncode({
          'kind': 'checkout',
          'key': 'confirmed-one',
          'cents': 7525,
          'consent_version': guardianConsent,
        }),
      });
      final repo = FakeGuardian()
        ..value = {
          'plan': {
            ...activePlan(),
            'gross_cents': 7525,
            'next_billing_at': '2026-11-02T18:00:00Z',
          },
          'activation': {
            'status': 'active',
            'key': 'confirmed-one',
            'gross_cents': 7525,
          },
        };
      await start(tester, repo);
      expect(find.text('¡Ya eres Guardián!'), findsOneWidget);
      expect(find.text('Próximo cargo: 2 de noviembre, 2026'), findsOneWidget);
      expect(repo.calls, isEmpty);
      expect(repo.opened, 0);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-guardian:one:intent',
        ),
        isNull,
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Volver a Apoyar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Volver a Apoyar'));
      await tester.pumpAndSettle();
      expect(find.text('¡Ya eres Guardián!'), findsNothing);
      expect(repo.calls, isEmpty);
    },
  );

  for (final state in [
    'funded_pending_schedule',
    'attention',
    'failed',
    'expired',
    'refunded',
    'unrelated',
  ]) {
    testWidgets('Activation $state never claims matching active membership', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'dopmi-guardian:one:intent': jsonEncode({
          'kind': 'checkout',
          'key': 'confirmed-one',
          'cents': 5000,
          'consent_version': guardianConsent,
        }),
      });
      final repo = FakeGuardian()
        ..value = {
          'plan': state == 'unrelated' ? activePlan() : null,
          'activation': {
            'status': state == 'unrelated' ? 'active' : state,
            'key': state == 'unrelated' ? 'another-attempt' : 'confirmed-one',
            'gross_cents': 5000,
          },
        };
      await start(tester, repo);
      expect(find.text('¡Ya eres Guardián!'), findsNothing);
      expect(
        find.text('No pudimos procesar tu pago'),
        state == 'failed' ? findsOneWidget : findsNothing,
      );
      expect(repo.calls, isEmpty);
      expect(repo.opened, 0);
    });
  }

  for (final action in ['Intentar de nuevo', 'Cambiar método de pago']) {
    testWidgets(
      'Confirmed failed checkout: $action requires fresh authorization',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'dopmi-guardian:one:intent': jsonEncode({
            'kind': 'checkout',
            'key': 'failed-one',
            'cents': 7525,
            'consent_version': guardianConsent,
          }),
        });
        final repo = FakeGuardian()
          ..value = {
            'plan': null,
            'activation': {
              'status': 'failed',
              'key': 'failed-one',
              'gross_cents': 7525,
            },
          };
        await start(tester, repo);
        expect(find.text('No pudimos procesar tu pago'), findsOneWidget);
        expect(find.text('Se elige en Stripe'), findsOneWidget);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'dopmi-guardian:one:intent',
          ),
          isNull,
        );
        if (action.startsWith('Cambiar')) {
          tester.view.physicalSize = const Size(320, 640);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text(action));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(find.text('No pudimos procesar tu pago'), findsNothing);
        expect(find.byType(CheckboxListTile), findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          false,
        );
        expect(repo.calls, isEmpty);
        expect(repo.opened, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Disabled promotion never offers enrollment or reads financial state',
    (tester) async {
      final repo = FakeGuardian();
      await start(tester, repo, location: '/impact/guardian', enabled: false);
      expect(find.text('Unirme como Guardián'), findsNothing);
      expect(find.text('Guardián todavía no está disponible'), findsOneWidget);
      expect(repo.reads, 0);
      expect(repo.calls, isEmpty);
    },
  );
  testWidgets('Promotion opens fresh enrollment without a payment', (
    tester,
  ) async {
    final repo = FakeGuardian();
    await start(tester, repo, location: '/impact/guardian');
    expect(repo.reads, 0);
    final second = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Ir a la página 2 de 3',
    );
    await tester.ensureVisible(second);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(second).properties.selected, true);
    await tester.ensureVisible(find.text('Unirme como Guardián'));
    await tester.tap(find.text('Unirme como Guardián'));
    await tester.pumpAndSettle();
    expect(find.text('Elige tu apoyo'), findsOneWidget);
    expect(find.text('Suscribirme'), findsNothing);
    expect(repo.reads, greaterThan(0));
    expect(repo.calls, isEmpty);
    expect(repo.opened, 0);
    await tester.tap(find.byTooltip('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('Conviértete en Guardián'), findsOneWidget);
    final first = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Ir a la página 1 de 3',
    );
    expect(tester.widget<Semantics>(first).properties.selected, true);
    expect(repo.calls, isEmpty);
    expect(repo.opened, 0);
  });
  testWidgets('System back returns fresh enrollment to its promotion origin', (
    tester,
  ) async {
    final repo = FakeGuardian();
    await start(tester, repo, location: '/impact/guardian');
    await tester.ensureVisible(find.text('Unirme como Guardián'));
    await tester.tap(find.text('Unirme como Guardián'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$200'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Conviértete en Guardián'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(repo.opened, 0);
  });
  testWidgets('Fresh enrollment without history returns to support', (
    tester,
  ) async {
    final repo = FakeGuardian();
    await start(tester, repo, location: '/guardian?enroll=1');
    await tester.tap(find.byTooltip('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('Ayudar se siente bien'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(repo.opened, 0);
  });
  testWidgets('System back keeps an in-flight capacity check recoverable', (
    tester,
  ) async {
    final repo = PendingCapacityGuardian();
    await start(tester, repo, location: '/guardian?enroll=1');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Activar en Stripe'));
    await tester.tap(find.text('Activar en Stripe'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Elige tu apoyo'), findsOneWidget);
    expect(repo.calls, isEmpty);
    repo.pendingCapacity.complete(false);
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(repo.opened, 0);
    await tester.tap(find.byTooltip('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('Ayudar se siente bien'), findsOneWidget);
  });
  testWidgets(
    'Promotion never offers a second enrollment when server returns an active plan',
    (tester) async {
      final repo = FakeGuardian()
        ..value = {'plan': activePlan(), 'activation': null};
      await start(tester, repo, location: '/impact/guardian');
      await tester.ensureVisible(find.text('Unirme como Guardián'));
      await tester.tap(find.text('Unirme como Guardián'));
      await tester.pumpAndSettle();
      expect(find.text('Suscripción activa'), findsOneWidget);
      expect(find.text('Elige tu apoyo'), findsNothing);
      expect(repo.calls, isEmpty);
      expect(repo.opened, 0);
    },
  );
  testWidgets(
    'Subscribe opens authorization without payment; only explicit Stripe confirmation starts checkout',
    (tester) async {
      final repo = FakeGuardian();
      await start(tester, repo);
      expect(find.text('Sin suscripción'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Suscribirme'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Otra cantidad'));
      await tester.tap(find.text('Otra cantidad'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(repo.calls, isEmpty);
      expect(repo.opened, 0);
      await tester.enterText(find.byType(TextField), '75.25');
      await tester.pump();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Activar en Stripe'));
      await tester.tap(find.text('Activar en Stripe'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['kind'], 'checkout');
      expect(repo.calls.single['cents'], 7525);
      expect(repo.opened, 1);
      expect(find.text('Suscripción activa'), findsNothing);
      expect(find.text('Suscribirme'), findsNothing);
    },
  );
  testWidgets(
    'Enrollment starts at the reference heading and returning revokes consent without checkout',
    (tester) async {
      final repo = FakeGuardian();
      await start(tester, repo);
      await tester.tap(find.text('Suscribirme'));
      await tester.pumpAndSettle();
      expect(find.text('Suscripción Dopmi'), findsNothing);
      expect(find.text('Historial de pagos'), findsNothing);
      expect(tester.getTopLeft(find.text('Elige tu apoyo')).dy, closeTo(88, 2));
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin suscripción'), findsOneWidget);
      expect(repo.calls, isEmpty);
      expect(repo.opened, 0);
      await tester.tap(find.text('Suscribirme'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Sin suscripción'), findsOneWidget);
      expect(repo.calls, isEmpty);
    },
  );
  testWidgets(
    'Pending activation never claims no subscription or permits another enrollment',
    (tester) async {
      final repo = FakeGuardian()
        ..value = {
          'plan': null,
          'activation': {
            'status': 'pending',
            'key': 'existing-attempt',
            'gross_cents': 5000,
            'consent_version': guardianConsent,
          },
        };
      await start(tester, repo);
      expect(find.text('Sin suscripción'), findsNothing);
      expect(find.text('Suscribirme'), findsNothing);
      expect(repo.calls, isEmpty);
    },
  );
  testWidgets(
    'Disabled Guardian never offers an enrollment or makes financial reads',
    (tester) async {
      final repo = FakeGuardian();
      await start(tester, repo, enabled: false);
      expect(find.text('Suscribirme'), findsNothing);
      expect(repo.reads, 0);
      expect(repo.calls, isEmpty);
    },
  );
}
