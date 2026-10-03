import 'package:dopmi_mobile/features/rescue/case_detail_layout.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rescue_test.dart' show PhotoPublicCaseRescue;

void main() {
  testWidgets(
    'case gallery preserves refresh and resets on another case or photos',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          rescueRepositoryProvider.overrideWithValue(PhotoPublicCaseRescue()),
        ],
      );
      addTearDown(container.dispose);
      Future<void> show(String id, List<String> photos) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: CaseDetailLayout(
                  record: RescueRecord({
                    'id': id,
                    'kind': 'case',
                    'status': 'approved',
                    'public_data': {'pet_name': 'Luna', 'photos': photos},
                  }),
                  expenses: const [],
                  needs: const SizedBox(),
                  saved: false,
                  busy: false,
                  favorite: () {},
                  share: () {},
                  report: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      double pageOffset() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(PageView),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
      const photos = ['approved/one', 'approved/two'];
      await show('first', photos);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(pageOffset(), 377);
      await show('first', photos);
      expect(pageOffset(), 377);
      await show('second', photos);
      expect(pageOffset(), 0);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await show('second', const ['approved/two']);
      expect(pageOffset(), 0);
      expect(tester.takeException(), isNull);
    },
  );
}
