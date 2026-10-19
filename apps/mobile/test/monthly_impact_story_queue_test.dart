import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_panel.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'community_test.dart' show FakeCommunity;
import 'monthly_impact_test.dart' show FakeMonthlyImpact;
import 'rescue_test.dart' show FakeCaseUpdates;
import 'support_stories_test.dart' show StoryRepository, story, tapStorySide;

class QueueImpactCommunity extends FakeCommunity {
  QueueImpactCommunity(this.third);
  final bool third;
  @override
  Future<List<Json>> personalImpact() async => [
    for (final id in [
      'case-one',
      'case-one',
      'case-two',
      if (third) 'case-three',
    ])
      {
        'case_id': id,
        'allocated_cents': 9200,
        'public_data': {
          'pet_name': id,
          'photos': id == 'case-one' ? ['one/a', 'one/b'] : ['$id/a'],
        },
      },
  ];
}

class QueueMonthlyImpact extends FakeMonthlyImpact {
  QueueMonthlyImpact(this.third);
  final bool third;
  @override
  Future<MonthlyPersonalImpact> personal({String? month}) async =>
      MonthlyPersonalImpact(
        month: month ?? currentMonth,
        currentMonth: currentMonth,
        allocatedCents: third ? 27600 : 18400,
        casesSupported: third ? 3 : 2,
        caseIds: ['case-one', 'case-two', if (third) 'case-three'],
      );
}

class QueueImpactRescue extends StoryRepository {
  QueueImpactRescue({this.revokeSecond = false});
  final bool revokeSecond;
  final catalogReads = <String>[];
  final failedCases = <String>{};
  final withdrawnCases = <String>{};
  final emptyPhotoCases = <String>{};
  final pendingCases = <String, Completer<void>>{};
  @override
  Future<DataPage<RescueRecord>> completeCaseCatalog(String id) async {
    catalogReads.add(id);
    await pendingCases[id]?.future;
    if (failedCases.contains(id)) {
      throw StateError('Synthetic public catalog unavailable');
    }
    final photos = emptyPhotoCases.contains(id)
        ? <String>[]
        : id == 'case-one'
        ? ['one/a', 'one/b']
        : ['$id/a'];
    return DataPage([
      story(
        id,
        photos,
        status:
            (revokeSecond && id == 'case-two') || withdrawnCases.contains(id)
            ? 'withdrawn'
            : 'approved',
      ),
      // A scoped catalog can include other records; none can enter the queue.
      story('unrelated-public-case', ['unrelated/photo']),
    ], 2);
  }
}

