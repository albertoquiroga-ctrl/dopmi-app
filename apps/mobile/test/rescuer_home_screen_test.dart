import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescuer_home_screen.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescuer_funnel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

Json homeFixture({String verification = 'approved', int views = 73}) => {
  'verification_status': verification,
  'adoption_counts': {'active': 2, 'review': 1, 'draft': 1, 'corrections': 1},
  'support_counts': {'active': 2, 'review': 1, 'draft': 1, 'corrections': 1},
  'adoption_metrics': {
    'unique_viewers': views,
    'pets_saved': 3,
    'tracking_started_at': '2026-10-05T00:00:00Z',
  },
  'unanswered_conversations': 12,
  'pending_evidence': [
    {
      'expense_id': 'expense-one',
      'case_id': 'case-one',
      'pet_name': 'Rocky',
      'expense_title': 'Veterinario',
      'status': 'draft',
      'urgent': true,
      'progress_percent': 30,
      'editable': true,
    },
    {
      'expense_id': 'expense-two',
      'case_id': 'case-two',
      'pet_name': 'Milo',
      'expense_title': 'Medicina',
      'status': 'changes_requested',
      'urgent': false,
      'progress_percent': 55,
      'editable': true,
    },
  ],
  'recent_activity': [paymentFixture('payment-one', 1500)],
  'payments_unseen_count': 4,
  'payments_cursor': 'home-presented-cursor',
};

Json paymentFixture(String id, int cents) => {
  'id': id,
  'case_id': 'case-one',
  'expense_id': 'expense-one',
  'pet_name': 'Nina',
  'expense_title': 'Veterinario',
  'photo': '',
  'net_cents': cents,
  'occurred_at': DateTime.now().toUtc().toIso8601String(),
  'source': 'direct',
  'transfer_status': 'pending',
};

class HomeRescue extends FakeRescue {
  Json home = homeFixture();
  bool failLoad = false, failAck = false;
  Completer<void>? ackWait;
  final acknowledgements = <String>[];
  final loadedPages = <int>[];
  final responses = <Future<Json>>[];
  Map<int, DataPage<Json>> pages = {
    1: DataPage(
      [
        paymentFixture('payment-one', 1500),
        paymentFixture('payment-two', 2500),
      ],
      3,
      cursor: 'page-one-presented',
    ),
    2: DataPage(
      [
        paymentFixture('payment-two', 2500),
        paymentFixture('payment-three', 7500),
      ],
      3,
      cursor: 'page-two-presented',
    ),
  };
  @override
  Future<Json> dashboardV2() async {
    if (failLoad) throw StateError('network_unavailable');
    if (responses.isNotEmpty) home = await responses.removeAt(0);
    return Map.of(home);
  }

  @override
  Future<RescuerFunnelMetrics> funnel(String period) async =>
      RescuerFunnelMetrics.fromJson({
        'period': period,
        'period_start': '2026-10-01T06:00:00Z',
        'period_end': '2026-11-01T06:00:00Z',
        'as_of': '2026-10-07T03:00:00Z',
        'view_tracking_started_at': '2026-10-05T00:00:00Z',
        'adoption': {
          'views': home['adoption_metrics']['unique_viewers'],
          'favorites': 3,
          'messages': 12,
          'adoptions': 2,
        },
        'support': {
          'donors': 7,
          'active': 2,
          'completed': 1,
          'raised_cents': 1500,
        },
      });

  @override
  Future<DataPage<Json>> receivedActivity(int page) async {
    loadedPages.add(page);
    return pages[page]!;
  }

  @override
  Future<void> acknowledgePayments(String cursor) async {
    acknowledgements.add(cursor);
    if (failAck) throw StateError('network_unavailable');
    if (ackWait != null) await ackWait!.future;
    home = {...home, 'payments_unseen_count': 0};
  }
}

