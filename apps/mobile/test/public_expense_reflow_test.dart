import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/payments/contribution_amount_dialog.dart';
import 'package:dopmi_mobile/features/rescue/public_expense_card.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
  });

  for (final scale in [1.0, 2.0]) {
    for (final fixture in [
      ('medicine', 'Desparasitante', 'Desparasitante', 25000, 5000),
      ('veterinary', 'Cita veterinario', 'veterinario', 70000, 20000),
    ]) {
      testWidgets(
        'public expense keeps whole words and correct actions: ${fixture.$1}/$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final record = RescueRecord({
            'id': 'expense-${fixture.$1}',
            'kind': 'expense',
            'status': 'approved',
            'parent_id': 'case-rocky',
            'target_cents': fixture.$4,
            'funded_cents': fixture.$5,
            'public_data': {'title': fixture.$2, 'category': fixture.$1},
          });
          Uri? checkout;
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: PublicExpenseCard(record, canContribute: true),
                  ),
                ),
              ),
              GoRoute(
                path: '/contribute/:expense',
                builder: (_, state) {
                  checkout = state.uri;
                  return const Scaffold(body: Text('Revisar aportación'));
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(theme: dopmiTheme(), routerConfig: router),
          );
          await tester.pumpAndSettle();

          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(fixture.$2),
          );
          final start = fixture.$2.indexOf(fixture.$3);
          expect(
            paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: start,
                extentOffset: start + fixture.$3.length,
              ),
            ),
            hasLength(1),
            reason: 'The complete word must fit with the bundled Inter font.',
          );
          final action = find.byTooltip('Aportar a ${fixture.$2}');
          final actionRect = tester.getRect(action);
          expect(actionRect.width, greaterThanOrEqualTo(48));
          expect(actionRect.height, greaterThanOrEqualTo(48));
          expect(
            actionRect.overlaps(tester.getRect(find.text(fixture.$2))),
            isFalse,
          );

          expect(
            find.text('No hay evidencia pública disponible.'),
            findsNothing,
          );
          await tester.tap(find.text(fixture.$2));
          await tester.pumpAndSettle();
          expect(
            find.text('No hay evidencia pública disponible.'),
            findsOneWidget,
          );
          await tester.tap(find.text(fixture.$2));
          await tester.pumpAndSettle();
          expect(
            find.text('No hay evidencia pública disponible.'),
            findsNothing,
          );

          await tester.ensureVisible(action);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(find.byType(ContributionAmountDialog), findsOneWidget);
          await tester.ensureVisible(find.text('Total faltante'));
          await tester.tap(find.text('Total faltante'));
          await tester.ensureVisible(find.text('Dona ahora'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Dona ahora'));
          await tester.pumpAndSettle();
          expect(checkout?.path, '/contribute/${record.id}');
          expect(checkout?.queryParameters['case'], record.parent);
          expect(
            checkout?.queryParameters['amount_cents'],
            '${record.targetCents - record.fundedCents}',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
