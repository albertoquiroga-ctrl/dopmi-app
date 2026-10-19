import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';

import 'rescue_test.dart' show FakeRescue, FakeCaseUpdates;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_repository.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;

Json personalMonth(String month) => {
  'month': month,
  'current_month': '2026-10-01',
  'timezone': 'America/Mexico_City',
  'allocated_cents': 9200,
  'cases_supported': 2,
  'case_ids': ['case-one', 'case-two'],
};
Json communityMonth(String month, {String status = 'partial'}) => {
  'month': month,
  'timezone': 'America/Mexico_City',
  'cases_supported': 7,
  'urgent_cases_covered': status == 'not_measured' ? null : 3,
  'measurement_started_at': '2026-10-17T18:00:00Z',
  'measurement_started_on': '2026-10-17',
  'measurement_status': status,
};

class FakeMonthlyImpact implements MonthlyImpactRepository {
  bool fail = false;
  String currentMonth = '2026-10-01';
  final personalRequests = <String?>[], communityRequests = <String?>[];
  @override
  Future<MonthlyPersonalImpact> personal({String? month}) async {
    personalRequests.add(month);
    if (fail) throw StateError('offline');
    return MonthlyPersonalImpact.fromJson({
      ...personalMonth(month ?? currentMonth),
      'current_month': currentMonth,
    });
  }

  @override
  Future<MonthlyCommunityImpact> community({String? month}) async {
    communityRequests.add(month);
    return MonthlyCommunityImpact.fromJson(
      communityMonth(
        month!,
        status: month.compareTo('2026-10-01') < 0
            ? 'not_measured'
            : month == '2026-10-01'
            ? 'partial'
            : 'complete',
      ),
    );
  }
}

class StoryImpactCommunity extends FakeCommunity {
  @override
  Future<List<Json>> personalImpact() async => [
    {
      'case_id': 'case-one',
      'allocated_cents': 9200,
      'public_data': {
        'pet_name': 'Luna',
        'photos': ['approved-luna.jpg'],
      },
    },
  ];
}

class StoryImpactRescue extends FakeRescue {
  StoryImpactRescue(this.status);
  final String status;
  @override
  Future<DataPage<RescueRecord>> completeCaseCatalog(String id) async =>
      DataPage([
        RescueRecord({
          'id': id,
          'kind': 'case',
          'status': status,
          'public_data': {
            'pet_name': 'Luna',
            'photos': ['approved-luna.jpg'],
          },
        }),
      ], 1);
}

void main() {
  for (final status in ['approved', 'closed', 'withdrawn']) {
    final approved = status != 'withdrawn';
    testWidgets(
      'monthly ring opens only currently approved public stories and returns, status=$status',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              monthlyImpactRepositoryProvider.overrideWithValue(
                FakeMonthlyImpact(),
              ),
              communityRepositoryProvider.overrideWithValue(
                StoryImpactCommunity(),
              ),
              rescueRepositoryProvider.overrideWithValue(
                StoryImpactRescue(status),
              ),
              caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
            ],
            child: MaterialApp(
              theme: dopmiTheme(),
              home: const Scaffold(
                body: SingleChildScrollView(child: MonthlyImpactPanel()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ring = find.byKey(const ValueKey('impact-ring-case-one'));
        await tester.ensureVisible(ring);
        await tester.tap(ring);
        // Stories animate continuously; inspect the open route before auto advance.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        if (approved) {
          expect(find.byType(SupportStories), findsOneWidget);
          await tester.tap(find.byTooltip('Cerrar historias'));
          await tester.pumpAndSettle();
          expect(find.byType(SupportStories), findsNothing);
          expect(find.byType(MonthlyImpactPanel), findsOneWidget);
        } else {
          expect(find.byType(SupportStories), findsNothing);
          expect(
            find.text(
              'Las historias públicas de este caso ya no están disponibles.',
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('community distinguishes no historical measurement from zero', () {
    final absent = MonthlyCommunityImpact.fromJson(
      communityMonth('2026-09-01', status: 'not_measured'),
    );
    expect(absent.urgentCasesCovered, isNull);
    expect(
      () => MonthlyCommunityImpact.fromJson({
        ...communityMonth('2026-09-01', status: 'not_measured'),
        'urgent_cases_covered': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => MonthlyPersonalImpact.fromJson({
        ...personalMonth('2026-10-01'),
        'timezone': 'UTC',
      }),
      throwsFormatException,
    );
    expect(
      () => MonthlyPersonalImpact.fromJson({
        ...personalMonth('2026-10-01'),
        'allocated_cents': -1,
      }),
      throwsFormatException,
    );
  });

  testWidgets(
    'resumption refreshes current CDMX month while a historical month stays selected',
    (tester) async {
      final repo = FakeMonthlyImpact();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyImpactRepositoryProvider.overrideWithValue(repo),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: MaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(child: MonthlyImpactPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Septiembre 2026'), findsOneWidget);
      repo.currentMonth = '2026-11-01';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Septiembre 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Octubre 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Noviembre 2026'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Mes siguiente',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(repo.personalRequests, isNot(contains('2026-12-01')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'monthly readings share server month, show real counts and historical gap $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeMonthlyImpact();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              monthlyImpactRepositoryProvider.overrideWithValue(repo),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            ],
            child: MaterialApp(
              theme: dopmiTheme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: MonthlyImpactPanel(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.personalRequests, [null]);
        expect(repo.communityRequests, ['2026-10-01']);
        expect(find.text('Tu impacto'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        try {
          expect(find.bySemanticsLabel(r'$92.00 MXN'), findsOneWidget);
        } finally {
          semantics.dispose();
        }
        expect(find.text('Casos apoyados por la comunidad'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.textContaining('Medición parcial'), findsOneWidget);
        expect(
          find.textContaining('Desde 17/10/2026 (Ciudad de México)'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Mes siguiente',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('Mes anterior'));
        await tester.pumpAndSettle();
        expect(repo.communityRequests.last, '2026-09-01');
        expect(find.text('Sin medición histórica'), findsOneWidget);
        expect(find.text('3'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final layout in [
    (width: 377.0, scale: 1.0),
    (width: 377.0, scale: 1.15),
    (width: 320.0, scale: 2.0),
  ]) {
    testWidgets(
      'historical measurement preserves whole words ${layout.width}/${layout.scale}',
      (tester) async {
        await (FontLoader(
          'Inter',
        )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
        tester.view.physicalSize = Size(layout.width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              monthlyImpactRepositoryProvider.overrideWithValue(
                FakeMonthlyImpact(),
              ),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            ],
            child: MaterialApp(
              theme: dopmiTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(layout.scale),
                ),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: MonthlyImpactPanel(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Mes anterior'));
        await tester.pumpAndSettle();
        const phrase = 'Sin medición histórica';
        final status = find.text(phrase);
        expect(status, findsOneWidget);
        await tester.ensureVisible(status);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(status);
        for (final word in RegExp(r'\S+').allMatches(phrase)) {
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: word.start, extentOffset: word.end),
          );
          expect(boxes, isNotEmpty);
          expect(
            boxes.map((box) => box.top).toSet(),
            hasLength(1),
            reason: '${word.group(0)} must not split across lines',
          );
        }
        expect(paragraph.didExceedMaxLines, isFalse);
        final label = find.text(
          'Casos con gastos urgentes totalmente cubiertos',
        );
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        expect(label.hitTestable(), findsOneWidget);
        expect(find.text('0'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
