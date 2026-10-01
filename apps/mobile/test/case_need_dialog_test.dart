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
  for (final dismissal in ['outside', 'cancel', 'close', 'back']) {
    testWidgets('need dialog opens immediately and dismisses by $dismissal', (
      tester,
    ) async {
      var completed = false;
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await addCaseNeed(context, 'medicine');
                    completed = true;
                  },
                  child: const Text('Abrir'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      final route = ModalRoute.of(tester.element(find.byType(CaseNeedDialog)))!;
      expect(route.animation!.value, 1);
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, const Color(0x7a15110d));
      await tester.enterText(
        find.byKey(const ValueKey('case-field-title')),
        'Necesidad pendiente',
      );
      await tester.tap(find.text('Agregar medicina'));
      await tester.pump();
      expect(completed, isFalse);
      expect(find.text('Necesidad pendiente'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      switch (dismissal) {
        case 'outside':
          await tester.tapAt(const Offset(5, 5));
        case 'cancel':
          await tester.ensureVisible(find.text('Cancelar'));
          await tester.tap(find.text('Cancelar'));
        case 'close':
          await tester.tap(find.byTooltip('Cerrar'));
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byType(CaseNeedDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
