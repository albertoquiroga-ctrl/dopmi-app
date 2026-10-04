import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class CardGestureRescue extends FakeRescue {
  CardGestureRescue(this.status);
  final String status;
  final reads = <String>[];
  RescueRecord get owned => RescueRecord({
    ...caseRecord.data,
    'owner_id': 'one',
    'status': status,
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
          final identity = FakeIdentityRepository()
            ..user = const Identity(
              'one',
              'fixture@example.test',
              verified: true,
            );
          final rescue = CardGestureRescue(status);
          final container = ProviderContainer(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
              rescueRepositoryProvider.overrideWithValue(rescue),
              routerInitialLocationProvider.overrideWithValue('/my-cases'),
            ],
          );
          addTearDown(() async {
            container.dispose();
            await identity.changes.close();
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const DopmiApp(),
            ),
          );
          await tester.pumpAndSettle();
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
}
