import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'discovery_stack_transition_test.dart'
    show CardPhotoCommunity, openCards, frontAction;
import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

void main() {
  for (final consent in [false, true]) {
    testWidgets('only decoded front adoption counts; consent=$consent', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final analytics = AnalyticsSpy();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        DiagnosticsSpy(),
      );
      await controller.owner('one');
      await controller.setAnalytics(consent);
      final repository = CardPhotoCommunity();
      repository.post = Adoption({
        ...repository.post.data,
        'owner_id': 'another',
      });
      await openCards(
        tester,
        repository: repository,
        support: false,
        measurement: controller,
      );
      expect(repository.recordedViews, consent ? ['post'] : isEmpty);
      await tester.pumpAndSettle();
      expect(repository.recordedViews, consent ? ['post'] : isEmpty);
      await tester.tap(frontAction('Pasar'));
      await tester.pumpAndSettle();
      expect(repository.recordedViews, consent ? ['post', 'second'] : isEmpty);
      expect(analytics.events, isEmpty);
    });
  }
  testWidgets('owner never records a view of their own front card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      AnalyticsSpy(),
      DiagnosticsSpy(),
    );
    await controller.owner('one');
    await controller.setAnalytics(true);
    final repository = CardPhotoCommunity();
    repository.post = Adoption({...repository.post.data, 'owner_id': 'one'});
    await openCards(
      tester,
      repository: repository,
      support: false,
      measurement: controller,
    );
    expect(repository.recordedViews, isEmpty);
  });
}
