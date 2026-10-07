import '../adoption/community_repository.dart';

/// Owner-only aggregates. Dates and counts are authoritative server values.
class RescuerFunnelMetrics {
  const RescuerFunnelMetrics({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.asOf,
    required this.viewTrackingStartedAt,
    required this.views,
    required this.favorites,
    required this.messages,
    required this.adoptions,
    required this.donors,
    required this.activeCases,
    required this.completedCases,
    required this.raisedCents,
  });

  factory RescuerFunnelMetrics.fromJson(Json value) {
    final adoption = Json.from(value['adoption'] as Map);
    final support = Json.from(value['support'] as Map);
    int count(Json source, String key) => (source[key] as num).toInt();
    DateTime date(String key) => DateTime.parse(value[key] as String);
    return RescuerFunnelMetrics(
      period: value['period'] as String,
      periodStart: date('period_start'),
      periodEnd: date('period_end'),
      asOf: date('as_of'),
      viewTrackingStartedAt: date('view_tracking_started_at'),
      views: count(adoption, 'views'),
      favorites: count(adoption, 'favorites'),
      messages: count(adoption, 'messages'),
      adoptions: count(adoption, 'adoptions'),
      donors: count(support, 'donors'),
      activeCases: count(support, 'active'),
      completedCases: count(support, 'completed'),
      raisedCents: count(support, 'raised_cents'),
    );
  }

  final String period;
  final DateTime periodStart, periodEnd, asOf, viewTrackingStartedAt;
  final int views, favorites, messages, adoptions;
  final int donors, activeCases, completedCases, raisedCents;
}
