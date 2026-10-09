import 'dart:typed_data';
import 'dart:async';

import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'rescue_test.dart' show FakeRescue, FakeCaseUpdates;

class StoryRepository extends FakeRescue {
  @override
  Future<String> fileUrl(String path) async => 'https://fixture.test/$path';
}

class RetryStoryRepository extends StoryRepository {
  int attempts = 0;
  @override
  Future<String> fileUrl(String path) async {
    attempts++;
    if (attempts == 1) throw StateError('offline');
    return super.fileUrl(path);
  }
}

class PendingStoryUpdates extends FakeCaseUpdates {
  final pending = Completer<List<CaseUpdate>>();
  int attempts = 0;
  bool failFirst = false;
  @override
  Future<List<CaseUpdate>> publicFor(String caseId) {
    attempts++;
    if (failFirst && attempts == 1) return Future.error(StateError('offline'));
    return pending.future;
  }
}

RescueRecord story(
  String id,
  List<String> photos, {
  String status = 'approved',
}) => RescueRecord({
  'id': id,
  'kind': 'case',
  'status': status,
  'target_cents': 10000,
  'funded_cents': 2500,
  'public_data': {'pet_name': id, 'photos': photos},
  'private_data': {
    'photos': ['private/receipt.jpg'],
  },
  'files': [
    {'path': 'private/receipt.jpg', 'role': 'receipt'},
  ],
});

