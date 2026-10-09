import 'package:dopmi_mobile/features/rescue/public_expense_card.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'need starts collapsed; repeated expansion preserves amounts and contribution action',
    (tester) async {
      final record = RescueRecord({
        'id': 'need',
        'kind': 'expense',
        'status': 'approved',
        'parent_id': 'case',
        'target_cents': 10000,
        'funded_cents': 2500,
        'public_data': {
          'title': 'Consulta',
          'category': 'veterinary',
          'photos': <String>[],
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PublicExpenseCard(record, canContribute: true)),
        ),
      );
      expect(find.text('No hay evidencia pública disponible.'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Consulta'));
        await tester.pump();
        expect(
          find.text('No hay evidencia pública disponible.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byTooltip('Aportar a Consulta'),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Consulta'));
        await tester.pump();
        expect(find.text('No hay evidencia pública disponible.'), findsNothing);
        expect(record.targetCents, 10000);
        expect(record.fundedCents, 2500);
        expect(
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byTooltip('Aportar a Consulta'),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
