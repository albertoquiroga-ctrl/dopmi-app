import 'package:dopmi_mobile/core/config/adoption_only_build.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'owned_cases_screen_test.dart'
    show OwnedCasesRepository, mount, ownedItem;
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_home_screen_test.dart' show HomeRescue, pumpHome;

void main() {
  testWidgets('rescatista keeps adoption and message shortcuts', (
    tester,
  ) async {
    await pumpHome(tester, HomeRescue());

    expect(find.byKey(const ValueKey('home-quick-adoption')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-quick-messages')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-quick-support')), findsNothing);
    expect(find.byKey(const ValueKey('home-quick-payments')), findsNothing);
  }, skip: !adoptionOnlyBuild);

  testWidgets('opening owned cases in support mode loads only adoptions', (
    tester,
  ) async {
    final rescue = OwnedCasesRepository([
      ownedItem('Adopción fixture'),
      ownedItem('Apoyo fixture', program: 'support'),
    ]);
    await mount(tester, rescue, program: 'support');

    expect(rescue.queries, isNotEmpty);
    expect(
      rescue.queries.map((query) => query['program']),
      everyElement('adoption'),
    );
    expect(find.text('Adopción fixture'), findsOneWidget);
    expect(find.text('Apoyo'), findsNothing);
    expect(find.text('Apoyo fixture'), findsNothing);
  }, skip: !adoptionOnlyBuild);

  testWidgets('shared rescue editor ignores misleading verification kind', (
    tester,
  ) async {
    final rescue = _SupportDetail();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rescueRepositoryProvider.overrideWithValue(rescue)],
        child: const MaterialApp(
          home: RescueEditorScreen('case-one', kind: 'verification'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(rescue.detailCalls, 1);
    expect(find.text('Este contenido no está disponible.'), findsOneWidget);
    expect(find.textContaining('Choco'), findsNothing);
  }, skip: !adoptionOnlyBuild);
}

class _SupportDetail extends FakeRescue {
  int detailCalls = 0;

  @override
  Future<Json> detail(String id) async {
    detailCalls++;
    return {'record': caseRecord.data, 'history': <Json>[]};
  }
}
