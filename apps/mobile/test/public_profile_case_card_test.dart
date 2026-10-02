import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/public_profile_case_card.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue;

class RevokedPublicCase extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      const DataPage([], 0);
}

void main() {
  Future<void> start(WidgetTester tester, FakeRescue rescue) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(rescue),
        ],
        child: MaterialApp(
          theme: dopmiTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 288,
                child: PublicProfileCaseCard('case-one'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'public case shows approved expense and opens real amount selector',
    (tester) async {
      await start(tester, FakeRescue());
      expect(find.text('Choco'), findsOneWidget);
      expect(find.text('Cirugía'), findsOneWidget);
      expect(find.text('\$25.00 MXN / \$100.00 MXN'), findsOneWidget);
      await tester.tap(find.text('Donar'));
      await tester.pumpAndSettle();
      expect(find.text('Elige un monto a donar:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'revoked case exposes neither past identity nor contribution controls',
    (tester) async {
      await start(tester, RevokedPublicCase());
      expect(find.text('Este caso ya no está disponible.'), findsOneWidget);
      expect(find.text('Choco'), findsNothing);
      expect(find.text('Donar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
