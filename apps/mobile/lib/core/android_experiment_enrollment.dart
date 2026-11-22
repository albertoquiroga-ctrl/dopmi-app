import 'package:supabase_flutter/supabase_flutter.dart';

import 'android_rescuer_acquisition.dart';
import 'measurement.dart';

/// Keeps an install claim bound to the actor's reconciled server consent.
/// The registry, rather than the client, supplies a placement's arm and variant.
class AndroidExperimentEnrollment {
  AndroidExperimentEnrollment({
    required this.client,
    required this.acquisition,
    required this.measurement,
    this.timeout = const Duration(seconds: 10),
  }) : assert(timeout > Duration.zero);

  final SupabaseClient client;
  final AndroidRescuerAcquisition acquisition;
  final MeasurementController Function() measurement;
  final Duration timeout;
  final _consentRevisions = <String, ({int local, int server})>{};

  void consentAccepted(
    String owner, {
    required int localRevision,
    required int serverRevision,
  }) {
    if (localRevision < 0 || serverRevision < 0) return;
    _consentRevisions[owner] = (local: localRevision, server: serverRevision);
  }

  void revoke(String owner) {
    // Do not reset install ownership/processed flags on opt-out or account switch.
    _consentRevisions.remove(owner);
  }

  Future<void> record(String owner) async {
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

    Future<String> sessionToken() async {
      final session = await client.auth.getSession().timeout(timeout);
      if (!eligible() ||
          session == null ||
          session.user.id != owner ||
          session.isExpired) {
        throw StateError('Acquisition session changed');
      }
      return session.accessToken;
    }

    await acquisition.record(
      owner: owner,
      sessionStillEligible: eligible,
      send: (variant, clickedAt) async {
        final token = await sessionToken();
        await client
            .rpc(
              'dopmi_record_android_rescuer_acquisition',
              params: {
                'p_variant': variant,
                'p_clicked_at': clickedAt.toIso8601String(),
              },
            )
            .setHeader('Authorization', 'Bearer $token')
            .timeout(timeout);
      },
      sendPlacement: (placement, clickedAt) async {
        final token = await sessionToken();
        final result = await client
            .rpc(
              'dopmi_record_android_experiment_acquisition',
              params: {
                'p_placement_token': placement,
                'p_clicked_at': clickedAt.toIso8601String(),
                'p_expected_consent_revision': acceptedRevision.server,
              },
            )
            .setHeader('Authorization', 'Bearer $token')
            .timeout(timeout);
        final status = switch (result is Map ? result['status'] : null) {
          'recorded' => AndroidExperimentClaimResult.recorded,
          'already_recorded' => AndroidExperimentClaimResult.alreadyRecorded,
          'ineligible' => AndroidExperimentClaimResult.ineligible,
          'consent_changed' => AndroidExperimentClaimResult.consentChanged,
          'invalid_placement' => AndroidExperimentClaimResult.invalidPlacement,
          _ => throw StateError('Invalid acquisition response'),
        };
        if (status == AndroidExperimentClaimResult.consentChanged &&
            _consentRevisions[owner] == acceptedRevision) {
          // A new server revision must be reconciled, never guessed or retried ON.
          _consentRevisions.remove(owner);
        }
        return status;
      },
    );
  }
}
