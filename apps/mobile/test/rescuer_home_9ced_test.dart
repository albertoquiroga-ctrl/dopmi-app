import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescuer_funnel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'rescuer_home_screen_test.dart'
    show HomeRescue, homeFixture, pumpHome, show;

RescuerFunnelMetrics metricFixture(
  String period, {
  int views = 73,
  int favorites = 28,
  int messages = 12,
  int adoptions = 3,
  int donors = 7,
  int active = 2,
  int completed = 1,
  int raised = 30500,
  String trackingStartedAt = '2026-10-05T00:00:00Z',
}) => RescuerFunnelMetrics.fromJson({
  'period': period,
  'period_start': '2026-10-01T06:00:00Z',
  'period_end': '2026-11-01T06:00:00Z',
  'as_of': '2026-10-07T03:00:00Z',
  'view_tracking_started_at': trackingStartedAt,
  'adoption': {
    'views': views,
    'favorites': favorites,
    'messages': messages,
    'adoptions': adoptions,
  },
  'support': {
    'donors': donors,
    'active': active,
    'completed': completed,
    'raised_cents': raised,
  },
});

class PeriodHomeRescue extends HomeRescue {
  final periods = <String>[];
  final pending = <String, Completer<RescuerFunnelMetrics>>{};
  final metrics = <String, RescuerFunnelMetrics>{
    'month': metricFixture('month'),
    'week': metricFixture('week', views: 41, donors: 4, raised: 10001),
    'yesterday': metricFixture('yesterday', views: 9, donors: 2, raised: 3501),
  };
  bool failFunnel = false;

  @override
  Future<RescuerFunnelMetrics> funnel(String period) async {
    periods.add(period);
    if (failFunnel) throw StateError('offline');
    if (pending.containsKey(period)) return pending[period]!.future;
    return metrics[period]!;
  }
}

class RecentHomeCommunity extends FakeCommunity {
  int inboxLoads = 0, reads = 0, sends = 0;
  bool fail = false;
  final threadRows = <Json>[
    {
      'id': '8833a306-b3eb-4b1b-92d4-34fda0e1bc9a',
      'pet_name': 'Luna',
      'participant_name': 'Ana',
      'last_message': 'Quiero conocerla',
      'unread_count': 2,
      'photo': '',
      'status': 'active',
      'updated_at': '2026-10-05T18:00:00Z',
    },
    {
      'id': 'a8e03436-97d8-45b8-9216-7223875a8c6f',
      'pet_name': 'Toby',
      'participant_name': 'Luis',
      'last_message': 'Gracias',
      'unread_count': 0,
      'photo': '',
      'status': 'active',
      'updated_at': '2026-10-06T18:00:00Z',
    },
  ];
  @override
  Future<DataPage<Json>> rescuerThreads(
    int page, {
    String? groupId,
    bool unreadOnly = false,
    bool history = false,
  }) async {
    inboxLoads++;
    if (fail) throw StateError('offline');
    return DataPage(List.of(threadRows), threadRows.length);
  }

  @override
  Future<void> readThread(String id) async {
    reads++;
  }

  @override
  Future<Json> sendMessage(
    String threadId,
    String messageId,
    String body,
  ) async {
    sends++;
    return {};
  }
}