Future<(GoRouter, FakeIdentityRepository)> pumpHome(
  WidgetTester tester,
  HomeRescue rescue, {
  bool large = false,
  double? textScale,
  String initial = '/rescuer',
  bool settle = true,
  CommunityRepository? community,
}) async {
  tester.view.physicalSize = large
      ? const Size(320, 640)
      : const Size(377, 852);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue =
      textScale ?? (large ? 2 : 1);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  await identity.setExperience('rescuer');
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/rescuer', builder: (_, _) => const RescueHomeScreen()),
      GoRoute(
        path: '/rescuer/received-payments',
        builder: (_, _) => const RescuerReceivedPaymentsScreen(),
      ),
      GoRoute(
        path: '/rescuer/photo-tips',
        builder: (_, _) => const RescuerPhotoTipsScreen(),
      ),
      for (final path in [
        '/my-cases',
        '/messages',
        '/profile',
        '/rescuer/profile/edit',
        '/publish',
        '/notifications',
        '/rescue/new',
      ])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
        ),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(identity.changes.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(
          community ?? FakeCommunity(),
        ),
        rescueRepositoryProvider.overrideWithValue(rescue),
      ],
      child: MaterialApp.router(
        theme: dopmiTheme(rescuer: true),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return (router, identity);
}

