import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_legal_access_screen.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_registration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;
import 'guardian_registration_screen_test.dart' show registration;

class LegalGuardian extends FakeGuardian {
  GuardianRegistration? snapshot;
  Completer<Json>? readGate;
  int stateReads = 0, snapshotReads = 0, cancels = 0;
  bool failSnapshot = false, loseFirst = false, conflictFirst = false;
  @override
  Future<Json> state() async {
    stateReads++;
    return readGate != null ? await readGate!.future : value;
  }

  @override
  Future<GuardianRegistration?> registrationSnapshot() async {
    snapshotReads++;
    if (failSnapshot) throw StateError('denied snapshot');
    return snapshot;
  }

  @override
  Future<GuardianRegistration?> registrationState() async =>
      throw StateError('No setup reconciliation allowed');
  @override
  Future<void> cancelRegistration(String id) async {
    cancels++;
    expect(id, snapshot!.id);
    snapshot = registration(snapshot!.key, status: 'canceled');
  }

  @override
  Future<Json> submit(Json intent) async {
    calls.add(Json.from(intent));
    if (calls.length == 1 && conflictFirst) {
      value = {
        'plan': {'status': 'active', 'revision': 4},
        'activation': null,
      };
      throw const PostgrestException(
        message: 'revision changed',
        code: '40001',
      );
    }
    if (calls.length == 1 && loseFirst) throw StateError('lost response');
    if (intent['kind'] == 'cancel') {
      value = {
        'plan': {...Json.from(value['plan']), 'status': 'cancel_requested'},
        'activation': null,
      };
    } else if (intent['kind'] == 'cancel_activation') {
      value = {
        'plan': null,
        'activation': {
          ...Json.from(value['activation']),
          'cancellation_status': 'stopped',
        },
      };
    } else {
      throw StateError('Forbidden legal-access mutation');
    }
    return value;
  }
}

