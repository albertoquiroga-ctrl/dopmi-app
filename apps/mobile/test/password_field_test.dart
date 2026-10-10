import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default password visibility toggles without losing input', (
    tester,
  ) async {
    final controller = TextEditingController();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PasswordField(controller: controller)),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Password1234');
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      expect(controller.text, 'Password1234');
      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      expect(controller.text, 'Password1234');
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });
}
