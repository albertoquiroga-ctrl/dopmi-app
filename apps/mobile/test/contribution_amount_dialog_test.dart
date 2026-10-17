import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/payments/contribution_amount_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'amount selector returns exact cents and dismisses without charging',
    (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: dopmiTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<int>(
                    context: context,
                    builder: (_) =>
                        const ContributionAmountDialog(remainingCents: 120025),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('\$50'), findsOneWidget);
      expect(find.text('\$200'), findsOneWidget);
      expect(find.text('\$500'), findsOneWidget);
      expect(find.text('Total faltante'), findsNothing);
      await tester.tap(find.text('\$200'));
      await tester.ensureVisible(find.text('Dona ahora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dona ahora'));
      await tester.pumpAndSettle();
      expect(result, 20000);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '9.99');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '100.25');
      await tester.ensureVisible(find.text('Dona ahora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dona ahora'));
      await tester.pumpAndSettle();
      expect(result, 10025);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
  for (final byCase in [false, true]) {
    testWidgets(
      'amount choice keeps case and historical expense contracts distinct: case=$byCase',
      (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => chooseContribution(
                    context,
                    'expense-one',
                    120025,
                    caseId: 'case-one',
                    caseContribution: byCase,
                  ),
                  child: const Text('Apoyar'),
                ),
              ),
            ),
            GoRoute(
              path: '/contribute/:id',
              builder: (_, _) => const Scaffold(body: Text('Legacy checkout')),
            ),
            GoRoute(
              path: '/contribute-case/:id',
              builder: (_, _) => const Scaffold(body: Text('Case checkout')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.tap(find.text('Apoyar'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Dona ahora'));
        await tester.tap(find.text('Dona ahora'));
        await tester.pumpAndSettle();
        expect(
          router.state.uri.path,
          byCase ? '/contribute-case/case-one' : '/contribute/expense-one',
        );
        expect(router.state.uri.queryParameters['amount_cents'], '5000');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('large text and keyboard leave amount and continue accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dopmiTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 200),
          ),
          child: const ContributionAmountDialog(remainingCents: 120025),
        ),
      ),
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '100.25');
    await tester.ensureVisible(find.text('Dona ahora'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