void main() {
  Future<FakeIdentityRepository> pump(
    WidgetTester tester,
    LegalGuardian guardian, {
    bool verified = true,
    String status = 'active',
    bool enabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final identity = FakeIdentityRepository()
      ..user = Identity('one', 'fixture@example.test', verified: verified)
      ..profile = Profile(
        id: 'one',
        name: 'Ana',
        phone: '',
        city: '',
        mode: 'donor',
        intent: 'adopt',
        status: status,
        termsVersion: 'terms-2026-09-28',
      );
    addTearDown(identity.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          guardianRepositoryProvider.overrideWithValue(guardian),
          guardianEnabledProvider.overrideWithValue(enabled),
        ],
        child: const MaterialApp(home: GuardianLegalAccessScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    if (guardian.readGate == null) await tester.pumpAndSettle();
    return identity;
  }

  testWidgets('disabled legal access performs no financial read or mutation', (
    tester,
  ) async {
    final guardian = LegalGuardian()
      ..value = {
        'plan': {'status': 'active', 'revision': 3},
        'activation': null,
      }
      ..snapshot = registration(
        '72000000-0000-4000-8000-000000000002',
        status: 'registered',
      );
    await pump(tester, guardian, enabled: false);
    expect(find.textContaining('todavía no está disponible'), findsOneWidget);
    expect(find.text('Cancelar Guardián'), findsNothing);
    expect(find.text('Confirmar cancelación'), findsNothing);
    expect(guardian.stateReads, 0);
    expect(guardian.snapshotReads, 0);
    expect(guardian.calls, isEmpty);
    expect(guardian.cancels, 0);
    expect(guardian.opened, 0);
    expect(tester.takeException(), isNull);
  });
  for (final state in [
    'active',
    'activation',
    'method_pending',
    'registered',
    'legacy_canceled_registration',
  ]) {
    testWidgets(
      'retained $state access reads only and cancellation requires confirmation',
      (tester) async {
        final guardian = LegalGuardian();
        if (state == 'active') {
          guardian.value = {
            'plan': {'status': 'active', 'revision': 3},
            'activation': null,
          };
        }
        if (state == 'activation') {
          guardian.value = {
            'plan': null,
            'activation': {
              'key': '72000000-0000-4000-8000-000000000004',
              'status': 'pending',
            },
          };
        }
        if (['method_pending', 'registered'].contains(state)) {
          guardian.snapshot = registration(
            '72000000-0000-4000-8000-000000000002',
            status: state,
          );
        }
        if (state == 'legacy_canceled_registration') {
          guardian.value = {
            'plan': {'status': 'canceled'},
            'activation': null,
          };
          guardian.snapshot = registration(
            '72000000-0000-4000-8000-000000000002',
            status: 'registered',
          );
        }
        await pump(tester, guardian);
        expect(guardian.snapshotReads, 1);
        expect(guardian.calls, isEmpty);
        expect(guardian.cancels, 0);
        expect(find.textContaining('Registrar'), findsNothing);
        expect(find.textContaining('Cambiar tarjeta'), findsNothing);
        await tester.ensureVisible(find.text('Cancelar Guardián'));
        await tester.tap(find.text('Cancelar Guardián'));
        await tester.pumpAndSettle();
        expect(guardian.calls, isEmpty);
        expect(guardian.cancels, 0);
        await tester.tap(find.text('Volver'));
        await tester.pumpAndSettle();
        expect(guardian.calls, isEmpty);
        expect(guardian.cancels, 0);
        await tester.tap(find.text('Cancelar Guardián'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar cancelación'));
        await tester.pumpAndSettle();
        if ([
          'method_pending',
          'registered',
          'legacy_canceled_registration',
        ].contains(state)) {
          expect(guardian.cancels, 1);
          expect(guardian.calls, isEmpty);
        } else {
          expect(
            guardian.calls.single['kind'],
            state == 'active' ? 'cancel' : 'cancel_activation',
          );
        }
        expect(find.text('Cancelar Guardián'), findsNothing);
        expect(guardian.opened, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final state in ['empty', 'canceled', 'cancel_requested']) {
    testWidgets('retained $state has no enrollment or repeated cancellation', (
      tester,
    ) async {
      final guardian = LegalGuardian();
      if (state != 'empty') {
        guardian.value = {
          'plan': {'status': state},
          'activation': null,
        };
      }
      await pump(tester, guardian);
      expect(find.text('Cancelar Guardián'), findsNothing);
      expect(guardian.calls, isEmpty);
      expect(guardian.cancels, 0);
      expect(guardian.opened, 0);
      expect(tester.takeException(), isNull);
    });
  }
  for (final account in ['active', 'suspended', 'unverified']) {
    testWidgets(
      'legacy cancellation survives denied secondary snapshot for $account',
      (tester) async {
        final guardian = LegalGuardian()
          ..failSnapshot = true
          ..value = {
            'plan': {'status': 'active', 'revision': 3},
            'activation': null,
          };
        await pump(
          tester,
          guardian,
          verified: account != 'unverified',
          status: account == 'suspended' ? 'suspended' : 'active',
        );
        expect(find.text('Plan activo'), findsOneWidget);
        expect(
          find.textContaining('No pudimos consultar el registro actual.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Cancelar Guardián'));
        await tester.tap(find.text('Cancelar Guardián'));
        await tester.pumpAndSettle();
        expect(guardian.calls, isEmpty);
        await tester.tap(find.text('Confirmar cancelación'));
        await tester.pumpAndSettle();
        expect(guardian.calls.single['kind'], 'cancel');
        expect(guardian.opened, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final account in ['suspended', 'unverified']) {
    testWidgets(
      'modern $account registration explains limitation without offering a cancel submit',
      (tester) async {
        final guardian = LegalGuardian()
          ..snapshot = registration(
            '72000000-0000-4000-8000-000000000002',
            status: 'registered',
          );
        await pump(
          tester,
          guardian,
          verified: account != 'unverified',
          status: account == 'suspended' ? 'suspended' : 'active',
        );
        expect(find.text('Registro vigente'), findsOneWidget);
        expect(
          find.textContaining(
            'necesitas una cuenta activa y el correo confirmado',
          ),
          findsOneWidget,
        );
        expect(find.text('Cuenta y privacidad'), findsOneWidget);
        expect(find.text('Cancelar Guardián'), findsNothing);
        expect(find.text('Confirmar cancelación'), findsNothing);
        expect(guardian.calls, isEmpty);
        expect(guardian.cancels, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'uncertain transport keeps the same cancellation key and revision',
    (tester) async {
      final guardian = LegalGuardian()
        ..loseFirst = true
        ..value = {
          'plan': {'status': 'active', 'revision': 3},
          'activation': null,
        };
      await pump(tester, guardian);
      await tester.ensureVisible(find.text('Cancelar Guardián'));
      await tester.tap(find.text('Cancelar Guardián'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect(guardian.calls, hasLength(1));
      await tester.ensureVisible(find.text('Reintentar misma cancelación'));
      await tester.tap(find.text('Reintentar misma cancelación'));
      await tester.pumpAndSettle();
      expect(guardian.calls, hasLength(1));
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect(guardian.calls, hasLength(2));
      expect(guardian.calls[1], guardian.calls[0]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'definitive revision conflict requires explicit new confirmation at current revision',
    (tester) async {
      final guardian = LegalGuardian()
        ..conflictFirst = true
        ..value = {
          'plan': {'status': 'active', 'revision': 3},
          'activation': null,
        };
      await pump(tester, guardian);
      await tester.ensureVisible(find.text('Cancelar Guardián'));
      await tester.tap(find.text('Cancelar Guardián'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect(guardian.calls, hasLength(1));
      expect(guardian.calls.single['revision'], 3);
      await tester.ensureVisible(find.text('Preparar nueva cancelación'));
      await tester.tap(find.text('Preparar nueva cancelación'));
      await tester.pumpAndSettle();
      expect(guardian.calls, hasLength(1));
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(guardian.calls, hasLength(1));
      await tester.tap(find.text('Preparar nueva cancelación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect(guardian.calls, hasLength(2));
      expect(guardian.calls[1]['revision'], 4);
      expect(guardian.calls[1]['key'], isNot(guardian.calls[0]['key']));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late old-owner projection is not rendered after sign-out', (
    tester,
  ) async {
    final guardian = LegalGuardian()..readGate = Completer<Json>();
    final identity = await pump(tester, guardian);
    identity.emit(const IdentityEvent(null, signedOut: true));
    await tester.pump();
    guardian.readGate!.complete({
      'plan': {'status': 'active', 'revision': 2},
      'activation': null,
    });
    await tester.pumpAndSettle();
    expect(find.text('Plan activo'), findsNothing);
    expect(guardian.snapshotReads, 0);
    expect(guardian.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
