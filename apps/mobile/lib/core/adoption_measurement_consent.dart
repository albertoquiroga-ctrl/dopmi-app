import 'package:supabase_flutter/supabase_flutter.dart';

/// Orders optional measurement intentions without retrying an uncertain write.
/// Every accepted CAS advances the revision, even if consent is already equal.
class AdoptionMeasurementConsent {
  AdoptionMeasurementConsent(
    this.client, {
    this.timeout = const Duration(seconds: 10),
    this.maxConflicts = 3,
  }) : assert(timeout > Duration.zero),
       assert(maxConflicts >= 0);

  final SupabaseClient client;
  final Duration timeout;

  /// Maximum OFF retries after a definitive conflict, excluding the first CAS.
  final int maxConflicts;
  final _intentions = <String, int>{};

  Future<bool> Function()? prepare(
    String owner,
    bool enabled, {
    required bool Function() stillEligible,
  }) {
    final captured = client.auth.currentSession;
    if (captured == null || captured.user.id != owner) return null;
    final intention = (_intentions[owner] ?? 0) + 1;
    _intentions[owner] = intention;

    bool current() =>
        _intentions[owner] == intention &&
        (!enabled ||
            (client.auth.currentSession?.user.id == owner && stillEligible()));

    Future<String?> token() async {
      if (!current()) return null;
      final session = client.auth.currentSession;
      // OFF can outlive sign-out or an account switch. Never let the next
      // account's Authorization header replace the captured actor's token.
      if (session?.user.id != owner) {
        return !enabled && !captured.isExpired ? captured.accessToken : null;
      }
      final refreshed = await client.auth.getSession().timeout(timeout);
      if (!current() ||
          refreshed == null ||
          refreshed.user.id != owner ||
          refreshed.isExpired) {
        return null;
      }
      return refreshed.accessToken;
    }

    return () async {
      try {
        if (!current()) return false;
        final stateToken = await token();
        if (!current() || stateToken == null) return false;
        final state = await client
            .rpc('dopmi_adoption_measurement_state')
            .setHeader('Authorization', 'Bearer $stateToken')
            .timeout(timeout);
        if (!current()) return false;
        var revision = _revision(state);
        if (revision == null) return false;

        for (var conflicts = 0; ; conflicts++) {
          if (!current()) return false;
          final writeToken = await token();
          if (!current() || writeToken == null) return false;
          final result = await client
              .rpc(
                'dopmi_set_adoption_measurement_v2',
                params: {'consent': enabled, 'expected_revision': revision},
              )
              .setHeader('Authorization', 'Bearer $writeToken')
              .timeout(timeout);
          if (!current()) return false;
          final next = _revision(result);
          if (next == null || result is! Map || result['applied'] is! bool) {
            return false;
          }
          if (result['applied'] == true) return result['consent'] == enabled;
          // A different device may have made the newer decision. Local intent
          // counters cannot establish that ON should override it, even when
          // the returned consent is true. Skip attribution until a fresh sync.
          if (enabled) return false;
          if (conflicts >= maxConflicts) return false;
          revision = next;
        }
      } catch (_) {
        // In particular, a timeout does not prove that the POST was rejected.
        // Only OFF can retry a definitive revision conflict safely.
        return false;
      }
    };
  }

  static int? _revision(Object? result) {
    if (result is! Map || result['consent'] is! bool) return null;
    final revision = result['revision'];
    return revision is int && revision >= 0 ? revision : null;
  }
}
