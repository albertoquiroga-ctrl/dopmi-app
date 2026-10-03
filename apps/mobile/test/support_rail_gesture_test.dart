import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue, FakeCaseUpdates;

class RailRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    if (caseId != null) return super.catalog(page, caseId: caseId);
    return DataPage([
      for (var n = 0; n < 8; n++)
        RescueRecord({
          'id': 'case-$n',
          'kind': 'case',
          'status': 'approved',
          'target_cents': 10000,
          'funded_cents': 2500,
          'public_data': {'pet_name': 'Caso $n', 'photos': <String>[]},
        }),
    ], 8);
  }
}

void main() {
  testWidgets(
    'horizontal case drag does not open a case and back retains rail',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(RailRescue()),
          caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
          routerInitialLocationProvider.overrideWithValue('/rescue-cases'),
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
      final rail = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      );
      final position = tester.state<ScrollableState>(rail).position;
      await tester.drag(rail, const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/rescue-cases');
      final offset = position.pixels;
      expect(offset, greaterThan(0));
      await tester.ensureVisible(find.text('Caso 4'));
      await tester.pumpAndSettle();
      final retained = position.pixels;
      await tester.tap(find.text('Caso 4'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.path,
        '/rescue-cases/case-4',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(rail).position, same(position));
      expect(position.pixels, retained);
      expect(find.text('Caso 4').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