Future<void> mountTimedStories(
  WidgetTester tester, {
  bool reduced = false,
  bool accessible = false,
  bool largeText = false,
}) async {
  tester.view.physicalSize = Size(largeText ? 320 : 377, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = StoryRepository();
  final runtime = PhotoRuntime(
    store: MemoryPhotoStore(),
    download: (_, _) async =>
        Uint8List.fromList(img.encodeJpg(img.Image(width: 20, height: 24))),
  );
  addTearDown(runtime.dispose);
  await tester.runAsync(() async {
    for (final path in ['timed/one', 'timed/two']) {
      await runtime.load(rescuePhotoSource(repo, path), width: 384);
    }
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueRepositoryProvider.overrideWithValue(repo),
        caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
        photoRuntimeProvider.overrideWithValue(runtime),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            accessibleNavigation: accessible,
            textScaler: TextScaler.linear(largeText ? 2 : 1),
          ),
          child: child!,
        ),
        home: SupportStories(
          records: [
            story('Luna', ['timed/one', 'timed/two']),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  // Photo readiness is signaled explicitly so frame decoding time is excluded
  // from the 5200 ms story clock being tested.
  tester.widget<RemotePhoto>(find.byType(RemotePhoto)).onDisplayed!();
  await tester.pump();
}

double storyProgress(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator).first)
    .value!;
String storyPath(WidgetTester tester) =>
    tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path;

Future<void> tapStorySide(WidgetTester tester, {required bool next}) async {
  final bounds = tester.getRect(find.byType(RemotePhoto));
  await tester.tapAt(
    Offset(bounds.left + bounds.width * (next ? .8 : .2), bounds.top + 80),
  );
}

void main() {
  testWidgets('story clock is linear and advances at 5200 ms', (tester) async {
    await mountTimedStories(tester);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(storyProgress(tester), closeTo(.25, .001));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(storyProgress(tester), closeTo(.5, .001));
    await tester.pump(const Duration(milliseconds: 2599));
    expect(storyPath(tester), 'timed/one');
    await tester.pump(const Duration(milliseconds: 1));
    expect(storyPath(tester), 'timed/two');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'background pause preserves elapsed time and resumes remaining time',
    (tester) async {
      await mountTimedStories(tester);
      await tester.pump(const Duration(milliseconds: 1300));
      final elapsed = storyProgress(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(storyProgress(tester), elapsed);
      expect(storyPath(tester), 'timed/one');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3899));
      expect(storyPath(tester), 'timed/one');
      await tester.pump(const Duration(milliseconds: 1));
      expect(storyPath(tester), 'timed/two');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final cancel in [false, true]) {
    testWidgets('held pointer pauses without tap navigation; cancel=$cancel', (
      tester,
    ) async {
      await mountTimedStories(tester);
      await tester.pump(const Duration(milliseconds: 1300));
      final elapsed = storyProgress(tester);
      final pointer = await tester.startGesture(const Offset(180, 300));
      await tester.pump(const Duration(seconds: 10));
      expect(storyProgress(tester), elapsed);
      if (cancel) {
        await pointer.cancel();
      } else {
        await pointer.up();
      }
      await tester.pump();
      expect(storyPath(tester), 'timed/one');
      await tester.pump(const Duration(milliseconds: 1300));
      expect(storyProgress(tester), closeTo(.5, .001));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final accessible in [false, true]) {
    testWidgets(
      '320 px 200 percent text keeps controls usable and accessibility clock manual; accessible=$accessible',
      (tester) async {
        await mountTimedStories(
          tester,
          reduced: !accessible,
          accessible: accessible,
          largeText: true,
        );
        await tester.pump(const Duration(seconds: 10));
        expect(storyPath(tester), 'timed/one');
        expect(storyProgress(tester), 0);
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Cerrar historias'), findsOneWidget);
        await tapStorySide(tester, next: true);
        await tester.pump();
        expect(storyPath(tester), 'timed/two');
        await tapStorySide(tester, next: false);
        await tester.pump();
        expect(storyPath(tester), 'timed/one');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final failFirst in [false, true]) {
    testWidgets('late public advances remain reachable; retry=$failFirst', (
      tester,
    ) async {
      final updates = PendingStoryUpdates()..failFirst = failFirst;
      final repo = StoryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueRepositoryProvider.overrideWithValue(repo),
            caseUpdateRepositoryProvider.overrideWithValue(updates),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: SupportStories(
                records: [
                  story('One', ['public/one']),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tapStorySide(tester, next: true);
      await tester.pump();
      expect(find.text('One'), findsOneWidget);
      if (failFirst) {
        expect(find.text('Reintentar avances'), findsOneWidget);
        await tester.tap(find.text('Reintentar avances'));
        await tester.pump();
      }
      updates.pending.complete([
        CaseUpdate({
          'id': 'update',
          'case_id': 'One',
          'body': 'Avance aprobado',
          'photos': ['update/photo'],
          'published_at': '2026-10-08T12:00:00Z',
        }),
      ]);
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path,
        'update/photo',
      );
      expect(find.text('Avance aprobado'), findsOneWidget);
      expect(updates.attempts, failFirst ? 2 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'previous cancels a pending final-photo advance before late updates resolve',
    (tester) async {
      final updates = PendingStoryUpdates();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueRepositoryProvider.overrideWithValue(StoryRepository()),
            caseUpdateRepositoryProvider.overrideWithValue(updates),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: SupportStories(
                records: [
                  story('One', ['public/one', 'public/two']),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tapStorySide(tester, next: true);
      await tester.pump();
      expect(storyPath(tester), 'public/two');
      await tapStorySide(tester, next: true);
      await tester.pump();
      await tapStorySide(tester, next: false);
      await tester.pump();
      expect(storyPath(tester), 'public/one');
      updates.pending.complete([
        CaseUpdate({
          'id': 'late',
          'case_id': 'One',
          'body': 'Avance tardío',
          'photos': ['update/late'],
          'published_at': '2026-10-08T12:00:00Z',
        }),
      ]);
      await tester.pump();
      await tester.pump();
      expect(storyPath(tester), 'public/one');
      await tapStorySide(tester, next: true);
      await tester.pump();
      expect(storyPath(tester), 'public/two');
      await tapStorySide(tester, next: true);
      await tester.pump();
      expect(storyPath(tester), 'update/late');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('failed photo retry reaches the same path without navigating', (
    tester,
  ) async {
    final repo = RetryStoryRepository();
    final runtime = PhotoRuntime(
      store: MemoryPhotoStore(),
      download: (_, _) async =>
          Uint8List.fromList(img.encodeJpg(img.Image(width: 20, height: 24))),
    );
    addTearDown(runtime.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueRepositoryProvider.overrideWithValue(repo),
          caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
          photoRuntimeProvider.overrideWithValue(runtime),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SupportStories(
              records: [
                story('One', ['public/one', 'public/two']),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reintentar foto'), findsOneWidget);
    await tester.tap(find.text('Reintentar foto'));
    await tester.runAsync(() async {
      await tester.pump();
    });
    await tester.pump();
    expect(repo.attempts, greaterThanOrEqualTo(2));
    expect(
      tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path,
      'public/one',
    );
    expect(find.text('One'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('stories use only approved public photos and deduplicate paths', () {
    expect(supportStoryPhotos(story('one', ['public/one', '', 'public/one'])), [
      'public/one',
    ]);
    expect(
      supportStoryPhotos(story('one', ['public/one'], status: 'draft')),
      isEmpty,
    );
    expect(supportStoryPhotos(story('one', [])), isEmpty);
  });
  for (final manual in [false, true]) {
    testWidgets('story navigation and vertical detail, manual=$manual', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = StoryRepository();
      final runtime = PhotoRuntime(
        store: MemoryPhotoStore(),
        download: (_, _) async =>
            Uint8List.fromList(img.encodeJpg(img.Image(width: 20, height: 24))),
      );
      addTearDown(runtime.dispose);
      final records = [
        story('One', ['public/one', 'public/two']),
        story('Two', ['public/three']),
      ];
      await tester.runAsync(() async {
        for (final path in ['public/one', 'public/two', 'public/three']) {
          await runtime.load(rescuePhotoSource(repo, path), width: 384);
        }
      });
      String? detail;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueRepositoryProvider.overrideWithValue(repo),
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
            photoRuntimeProvider.overrideWithValue(runtime),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: manual),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    detail = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => SupportStories(records: records),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('One'), findsOneWidget);
      if (manual) {
        await tester.pump(const Duration(seconds: 6));
      } else {
        final hold = await tester.startGesture(const Offset(180, 400));
        await tester.pump(const Duration(seconds: 6));
        await hold.up();
        await tester.pump();
      }
      expect(
        tester.widget<RemotePhoto>(find.byType(RemotePhoto)).source.path,
        'public/one',
      );
      await tapStorySide(tester, next: true);
      await tester.pump();
      await tapStorySide(tester, next: true);
      await tester.pump();
      expect(find.text('Two'), findsOneWidget);
      await tapStorySide(tester, next: false);
      await tester.pump();
      expect(find.text('One'), findsOneWidget);
      await tester.dragFrom(const Offset(180, 400), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(detail, 'One');
      expect(find.text('Open'), findsOneWidget);
      // Reopen and advance to the last photo: the final next closes once.
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 3; i++) {
        await tapStorySide(tester, next: true);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
