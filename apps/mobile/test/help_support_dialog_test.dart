import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/profile/help_support_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mail handoff preserves accents and draft after failure, prevents duplicates and never claims delivery',
    (tester) async {
      final calls = <Uri>[];
      var pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          theme: dopmiTheme(),
          home: Scaffold(
            body: HelpSupportDialog(
              topics: const ['Guardián', 'Mi cuenta'],
              initialTopic: 0,
              openMail: (uri) {
                calls.add(uri);
                return pending.future;
              },
            ),
          ),
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'Luna & Sol');
      await tester.enterText(
        fields.last,
        'Necesito ayuda: México + información.',
      );
      await tester.pumpAndSettle();
      final next = find.widgetWithText(FilledButton, 'Continuar en correo');
      final action = tester.widget<FilledButton>(next).onPressed!;
      action();
      action();
      await tester.pump();
      expect(calls, hasLength(1));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      expect(calls.single.scheme, 'mailto');
      expect(calls.single.path, 'soporte@dopmi.org');
      expect(
        calls.single.queryParameters['subject'],
        'Ayuda con Dopmi: Guardián',
      );
      expect(
        calls.single.queryParameters['body'],
        'Tema: Guardián\nCaso relacionado: Luna & Sol\n\nNecesito ayuda: México + información.',
      );
      expect(calls.single.query, contains('%20'));
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(fields.first).controller!.text,
        'Luna & Sol',
      );
      expect(
        tester.widget<TextField>(fields.last).controller!.text,
        'Necesito ayuda: México + información.',
      );
      expect(find.textContaining('Tu mensaje sigue aquí'), findsOneWidget);
      pending = Completer<bool>();
      tester.widget<FilledButton>(next).onPressed!();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(
        find.text('Completa el envío desde tu aplicación de correo.'),
        findsOneWidget,
      );
      expect(find.text('Recibimos tu mensaje.'), findsNothing);
    },
  );
}
