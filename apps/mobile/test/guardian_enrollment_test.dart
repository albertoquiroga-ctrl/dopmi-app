import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> start(
    WidgetTester tester,
    FakeGuardian repo, {
    bool enabled = true,
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
    await tester.pumpAndSettle();
  }

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
