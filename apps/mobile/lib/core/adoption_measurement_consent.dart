import 'package:supabase_flutter/supabase_flutter.dart';

import 'usage_analytics_choice.dart';

/// Orders optional measurement intentions without retrying an uncertain write.
/// Every accepted CAS advances the revision, even if consent is already equal.
class AdoptionMeasurementConsent implements UsageAnalyticsChoiceStore {
  AdoptionMeasurementConsent(
    SupabaseClient client, {
    this.timeout = const Duration(seconds: 10),
    this.maxConflicts = 3,
  }) : _client = client,
       _getClient = null,
       assert(timeout > Duration.zero),
       assert(maxConflicts >= 0);

  AdoptionMeasurementConsent.deferred(
    SupabaseClient Function() getClient, {
    this.timeout = const Duration(seconds: 10),
    this.maxConflicts = 3,
  }) : _client = null,
       _getClient = getClient,
       assert(timeout > Duration.zero),
       assert(maxConflicts >= 0);

  final SupabaseClient? _client;
  final SupabaseClient Function()? _getClient;
  SupabaseClient get client => _client ?? _getClient!();
  final Duration timeout;

  /// Maximum OFF retries after a definitive conflict, excluding the first CAS.
  final int maxConflicts;
  final _intentions = <String, int>{};

  @override
  Future<UsageAnalyticsChoice> read(String owner) async {
    if (client.auth.currentSession?.user.id != owner) {
      throw StateError('analytics_owner_changed');
    }
    final session = await client.auth.getSession().timeout(timeout);
    if (session == null ||
        session.isExpired ||
        session.user.id != owner ||
        client.auth.currentSession?.user.id != owner) {
      throw StateError('analytics_owner_changed');
    }
    final state = await client
        .rpc('dopmi_adoption_measurement_state')
        .setHeader('Authorization', 'Bearer ${session.accessToken}')
        .timeout(timeout);
    if (client.auth.currentSession?.user.id != owner) {
      throw StateError('analytics_owner_changed');
    }
    return UsageAnalyticsChoice.fromJson(state);
  }

  @override
  Future<UsageAnalyticsChoiceResult> save(
    String owner,
    bool enabled,
    int expectedRevision,
  ) async {
    final captured = client.auth.currentSession;
    if (captured == null || captured.user.id != owner || expectedRevision < 0) {
      throw StateError('analytics_owner_changed');
    }
    final intention = (_intentions[owner] ?? 0) + 1;
    _intentions[owner] = intention;
    bool current() =>
        _intentions[owner] == intention &&
        (!enabled || client.auth.currentSession?.user.id == owner);
    var revision = expectedRevision;
    for (var conflicts = 0; ; conflicts++) {
      if (!current()) throw StateError('analytics_choice_superseded');
      final session = client.auth.currentSession?.user.id == owner
          ? await client.auth.getSession().timeout(timeout)
          : (!enabled && !captured.isExpired ? captured : null);
      if (!current() ||
          session == null ||
          session.isExpired ||
          session.user.id != owner) {
        throw StateError('analytics_owner_changed');
      }
      // An uncertain POST is never repeated. Only a definitive OFF conflict
      // can advance to the returned server revision and send another request.
      final response = await client
          .rpc(
            'dopmi_choose_usage_analytics',
            params: {
              'consent': enabled,
              'expected_revision': revision,
              'notice_version': usageAnalyticsNoticeVersion,
            },
          )
          .setHeader('Authorization', 'Bearer ${session.accessToken}')
          .timeout(timeout);
      if (!current()) throw StateError('analytics_choice_superseded');
      final state = UsageAnalyticsChoice.fromJson(response);
      if (response is! Map || response['applied'] is! bool) {
        throw const FormatException('Elección de analítica no confirmada');
      }
      final applied = response['applied'] == true;
      if (applied &&
          (!state.hasChoice ||
              state.consent != enabled ||
              state.noticeVersion != usageAnalyticsNoticeVersion)) {
        throw const FormatException('Elección de analítica no confirmada');
      }
      if (applied || enabled || conflicts >= maxConflicts) {
        return UsageAnalyticsChoiceResult(state: state, applied: applied);
      }
      revision = state.revision;
    }
  }

  Future<bool> Function()? prepare(
    String owner,
    bool enabled, {
    required bool Function() stillEligible,
    void Function(int revision)? onAcceptedRevision,
    bool restoreOnly = false,
    Future<void> Function()? onRevoked,
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
        if (restoreOnly && enabled) {
          if (state is Map &&
              state['has_choice'] == true &&
              state['consent'] == false) {
            await onRevoked?.call();
            return false;
          }
          if (state is! Map ||
              state['has_choice'] != true ||
              state['consent'] != true) {
            return false;
          }
          onAcceptedRevision?.call(revision);
          return true;
        }

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
          if (result['applied'] == true) {
            if (result['consent'] != enabled) return false;
            // Only this response proves which CAS revision was accepted. OFF
            // may finish for a captured actor after sign-out, but its revision
            // must not become acquisition state for the next signed-in actor.
            if (client.auth.currentSession?.user.id == owner) {
              try {
                onAcceptedRevision?.call(next);
              } catch (_) {
                // An optional observer cannot undo confirmed acceptance.
              }
            }
            return true;
          }
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
