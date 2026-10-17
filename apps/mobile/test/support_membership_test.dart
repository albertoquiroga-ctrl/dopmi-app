import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_registration_screen_test.dart' show registration;
import 'guardian_test.dart' show FakeGuardian;
import 'rescue_test.dart' show FakeRescue;
import 'monthly_impact_test.dart' show FakeMonthlyImpact;

class MembershipGuardian extends FakeGuardian {
  Json membership = {};
  Completer<Json>? pendingMembership;
  int membershipReads = 0, registrationSubmissions = 0;
  @override
  Future<Json> membershipState() async {
    membershipReads++;
    return pendingMembership == null ? membership : pendingMembership!.future;
  }
  @override
  Future<Json> submitRegistration(Json draft) async {
    registrationSubmissions++;
    throw StateError('No new registration is expected on return');
  }
}

class MembershipRescue extends FakeRescue {
  int catalogReads = 0;
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    if (caseId == null) catalogReads++;
    return super.catalog(page, caseId: caseId);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ProviderContainer> start(
    WidgetTester tester,
    MembershipGuardian guardian,
    MembershipRescue rescue, {
    String path = '/rescue-cases',
  }) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(rescue),
        guardianEnabledProvider.overrideWithValue(true),
        guardianRepositoryProvider.overrideWithValue(guardian),
        monthlyImpactRepositoryProvider.overrideWithValue(FakeMonthlyImpact()),
        routerInitialLocationProvider.overrideWithValue(path),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    if (guardian.pendingMembership == null) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    return container;
  }

  for (final pending in [false, true]) {
    testWidgets(
      'registered Guardian sees own/community impact without discovery; pending=$pending',
      (tester) async {
        final guardian = MembershipGuardian()
          ..membership = {
            'registration': registration(
              '72000000-0000-4000-8000-000000000002',
              status: pending ? 'method_pending' : 'registered',
            ),
          };
        final rescue = MembershipRescue();
        await start(tester, guardian, rescue);
        expect(find.text('Tu impacto Guardián'), findsOneWidget);
        expect(find.text('Consultar registro Guardián'), findsOneWidget);
        expect(find.text('Este mes logramos'), findsOneWidget);
        expect(find.text('Ayudar se siente bien'), findsNothing);
        expect(find.text('Suscríbete ahora'), findsNothing);
        expect(find.textContaining('Explorar'), findsNothing);
        // Personal history may resolve its public case; discovery is never loaded.
        expect(rescue.catalogReads, 0);
        expect(guardian.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'membership loading never loads discovery; legacy active uses impact',
    (tester) async {
      final guardian = MembershipGuardian()
        ..pendingMembership = Completer<Json>();
      final rescue = MembershipRescue();
      await start(tester, guardian, rescue);
      expect(find.text('Ayudar se siente bien'), findsNothing);
      expect(rescue.catalogReads, 0);
      guardian.pendingMembership!.complete({
        'plan': {'status': 'active'},
      });
      await tester.pumpAndSettle();
      expect(find.text('Tu impacto Guardián'), findsOneWidget);
      expect(find.text('Suscríbete ahora'), findsNothing);
      expect(guardian.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('membership failure is retryable without exposing discovery', (
    tester,
  ) async {
    final guardian = MembershipGuardian()
      ..pendingMembership = Completer<Json>();
    final rescue = MembershipRescue();
    await start(tester, guardian, rescue);
    guardian.pendingMembership!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No pudimos consultar tu estado de Guardián. Vuelve a intentarlo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ayudar se siente bien'), findsNothing);
    expect(rescue.catalogReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guardian can still open a public case directly', (tester) async {
    final guardian = MembershipGuardian()
      ..pendingMembership = Completer<Json>();
    await start(
      tester,
      guardian,
      MembershipRescue(),
      path: '/rescue-cases/case-one',
    );
    expect(find.text('Tu impacto Guardián'), findsNothing);
    expect(find.text('Mi historia'), findsOneWidget);
    expect(guardian.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final status in ['registered', 'method_pending']) {
    for (final card in [true, false]) {
      testWidgets('enrollment return immediately refreshes None to $status; card=$card', (tester) async {
        final guardian = MembershipGuardian()..methodsRegistration = registration(
          '72000000-0000-4000-8000-000000000002', status: status);
        final container = await start(tester, guardian, MembershipRescue());
        final started = tester.binding.clock.now();
        expect(find.text('Ayudar se siente bien'), findsOneWidget);
        final target = card ? find.byKey(const ValueKey('guardian-support-card-action'))
          : find.text('Suscríbete ahora');
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/guardian');
        guardian.membership = {'registration': guardian.methodsRegistration};
        final readsBeforeReturn = guardian.membershipReads;
        if (status == 'registered' && card) guardian.pendingMembership = Completer<Json>();
        await tester.binding.handlePopRoute();
        if (guardian.pendingMembership != null) {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('Ayudar se siente bien'), findsNothing);
          expect(find.text('Suscríbete ahora'), findsNothing);
          guardian.pendingMembership!.complete(guardian.membership);
        }
        await tester.pumpAndSettle();
        expect(tester.binding.clock.now().difference(started), lessThan(const Duration(seconds: 30)));
        expect(guardian.membershipReads, greaterThan(readsBeforeReturn));
        expect(find.text('Tu impacto Guardián'), findsOneWidget);
        expect(find.text(guardian.methodsRegistration!.summary), findsOneWidget);
        expect(find.text('Suscríbete ahora'), findsNothing);
        expect(find.text('Ayudar se siente bien'), findsNothing);
        expect(guardian.registrationSubmissions, 0);
        expect(guardian.calls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('returning from a pending registration management refreshes the same registration immediately', (tester) async {
    final guardian = MembershipGuardian()..methodsRegistration = registration(
      '72000000-0000-4000-8000-000000000002', status: 'method_pending');
    guardian.membership = {'registration': guardian.methodsRegistration};
    await start(tester, guardian, MembershipRescue());
    await tester.tap(find.text('Consultar registro Guardián'));
    await tester.pumpAndSettle();
    guardian.methodsRegistration = registration(
      '72000000-0000-4000-8000-000000000002', status: 'registered');
    guardian.membership = {'registration': guardian.methodsRegistration};
    final reads = guardian.membershipReads;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(guardian.membershipReads, greaterThan(reads));
    expect(find.text(guardian.methodsRegistration!.summary), findsOneWidget);
    expect(find.text('Suscríbete ahora'), findsNothing);
    expect(guardian.registrationSubmissions, 0);
    expect(guardian.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
