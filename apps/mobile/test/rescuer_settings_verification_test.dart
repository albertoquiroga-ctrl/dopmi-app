import 'package:dopmi_mobile/features/profile/rescuer_settings_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final item in const [
    ('not_started', 'No verificada', 'Iniciar verificación'),
    ('submitted', 'Verificación en proceso', 'Ver estado'),
    ('changes_requested', 'Verificación con errores', 'Corregir información'),
    ('approved', 'Cuenta verificada', ''),
    ('unknown', 'Verificación no disponible', ''),
  ]) {
    testWidgets(
      'settings state remains truthful and accessible at 200 percent: ${item.$1}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SettingsVerificationCard(
                      status: item.$1,
                      onPressed: () => calls++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(item.$2), findsOneWidget);
        expect(
          find.text('Tu cuenta está activa y puede recibir donaciones.'),
          findsNothing,
        );
        if (item.$3.isEmpty) {
          expect(find.byType(FilledButton), findsNothing);
        } else {
          await tester.ensureVisible(find.text(item.$3));
          await tester.tap(find.text(item.$3));
          await tester.pumpAndSettle();
          expect(calls, 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