void main() {
  testWidgets('funnel coverage uses the Mexico day and explains snapshots', (
    tester,
  ) async {
    final rescue = PeriodHomeRescue();
    rescue.metrics['month'] = metricFixture(
      'month',
      trackingStartedAt: '2026-10-07T03:48:58Z',
    );
    await pumpHome(tester, rescue);
    expect(
      find.text(
        'Activos y completados al momento. Recaudado es apoyo neto asignado.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('En adopción'));
    await tester.pumpAndSettle();
    expect(
      find.text('Favoritos vigentes del período. Vistas desde 6/10/2026.'),
      findsOneWidget,
    );
    expect(find.textContaining('7/10/2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'default support and period controls use exact server aggregates',
    (tester) async {
      final rescue = PeriodHomeRescue();
      await pumpHome(tester, rescue);
      expect(rescue.periods, ['month']);
      expect(find.byKey(const ValueKey('home-funnel-support')), findsOneWidget);
      expect(find.text('Rescatista verificado'), findsOneWidget);
      expect(find.text('Donantes'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-period-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(rescue.periods, ['month', 'yesterday']);
      expect(find.byKey(const ValueKey('home-metric-donors')), findsOneWidget);
      expect(find.text('7'), findsNothing);
      await tester.tap(find.text('En adopción'));
      await tester.pumpAndSettle();
      expect(find.text('9'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(rescue.acknowledgements, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('historic outcomes stay visible with no current active cases', (
    tester,
  ) async {
    final rescue = PeriodHomeRescue();
    rescue.home = {
      ...homeFixture(),
      'adoption_counts': {
        'active': 0,
        'draft': 0,
        'review': 0,
        'corrections': 0,
      },
      'support_counts': {
        'active': 0,
        'draft': 0,
        'review': 0,
        'corrections': 0,
      },
      'pending_evidence': <Json>[],
      'recent_activity': <Json>[],
      'unanswered_conversations': 0,
      'payments_unseen_count': 0,
    };
    rescue.metrics['month'] = metricFixture('month', active: 0, adoptions: 3);
    await pumpHome(tester, rescue);
    expect(find.text('Recaudado'), findsOneWidget);
    expect(find.text('¿Empezamos?'), findsNothing);
    await tester.tap(find.text('En adopción'));
    await tester.pumpAndSettle();
    expect(find.text('Adopciones'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-metric-adoptions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed metrics can retry without presenting invented zeros', (
    tester,
  ) async {
    final rescue = PeriodHomeRescue()..failFunnel = true;
    await pumpHome(tester, rescue);
    expect(find.byKey(const ValueKey('home-metric-donors')), findsNothing);
    expect(find.text('Volver a intentar'), findsOneWidget);
    rescue.failFunnel = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    expect(rescue.periods, ['month', 'month']);
    expect(rescue.acknowledgements, isEmpty);
  });

  testWidgets('late previous-period response never replaces selected results', (
    tester,
  ) async {
    final rescue = PeriodHomeRescue();
    final old = Completer<RescuerFunnelMetrics>();
    rescue.pending['month'] = old;
    await pumpHome(tester, rescue, settle: false);
    await tester.tap(find.byKey(const ValueKey('home-period-filter')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Esta semana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    old.complete(metricFixture('month', donors: 97));
    await tester.pumpAndSettle();
    expect(find.text('97'), findsNothing);
    expect(find.byKey(const ValueKey('home-funnel-support')), findsOneWidget);
    expect(rescue.periods, ['month', 'week']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recent messages open the UUID without response or payment writes',
    (tester) async {
      final rescue = PeriodHomeRescue();
      final community = RecentHomeCommunity();
      final (router, _) = await pumpHome(tester, rescue, community: community);
      final messages = find.byKey(const ValueKey('home-quick-messages'));
      await show(tester, messages);
      await tester.tap(messages);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/rescuer');
      expect(find.text('Mensajes recientes'), findsOneWidget);
      expect(find.text('Luna · Ana'), findsOneWidget);
      expect(community.inboxLoads, 1);
      expect(community.reads, 0);
      expect(community.sends, 0);
      expect(rescue.acknowledgements, isEmpty);
      const id = '8833a306-b3eb-4b1b-92d4-34fda0e1bc9a';
      final row = find.byKey(const ValueKey('home-message-$id'));
      await show(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/messages/$id');
      expect(community.reads, 0);
      expect(community.sends, 0);
      expect(rescue.acknowledgements, isEmpty);
    },
  );

  testWidgets(
    'recent-message failures retry without fabricating conversations',
    (tester) async {
      final community = RecentHomeCommunity()..fail = true;
      await pumpHome(tester, PeriodHomeRescue(), community: community);
      final messages = find.byKey(const ValueKey('home-quick-messages'));
      await show(tester, messages);
      await tester.tap(messages);
      await tester.pumpAndSettle();
      expect(find.text('Luna · Ana'), findsNothing);
      final retry = find.text('Volver a intentar');
      await show(tester, retry);
      community.fail = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Luna · Ana'), findsOneWidget);
      expect(community.reads, 0);
    },
  );
}
