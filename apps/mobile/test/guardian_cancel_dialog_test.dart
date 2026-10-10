import 'package:dopmi_mobile/features/payments/guardian_cancel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final action in [
    'Cerrar',
    'Mantener suscripción',
    'Cancelar suscripción',
    'Regresar',
  ]) {
    testWidgets(
      'Cancellation dialog returns consent only for explicit confirmation: $action',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await confirmGuardianCancellation(context);
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('no se devuelven automáticamente'),
          findsOneWidget,
        );
        if (action == 'Regresar') {
          await tester.binding.handlePopRoute();
        } else if (action == 'Cerrar') {
          await tester.tap(find.byTooltip('Cerrar'));
        } else {
          await tester.tap(find.text(action));
        }
        await tester.pumpAndSettle();
        expect(result == true, action == 'Cancelar suscripción');
        expect(find.text('¿Cancelar suscripción?'), findsNothing);
      },
    );
  }
  testWidgets(
    'Large text retains full explanation and both actions through scroll',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => confirmGuardianCancellation(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mantener suscripción'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mantener suscripción'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar suscripción?'), findsNothing);
    },
  );
}
