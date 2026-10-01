import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/payments/contribution_amount_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      await tester.tap(find.text('Total faltante'));
      await tester.ensureVisible(find.text('Dona ahora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dona ahora'));
      await tester.pumpAndSettle();
      expect(result, 120025);
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
