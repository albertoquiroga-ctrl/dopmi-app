import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/rescue/expense_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locked in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'expense controls cancel safely and respect lock: $locked/$scale',
        (tester) async {
          var backs = 0, closes = 0;
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: dopmiTheme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: ExpenseFrame(
                  step: 1,
                  onBack: locked ? null : () => backs++,
                  onClose: locked ? null : () => closes++,
                  children: const [Text('Comprobante privado')],
                ),
              ),
            ),
          );
          for (final label in ['Paso anterior', 'Cerrar formulario']) {
            final control = find.byTooltip(label);
            final rect = tester.getRect(control);
            final held = await tester.startGesture(rect.center);
            await tester.pump(const Duration(milliseconds: 150));
            expect(tester.getRect(control), rect);
            await held.cancel();
            await tester.pumpAndSettle();
            expect(backs, 0);
            expect(closes, 0);
          }
          await tester.tap(find.byTooltip('Paso anterior'));
          await tester.pumpAndSettle();
          expect(backs, locked ? 0 : 1);
          await tester.tap(find.byTooltip('Cerrar formulario'));
          await tester.pumpAndSettle();
          expect(closes, locked ? 0 : 1);
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(closes, locked ? 0 : 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
