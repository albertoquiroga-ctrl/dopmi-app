import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_screen.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_screen.dart';
import 'package:dopmi_mobile/features/payments/guardian_registration.dart';
import 'package:dopmi_mobile/features/payments/payment_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_account_photo_repository.dart';
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;
import 'rescue_test.dart' show FakeRescue;
import 'payments_test.dart' show FakePayments;

void main() {
  final aliases = {
    '/saved-rescuers': '/profile',
    '/saved?kind=rescuer': '/saved',
    '/profile/basic-info': '/basic-info',
    '/settings/basic-info': '/basic-info',
    '/profile/payment-methods': '/settings/payment-methods',
    '/profile/payment-method/success': '/settings/payment-methods',
    '/settings/payment-method/success': '/settings/payment-methods',
    '/profile/billing': '/guardian',
    '/settings/billing': '/guardian',
    '/rescuer/account': '/settings/account',
    '/rescuer/settings': '/settings/account',
  };
  final scenarios = [
    for (final alias in aliases.entries)
      (path: alias.key, target: alias.value, verified: true, expired: false),
    for (final path in ['/profile/billing', '/settings/billing']) ...[
      (path: path, target: '/guardian', verified: false, expired: false),
      (path: path, target: '/guardian', verified: true, expired: true),
    ],
    (
      path: '/profile/basic-info',
      target: '/welcome',
      verified: false,
      expired: false,
    ),
    (
      path: '/profile/basic-info',
      target: '/consent',
      verified: true,
      expired: true,
    ),
  ];
  for (final scenario in scenarios) {
    testWidgets('account link $scenario reads without payment mutation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final identity = FakeIdentityRepository()
        ..user = Identity(
          'one',
          'fixture@example.test',
          verified: scenario.verified,
        );
      if (scenario.expired) {
        identity.profile = const Profile(
          id: 'one',
          name: 'Ana',
          phone: '',
          city: '',
          mode: 'donor',
          intent: 'adopt',
          status: 'active',
          termsVersion: 'expired',
        );
      }
      final guardian = FakeGuardian();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          accountPhotoRepositoryProvider.overrideWithValue(
            emptyAccountPhotoRepository(identity),
          ),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          guardianRepositoryProvider.overrideWithValue(guardian),
          routerInitialLocationProvider.overrideWithValue(scenario.path),
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
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.toString(),
        scenario.target,
      );
      expect(guardian.calls, isEmpty);
      expect(guardian.opened, 0);
      if (scenario.verified &&
          !scenario.expired &&
          scenario.target != '/profile' &&
          scenario.target != '/saved') {
        final router = container.read(routerProvider);
        router.go('/profile');
        await tester.pumpAndSettle();
        // Opening an old link from a profile preserves its actual return page.
        router.push(scenario.path);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, scenario.target);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/profile');
        expect(guardian.calls, isEmpty);
        expect(guardian.opened, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }
  const priorConsent = Profile(
    id: 'one',
    name: 'Ana',
    phone: '',
    city: '',
    mode: 'donor',
    intent: 'adopt',
    status: 'active',
    termsVersion: 'terms-2026-09-28',
    privacyVersion: 'privacy-2026-09-28',
    adultConfirmed: true,
  );
  Future<ProviderContainer> startLegal(
    WidgetTester tester,
    String path,
    FakeIdentityRepository identity,
    _LegalAttemptPayments payments,
    _LegalReadsGuardian guardian,
    _LegalHistoryActivity history,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(identity),
        ),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        guardianRepositoryProvider.overrideWithValue(guardian),
        paymentRepositoryProvider.overrideWithValue(payments),
        guardianEnabledProvider.overrideWithValue(true),
        paymentActivityRepositoryProvider.overrideWithValue(history),
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
    return container;
  }

  testWidgets(
    'restoration error retains recovery controls before legal update',
    (tester) async {
      final restored = Completer<Identity?>();
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'legal@example.test', verified: true)
        ..profile = priorConsent
        ..restoreResult = restored.future;
      final payments = _LegalAttemptPayments();
      final guardian = _LegalReadsGuardian();
      final container = await startLegal(
        tester,
        '/contribute-case/case-one',
        identity,
        payments,
        guardian,
        _LegalHistoryActivity(),
      );
      await tester.pump();
      restored.completeError(StateError('restoration failed'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/auth-error');
      expect(find.text('Revisemos tu acceso.'), findsOneWidget);
      expect(find.text('Volver a intentar'), findsOneWidget);
      expect(find.text('Volver a iniciar sesión'), findsOneWidget);
      expect(find.text('Antes de continuar'), findsNothing);
      expect(find.byType(ContributeScreen, skipOffstage: false), findsNothing);
      expect(payments.calls, isEmpty);
      expect(payments.caseCalls, isEmpty);
      expect(guardian.calls, isEmpty);
      expect(guardian.opened, 0);
      expect(identity.consentCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final path in [
    '/contribute/expense-one',
    '/contribute-case/case-one',
    '/settings/payment-methods',
  ]) {
    testWidgets('legal restoration never mounts blocked mutating route $path', (
      tester,
    ) async {
      final profile = Completer<Profile>();
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'legal@example.test', verified: true)
        ..profile = priorConsent
        ..profileResult = profile.future;
      final payments = _LegalAttemptPayments();
      final guardian = _LegalReadsGuardian();
      final container = await startLegal(
        tester,
        path,
        identity,
        payments,
        guardian,
        _LegalHistoryActivity(),
      );
      await tester.pump();
      expect(find.byType(ContributeScreen, skipOffstage: false), findsNothing);
      expect(find.byType(GuardianScreen, skipOffstage: false), findsNothing);
      expect(payments.fundingReads, 0);
      expect(guardian.reads, 0);
      profile.complete(priorConsent);
      await tester.pumpAndSettle();
      expect(find.text('Antes de continuar'), findsOneWidget);
      expect(find.byType(ContributeScreen, skipOffstage: false), findsNothing);
      expect(find.byType(GuardianScreen, skipOffstage: false), findsNothing);
      expect(payments.fundingReads, 0);
      expect(payments.calls, isEmpty);
      expect(payments.caseCalls, isEmpty);
      expect(guardian.calls, isEmpty);
      expect(guardian.opened, 0);
      expect(guardian.reads, 0);
      // Also exercise the fail-closed route's visible account controls.
      container.read(routerProvider).go('/account-privacy');
      await tester.pumpAndSettle();
      expect(find.text('Privacidad y cuenta'), findsOneWidget);
      expect(identity.consentCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final path in ['/payments', '/rescuer/received-payments']) {
    testWidgets(
      'prior legal version retains private receipts without checkout $path',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity('one', 'legal@example.test', verified: true)
          ..profile = priorConsent;
        final history = _LegalHistoryActivity();
        final payments = _LegalAttemptPayments();
        final guardian = _LegalReadsGuardian();
        final container = await startLegal(
          tester,
          path,
          identity,
          payments,
          guardian,
          history,
        );
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, path);
        expect(
          tester
              .widget<PaymentActivityScreen>(find.byType(PaymentActivityScreen))
              .readOnly,
          isTrue,
        );
        expect(history.receivedReads, contains(path.contains('received')));
        expect(find.text('Recibo privado'), findsOneWidget);
        await tester.tap(find.text('Recibo privado'));
        await tester.pumpAndSettle();
        expect(find.text('Referencia: own-receipt'), findsOneWidget);
        expect(find.text('Continuar aportación'), findsNothing);
        expect(find.text('Consultar aportación'), findsNothing);
        expect(find.text('Ver caso'), findsNothing);
        expect(identity.consentCount, 0);
        expect(payments.calls, isEmpty);
        expect(payments.caseCalls, isEmpty);
        expect(guardian.calls, isEmpty);
        expect(guardian.opened, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'expired consent ignores Guardian enrollment query and keeps cancellation access',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'legal@example.test', verified: true)
        ..profile = priorConsent;
      final guardian = _LegalReadsGuardian();
      final payments = _LegalAttemptPayments();
      final container = await startLegal(
        tester,
        '/guardian?enroll=1',
        identity,
        payments,
        guardian,
        _LegalHistoryActivity(),
      );
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/guardian');
      expect(find.text('Consultar o cancelar Guardián'), findsOneWidget);
      expect(find.byType(GuardianScreen, skipOffstage: false), findsNothing);
      expect(guardian.snapshotReads, greaterThan(0));
      expect(guardian.calls, isEmpty);
      expect(guardian.opened, 0);
      expect(identity.consentCount, 0);
      expect(payments.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class _LegalAttemptPayments extends FakePayments {
  int fundingReads = 0;
  @override
  Future<Json> funding(String expense) {
    fundingReads++;
    return super.funding(expense);
  }
}

class _LegalReadsGuardian extends FakeGuardian {
  int snapshotReads = 0;
  @override
  Future<GuardianRegistration?> registrationSnapshot() async {
    snapshotReads++;
    return null;
  }
}

class _LegalHistoryActivity extends PaymentActivityRepository {
  _LegalHistoryActivity() : super(FakeRescue().client);
  final receivedReads = <bool>[];
  @override
  Future<Json> page({required bool received, Json? cursor}) async {
    receivedReads.add(received);
    return {
      'items': [
        {
          'id': 'own-receipt',
          'kind': 'contribution',
          'title': 'Recibo privado',
          'created_at': '2026-10-17T12:00:00Z',
          'amount_cents': 1000,
          'assigned_cents': 584,
          'status': 'processing',
          'payment_status': 'pending',
          'idempotency_key': 'same-key',
          'expense_id': 'private-expense',
          'case_id': 'private-case',
          'allocation_count': 0,
        },
      ],
      'next_cursor': null,
    };
  }
}