Future<void> show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'payment transfer states are visible and do not claim a bank deposit',
    (tester) async {
      final rescue = HomeRescue();
      rescue.pages[1] = DataPage(
        [
          for (final state in [
            'not_started',
            'pending',
            'transferred',
            'attention',
          ])
            {...paymentFixture(state, 1500), 'transfer_status': state},
        ],
        4,
        cursor: 'states-presented',
      );
      await pumpHome(
        tester,
        rescue,
        large: true,
        initial: '/rescuer/received-payments',
      );
      for (final label in [
        'Asignado al gasto',
        'Transferencia en proceso',
        'Transferido al saldo',
        'Transferencia por revisar',
      ]) {
        final visibleState = find.textContaining(label);
        await show(tester, visibleState);
        expect(visibleState.hitTestable(), findsOneWidget);
      }
      expect(find.textContaining('Depositado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final large in [false, true]) {
    testWidgets(
      'home grids and selectors preserve summaries and readable text: $large',
      (tester) async {
        final (router, _) = await pumpHome(tester, HomeRescue(), large: large);
        expect(find.text('Hola, Ana'), findsOneWidget);
        await show(tester, find.text('Recibiendo apoyo'));
        await tester.tap(find.text('Recibiendo apoyo'));
        await tester.pumpAndSettle();
        expect(find.text('Donantes'), findsOneWidget);
        expect(find.text('9+'), findsOneWidget);
        expect(find.text('Tu panel de rescate'), findsNothing);
        expect(find.text('Resumen comprobado'), findsNothing);
        expect(find.text('Continuar evidencia'), findsNothing);
        await show(tester, find.text('En adopción'));
        await tester.tap(find.text('En adopción'));
        await tester.pumpAndSettle();
        expect(find.text('73'), findsOneWidget);
        expect(find.text('Adopciones'), findsOneWidget);
        expect(find.byKey(const ValueKey('home-carousel')), findsNothing);
        expect(router.state.uri.path, '/rescuer');
        final supportTab = find.text('Recibiendo apoyo');
        await Scrollable.ensureVisible(
          tester.element(supportTab),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(supportTab.hitTestable(), findsOneWidget);
        await tester.tap(supportTab);
        await tester.pumpAndSettle();
        expect(find.text('Recaudado'), findsOneWidget);
        await show(tester, find.text('Apoyo'));
        await tester.tap(find.text('Apoyo'));
        await tester.pumpAndSettle();
        expect(find.text('Resumen de apoyo'), findsOneWidget);
        final selectedIcon = find.descendant(
          of: find.byKey(const ValueKey('home-quick-support')),
          matching: find.byType(SvgPicture),
        );
        expect(
          tester.widget<SvgPicture>(selectedIcon).colorFilter,
          const ColorFilter.mode(purple, BlendMode.srcIn),
        );
        final review = find.byKey(
          const ValueKey('home-summary-support-review'),
        );
        await show(tester, review);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(
          router.state.uri.toString(),
          '/my-cases?program=support&status=review',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'payment acknowledgement follows presentation and keeps badge on failure',
    (tester) async {
      final rescue = HomeRescue()..failAck = true;
      final (router, _) = await pumpHome(tester, rescue);
      expect(rescue.acknowledgements, isEmpty);
      await tester.tap(find.text('Pagos'));
      await tester.pumpAndSettle();
      expect(rescue.acknowledgements, ['home-presented-cursor']);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('+\$15'), findsOneWidget);
      final retry = find.text('Reintentar contador');
      await show(tester, retry);
      rescue.failAck = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(rescue.acknowledgements, [
        'home-presented-cursor',
        'home-presented-cursor',
      ]);
      expect(find.text('4'), findsNothing);
      await show(tester, find.text('Ver todo'));
      await tester.tap(find.text('Ver todo'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile');
      expect(rescue.acknowledgements.last, 'home-presented-cursor');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'received history deduplicates pages and acknowledges only page cursors',
    (tester) async {
      final rescue = HomeRescue();
      await pumpHome(
        tester,
        rescue,
        large: true,
        initial: '/rescuer/received-payments',
      );
      expect(rescue.loadedPages, [1]);
      expect(rescue.acknowledgements, ['page-one-presented']);
      await show(tester, find.text('Cargar más pagos'));
      await tester.tap(find.text('Cargar más pagos'));
      await tester.pumpAndSettle();
      expect(rescue.loadedPages, [1, 2]);
      expect(rescue.acknowledgements, [
        'page-one-presented',
        'page-two-presented',
      ]);
      expect(find.text('+\$25'), findsOneWidget);
      expect(find.text('+\$75'), findsOneWidget);
      expect(find.text('Cargar más pagos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed dashboard is retriable without invented zero metrics', (
    tester,
  ) async {
    final rescue = HomeRescue()..failLoad = true;
    await pumpHome(tester, rescue);
    expect(find.text('¿Empezamos?'), findsNothing);
    expect(find.text('73'), findsNothing);
    expect(find.text('Volver a intentar'), findsOneWidget);
    rescue.failLoad = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En adopción'));
    await tester.pumpAndSettle();
    expect(find.text('73'), findsOneWidget);
    expect(rescue.acknowledgements, isEmpty);
  });

  testWidgets(
    'own adoption summaries remain usable while rescue verification is pending',
    (tester) async {
      final rescue = HomeRescue()
        ..home = homeFixture(verification: 'submitted');
      final (router, _) = await pumpHome(tester, rescue);
      expect(find.text('Completar mi perfil'), findsOneWidget);
      expect(find.text('Simular verificación'), findsNothing);
      await show(tester, find.text('Adopción'));
      await tester.tap(find.text('Adopción'));
      await tester.pumpAndSettle();
      final drafts = find.byKey(const ValueKey('home-summary-adoption-draft'));
      await show(tester, drafts);
      await tester.tap(drafts);
      await tester.pumpAndSettle();
      expect(
        router.state.uri.toString(),
        '/my-cases?program=adoption&status=draft',
      );
    },
  );

  testWidgets('Tips opens a five-tip modal and returns to the same home', (
    tester,
  ) async {
    final (router, _) = await pumpHome(tester, HomeRescue(), large: true);
    await show(tester, find.text('Tips para mejores fotos'));
    await tester.tap(find.text('Tips para mejores fotos'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rescuer');
    expect(find.text('Luz natural'), findsOneWidget);
    expect(find.text('Sin filtros fuertes'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rescuer');
    expect(tester.takeException(), isNull);
  });

  testWidgets('late dashboard response does not cross accounts', (
    tester,
  ) async {
    final pending = Completer<Json>();
    final rescue = HomeRescue()..responses.add(pending.future);
    final (_, identity) = await pumpHome(tester, rescue, settle: false);
    rescue.responses.add(Future.value(homeFixture(views: 42)));
    identity.emit(
      const IdentityEvent(
        Identity('two', 'other@example.test', verified: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('En adopción'));
    await tester.pumpAndSettle();
    pending.complete(homeFixture(views: 73));
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('73'), findsNothing);
    expect(rescue.acknowledgements, isEmpty);
  });

  testWidgets('received history clears immediately when the actor changes', (
    tester,
  ) async {
    final rescue = HomeRescue();
    final (_, identity) = await pumpHome(
      tester,
      rescue,
      initial: '/rescuer/received-payments',
    );
    expect(find.text('+\$15'), findsOneWidget);
    identity.emit(
      const IdentityEvent(
        Identity('two', 'other@example.test', verified: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+\$15'), findsNothing);
    expect(find.text('Tu sesión cambió. Vuelve a Inicio.'), findsOneWidget);
    expect(rescue.loadedPages, [1]);
  });

  testWidgets('Samsung 115 percent preserves complete labels in four columns', (
    tester,
  ) async {
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await fonts.load();
    await pumpHome(tester, HomeRescue(), textScale: 1.15);
    final labels = ['Adopción', 'Apoyo', 'Mensajes', 'Pagos'];
    double? row;
    for (final label in labels) {
      final id = {
        'Adopción': 'adoption',
        'Apoyo': 'support',
        'Mensajes': 'messages',
        'Pagos': 'payments',
      }[label]!;
      final finder = find.descendant(
        of: find.byKey(ValueKey('home-quick-$id')),
        matching: find.text(label),
      );
      await show(tester, finder);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: label.length),
      );
      expect(
        boxes,
        hasLength(1),
        reason: '$label debe conservar la palabra completa',
      );
      expect(boxes.single.right, lessThanOrEqualTo(paragraph.size.width + .5));
      final y = tester.getTopLeft(finder).dy;
      row ??= y;
      expect(y, closeTo(row, .5));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal funnel cards preserve the source 92 pixel geometry', (
    tester,
  ) async {
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await fonts.load();
    await pumpHome(tester, HomeRescue());
    await show(tester, find.text('Recibiendo apoyo'));
    await tester.tap(find.text('Recibiendo apoyo'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('home-metric-donors'));
    expect(tester.getSize(card).height, closeTo(92, .01));
    final label = find.descendant(of: card, matching: find.text('Donantes'));
    expect(
      tester.getTopLeft(label).dy - tester.getTopLeft(card).dy,
      closeTo(51, .01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('program tabs reveal full support label by drag at 200 percent', (
    tester,
  ) async {
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await fonts.load();
    await pumpHome(tester, HomeRescue(), large: true);
    final support = find.text('Recibiendo apoyo');
    final scroller = find
        .ancestor(of: support, matching: find.byType(SingleChildScrollView))
        .first;
    await tester.drag(scroller, const Offset(-400, 0));
    await tester.pumpAndSettle();
    final labelRect = tester.getRect(support);
    final viewportRect = tester.getRect(scroller);
    expect(labelRect.left, greaterThanOrEqualTo(viewportRect.left - .5));
    expect(labelRect.right, lessThanOrEqualTo(viewportRect.right + .5));
    await tester.tap(support);
    await tester.pumpAndSettle();
    expect(find.text('Donantes'), findsOneWidget);
    expect(find.text('Recaudado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support grid replaces evidence cards without changing drafts', (
    tester,
  ) async {
    final rescue = HomeRescue();
    rescue.home['pending_evidence'][1]['status'] = 'draft';
    await pumpHome(tester, rescue);
    await show(tester, find.text('Recibiendo apoyo'));
    await tester.tap(find.text('Recibiendo apoyo'));
    await tester.pumpAndSettle();
    expect(find.text('Donantes'), findsOneWidget);
    expect(find.text('Recaudado'), findsOneWidget);
    expect(rescue.home['pending_evidence'][0]['progress_percent'], 30);
    expect(rescue.home['pending_evidence'][1]['progress_percent'], 55);
    expect(rescue.home['pending_evidence'][1]['status'], 'draft');
    expect(find.text('Continuar evidencia'), findsNothing);
  });
}
