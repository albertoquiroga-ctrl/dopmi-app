import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/features/payments/guardian_registration.dart';

Map<String, dynamic> fixture(String paymentState) => {
  'id': '72000000-0000-4000-8000-000000000001',
  'key': '72000000-0000-4000-8000-000000000002',
  'status': 'registered',
  'gross_cents': 2000,
  'revision': 1,
  'registered_at': '2026-10-14T10:00:00Z',
  'next_evaluation_at': '2026-11-14T10:00:00Z',
  'consent_version': 'guardian-registration-2026-10-14',
  'payment': {
    'state': paymentState,
    'attempt_id': '72000000-0000-4000-8000-000000000003',
    'allocated_cents': paymentState == 'allocated' ? 1860 : 0,
    'refund_cents': paymentState == 'refund_pending' ? 2000 : 0,
  },
};

void main() {
  test(
    'confirmed canceled attempt remains visible on a continuing registration',
    () {
      final result = GuardianRegistration.fromJson(fixture('canceled'));
      expect(result.status, 'registered');
      expect(result.nextEvaluationAt, isNotNull);
      expect(result.summary, contains('Este intento terminó sin cobro'));
      expect(result.summary, isNot(contains('Registro preparado')));
      expect(result.hasConfirmedImpact, false);
    },
  );
  test('only server allocation confirms impact, never method or processor', () {
    for (final state in [
      'not_evaluated',
      'prepared',
      'processing',
      'requires_action',
      'processor_confirmed',
      'refund_pending',
      'refunded',
      'canceled',
      'skipped',
      'expired',
    ]) {
      expect(
        GuardianRegistration.fromJson(fixture(state)).hasConfirmedImpact,
        false,
      );
    }
    expect(
      GuardianRegistration.fromJson(fixture('allocated')).hasConfirmedImpact,
      true,
    );
  });
  test('unknown and incomplete receipts do not become confirmed state', () {
    for (final change in [
      {'status': 'active'},
      {'id': 'other'},
      {'gross_cents': 1999},
      {'revision': -1},
      {'next_evaluation_at': null},
      {'consent_version': 'old'},
      {
        'payment': {'state': 'paid'},
      },
    ]) {
      expect(
        () => GuardianRegistration.fromJson({
          ...fixture('processing'),
          ...change,
        }),
        throwsFormatException,
      );
    }
  });
  test(
    'canceled registration keeps payment uncertainty and no next charge',
    () {
      final result = GuardianRegistration.fromJson({
        ...fixture('processing'),
        'status': 'canceled',
        'next_evaluation_at': null,
      });
      expect(result.nextEvaluationAt, isNull);
      expect(result.paymentState, GuardianRegistrationPaymentState.processing);
      expect(result.hasConfirmedImpact, false);
    },
  );
  test(
    'omitted monthly interval stays separate from the previous contribution',
    () {
      final result = GuardianRegistration.fromJson({
        ...fixture('allocated'),
        'evaluation': {'status': 'skipped', 'cycle_number': 2},
      });
      expect(result.hasConfirmedImpact, true);
      expect(result.evaluationStatus, 'skipped');
      expect(result.evaluationCycle, 2);
    },
  );
}
