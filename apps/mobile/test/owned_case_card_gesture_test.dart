import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'photo_runtime_test.dart' show photograph, realRuntime;
import 'rescue_test.dart' show FakeRescue;

class CardGestureRescue extends FakeRescue {
  CardGestureRescue(this.status);
  static const photoPath = 'one/case-one/card.jpg';
  final String status;
  final reads = <String>[];
  RescueRecord get owned => RescueRecord({
    ...caseRecord.data,
    'owner_id': 'one',
    'status': status,
    'public_data': {
      ...caseRecord.publicData,
      'photos': [photoPath],
    },
    'private_data': <String, dynamic>{},
    'files': <Json>[],
  });
  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async => DataPage([owned], 1);
  @override
  Future<Json> detail(String id) async {
    reads.add(id);
    return {'record': owned.data, 'history': <Json>[]};
  }

  @override
  Future<Json> ownedCases(
    int page, {
    String program = 'adoption',
    List<String> statuses = const [],
    bool archived = false,
  }) async {
    final result = await super.ownedCases(
      page,
      program: program,
      statuses: statuses,
      archived: archived,
    );
    return {
      ...result,
      'items': [
        for (final item in result['items'] as List)
          {...Json.from(item as Map), 'cover_path': photoPath},
      ],
    };
  }

  @override
  Future<String> fileUrl(String path) async =>
      'https://fixture.test/owned-card.jpg';
}

Future<ProviderContainer> mountOwnedCard(
  WidgetTester tester,
  CardGestureRescue rescue,
  PhotoRuntime runtime,
) async {
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(FakeCommunity()),
      rescueRepositoryProvider.overrideWithValue(rescue),
      photoRuntimeProvider.overrideWithValue(runtime),
      routerInitialLocationProvider.overrideWithValue(
        '/my-cases?program=support',
      ),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await identity.changes.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DopmiApp()),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 20),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  return container;
}

void main() {
  for (final status in ['draft', 'changes_requested', 'approved']) {
    for (final large in [false, true]) {
      testWidgets(
        'case card scroll does not open; tap loads owned $status; large=$large',
        (tester) async {
          tester.view.physicalSize = Size(large ? 320 : 377, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final rescue = CardGestureRescue(status);
          final runtime = await realRuntime(
            tester,
            MemoryPhotoStore(),
            download: (_, _) async => photograph,
          );
          addTearDown(runtime.dispose);
          await tester.runAsync(
            () => runtime.load(
              rescuePhotoSource(rescue, CardGestureRescue.photoPath),
              width: 384,
            ),
          );
          final container = await mountOwnedCard(tester, rescue, runtime);
          final card = find.byKey(const ValueKey('owned-case-open-case-one'));
          final initial = tester.getRect(card);
          expect(initial.height, greaterThanOrEqualTo(48));
          await tester.dragFrom(
            Offset(initial.left + 30, initial.top + 30),
            const Offset(0, -50),
          );
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, '/my-cases');
          expect(rescue.reads, isEmpty);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          final target = tester.getRect(card);
          // Photo/name surface invokes the private editor or owned detail.
          await tester.tapAt(Offset(target.left + 30, target.top + 30));
          await tester.pumpAndSettle();
          expect(
            container.read(routerProvider).state.uri.path,
            '/rescue/case-one',
          );
          expect(rescue.reads, ['case-one']);
          expect(rescue.saveCalls, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'approved case photo retry starts transport without opening the case',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retrying = false;
      final retryResponse = Completer<Uint8List>();
      // This regression checks the gesture and loading state. Keep its pending
      // transport in FakeAsync; real decoding is covered by the six tests above
      // and the PhotoRuntime recovery suite.
      final runtime = PhotoRuntime(
        store: MemoryPhotoStore(),
        retryDelay: Duration.zero,
        download: (_, _) async {
          if (!retrying) throw StateError('offline');
          return retryResponse.future;
        },
      );
      addTearDown(runtime.dispose);
      final rescue = CardGestureRescue('approved');
      final container = await mountOwnedCard(tester, rescue, runtime);
      final retry = find.byTooltip('Foto no disponible. Reintentar foto');
      expect(retry.hitTestable(), findsOneWidget);
      final failedDownloads = runtime.metrics.downloads;
      retrying = true;
      await tester.tap(retry);
      await tester.pump();
      // No test-side load invokes transport: the actual retry must do it.
      expect(runtime.metrics.downloads, failedDownloads + 1);
      expect(retry, findsNothing);
      expect(
        find.descendant(
          of: find.byType(RescuePublicPhoto),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(container.read(routerProvider).state.uri.path, '/my-cases');
      expect(rescue.reads, isEmpty);
      expect(rescue.saveCalls, 0);
      retryResponse.completeError(StateError('offline again'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 20),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(retry.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
