import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/features/rescue/case_need_dialog.dart';

void main() {
  for (final type in ['medicine', 'veterinary']) {
    testWidgets(
      '$type validates exact cents and remains usable at enlarged text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        Map<String, dynamic>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await addCaseNeed(context, type);
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        final save = find.widgetWithText(
          FilledButton,
          type == 'medicine' ? 'Guardar medicina' : 'Guardar consulta',
        );
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        final title = find.byKey(const ValueKey('case-field-title'));
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        await tester.enterText(title, 'Medicina prescrita');
        final amount = find.byKey(const ValueKey('case-field-amount'));
        await tester.ensureVisible(amount);
        await tester.pumpAndSettle();
        await tester.enterText(amount, '123.456');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await tester.enterText(amount, '123.45');
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final urgency = find.text('Marcar como urgente');
        await tester.ensureVisible(urgency);
        await tester.pumpAndSettle();
        await tester.tap(urgency);
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(result!['amount_cents'], 12345);
        expect(result!['type'], type);
        expect(result!['detail'], '');
        expect(result!['urgent'], true);
        expect(find.byType(CaseNeedDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
