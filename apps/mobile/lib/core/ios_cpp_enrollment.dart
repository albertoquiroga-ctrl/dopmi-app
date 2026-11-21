import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'ios_cpp_acquisition.dart';
import 'measurement.dart';

/// Enrolls captured CPP context using this actor's accepted consent revision.
class IosCppEnrollment {
  IosCppEnrollment({
    required this.client,
    required this.acquisition,
    required this.measurement,
    required this.captureReady,
    this.timeout = const Duration(seconds: 5),
  }) : assert(timeout > Duration.zero);

  final SupabaseClient client;
  final IosCppAcquisition acquisition;
  final MeasurementController Function() measurement;
  final Future<void> Function() captureReady;
  final Duration timeout;
  final _consentRevisions = <String, ({int local, int server})>{};

  void consentAccepted(
    String owner, {
    required int localRevision,
    required int serverRevision,
  }) {
    _consentRevisions[owner] = (local: localRevision, server: serverRevision);
  }

  void revoke(String owner) {
    _consentRevisions.remove(owner);
    // revoke invalidates live acquisition eligibility before its queued storage
    // cleanup waits for an older network request to finish.
    unawaited(acquisition.revoke(owner));
  }

  Future<void> record(String owner) async {
    await captureReady();
    final acceptedRevision = _consentRevisions[owner];
    final controller = measurement();
    if (acceptedRevision == null ||
        acceptedRevision.local != controller.analyticsRevision) {
      return;
    }
    bool eligible() =>
        controller.ownerId == owner &&
        controller.analyticsConsentCurrent &&
        controller.analyticsRevision == acceptedRevision.local &&
        client.auth.currentSession?.user.id == owner;
    if (!eligible()) return;
    await acquisition.record(
      owner: owner,
      sessionStillEligible: eligible,
      send: (variant) async {
        final session = await client.auth.getSession().timeout(timeout);
        if (!eligible() ||
            session == null ||
            session.user.id != owner ||
            session.isExpired) {
          throw StateError('Acquisition session changed');
        }
        final result = await client
            .rpc(
              'dopmi_record_ios_cpp_acquisition',
              params: {
                'p_variant': variant,
                'p_expected_consent_revision': acceptedRevision.server,
              },
            )
            .setHeader('Authorization', 'Bearer ${session.accessToken}')
            .timeout(timeout);
        return switch (result is Map ? result['status'] : null) {
          'recorded' => IosCppClaimResult.recorded,
          'already_recorded' => IosCppClaimResult.alreadyRecorded,
          'ineligible' => IosCppClaimResult.ineligible,
          'consent_changed' => IosCppClaimResult.consentChanged,
          _ => throw StateError('Invalid acquisition response'),
        };
      },
    );
  }
}