void main() {
  Future<QueueImpactRescue> start(
    WidgetTester tester, {
    bool third = false,
    bool revokeSecond = false,
    QueueImpactRescue? repository,
  }) async {
    tester.view.physicalSize = const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = repository ?? QueueImpactRescue(revokeSecond: revokeSecond);
    final runtime = PhotoRuntime(
      store: MemoryPhotoStore(),
      download: (_, _) async =>
          Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 24))),
    );
    addTearDown(runtime.dispose);
    await tester.runAsync(() async {
      for (final path in [
        'one/a',
        'one/b',
        'case-two/a',
        if (third) 'case-three/a',
      ]) {
        await runtime.load(rescuePhotoSource(repo, path), width: 384);
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyImpactRepositoryProvider.overrideWithValue(
            QueueMonthlyImpact(third),
          ),
          communityRepositoryProvider.overrideWithValue(
            QueueImpactCommunity(third),
          ),
          rescueRepositoryProvider.overrideWithValue(repo),
          caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
          photoRuntimeProvider.overrideWithValue(runtime),
        ],
        child: MaterialApp(
          theme: dopmiTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: MonthlyImpactPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> open(WidgetTester tester, String id) async {
    final ring = find.byKey(ValueKey('impact-ring-$id'));
    await tester.ensureVisible(ring);
    await tester.tap(ring);
    await tester.pumpAndSettle();
    expect(find.byType(SupportStories), findsOneWidget);
  }

  String photo(WidgetTester tester) =>
      tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path;

  Future<void> next(WidgetTester tester) async {
    await tapStorySide(tester, next: true);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'monthly first ring follows its photo segments then next rail case and closes at end',
    (tester) async {
      final repo = await start(tester);
      await open(tester, 'case-one');
      expect(
        tester
            .widget<SupportStories>(find.byType(SupportStories))
            .records
            .map((record) => record.id)
            .toList(),
        ['case-one', 'case-two'],
      );
      expect(repo.catalogReads, ['case-one', 'case-two']);
      expect(photo(tester), 'one/a');
      await next(tester);
      expect(photo(tester), 'one/b');
      await next(tester);
      expect(photo(tester), 'case-two/a');
      await next(tester);
      expect(find.byType(SupportStories), findsNothing);
      expect(find.byType(MonthlyImpactPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'monthly second ring starts at selected last case and closes without cycling',
    (tester) async {
      final repo = await start(tester);
      await open(tester, 'case-two');
      expect(
        tester
            .widget<SupportStories>(find.byType(SupportStories))
            .records
            .map((record) => record.id)
            .toList(),
        ['case-two'],
      );
      expect(repo.catalogReads, ['case-two']);
      expect(photo(tester), 'case-two/a');
      await next(tester);
      expect(find.byType(SupportStories), findsNothing);
      expect(find.byType(MonthlyImpactPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'monthly story queue revalidates and skips revoked next case without exposing private or unrelated photos',
    (tester) async {
      final repo = await start(tester, third: true, revokeSecond: true);
      await open(tester, 'case-one');
      expect(repo.catalogReads, ['case-one', 'case-two', 'case-three']);
      final records = tester
          .widget<SupportStories>(find.byType(SupportStories))
          .records;
      expect(records.map((record) => record.id).toList(), [
        'case-one',
        'case-three',
      ]);
      expect(
        records.expand(supportStoryPhotos),
        isNot(contains('private/receipt.jpg')),
      );
      expect(
        records.expand(supportStoryPhotos),
        isNot(contains('unrelated/photo')),
      );
      await next(tester);
      expect(photo(tester), 'one/b');
      await next(tester);
      expect(photo(tester), 'case-three/a');
      await next(tester);
      expect(find.byType(SupportStories), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'monthly unavailable later catalog does not block the valid selected case',
    (tester) async {
      final repo = QueueImpactRescue()..failedCases.add('case-two');
      await start(tester, repository: repo);
      await open(tester, 'case-one');
      expect(repo.catalogReads, ['case-one', 'case-two']);
      expect(
        tester
            .widget<SupportStories>(find.byType(SupportStories))
            .records
            .map((record) => record.id)
            .toList(),
        ['case-one'],
      );
      expect(photo(tester), 'one/a');
      await next(tester);
      expect(photo(tester), 'one/b');
      await next(tester);
      expect(find.byType(SupportStories), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'monthly selected catalog failure stays closed without reading later cases',
    (tester) async {
      final repo = QueueImpactRescue()..failedCases.add('case-one');
      await start(tester, repository: repo);
      final ring = find.byKey(const ValueKey('impact-ring-case-one'));
      await tester.ensureVisible(ring);
      await tester.tap(ring);
      await tester.pumpAndSettle();
      expect(find.byType(SupportStories), findsNothing);
      expect(repo.catalogReads, ['case-one']);
      expect(
        find.text('No pudimos abrir las historias. Vuelve a intentarlo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'monthly pending later lookup cannot open a story after the panel unmounts',
    (tester) async {
      final gate = Completer<void>();
      final repo = QueueImpactRescue()..pendingCases['case-two'] = gate;
      await start(tester, third: true, repository: repo);
      final ring = find.byKey(const ValueKey('impact-ring-case-one'));
      await tester.ensureVisible(ring);
      await tester.tap(ring);
      await tester.pump();
      expect(repo.catalogReads, ['case-one', 'case-two']);
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SupportStories), findsNothing);
      expect(repo.catalogReads, ['case-one', 'case-two']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final withdrawn in [true, false]) {
    testWidgets(
      'monthly selected unavailable public snapshot stays closed, withdrawn=$withdrawn',
      (tester) async {
        final repo = QueueImpactRescue();
        if (withdrawn) {
          repo.withdrawnCases.add('case-one');
        } else {
          repo.emptyPhotoCases.add('case-one');
        }
        await start(tester, repository: repo);
        final ring = find.byKey(const ValueKey('impact-ring-case-one'));
        await tester.ensureVisible(ring);
        await tester.tap(ring);
        await tester.pumpAndSettle();
        expect(find.byType(SupportStories), findsNothing);
        expect(repo.catalogReads, ['case-one']);
        expect(
          find.text(
            'Las historias públicas de este caso ya no están disponibles.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
