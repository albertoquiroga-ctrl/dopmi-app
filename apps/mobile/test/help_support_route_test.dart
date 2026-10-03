import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/profile/help_support_dialog.dart';
import 'package:dopmi_mobile/features/profile/support_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dismissal in ['outside', 'back', 'close']) {
    testWidgets(
      'support opens immediately and closes by $dismissal without sending',
      (tester) async {
        var submissions = 0;
        final repository = SupportRepository((_, params) async {
          submissions++;
          return {'request_id': params['target_request'], 'status': 'received'};
        });
        await tester.pumpWidget(_host(repository));
        await tester.tap(find.text('Abrir soporte'));
        await tester.pump();
        final dialog = find.byType(Dialog);
        expect(dialog, findsOneWidget);
        final route = ModalRoute.of(tester.element(dialog))!;
        expect(route.transitionDuration, Duration.zero);
        expect(route.animation!.value, 1);
        expect(
          route.barrierColor,
          const Color(0xff15110d).withValues(alpha: .48),
        );
        await tester.tap(find.text('Contactar a soporte'));
        await tester.pump();
        expect(dialog, findsOneWidget);
        if (dismissal == 'outside') {
          await tester.tapAt(const Offset(2, 2));
        } else if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Cerrar'));
        }
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(submissions, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending support blocks dismissal and duplicate send until receipt',
    (tester) async {
      final pending = Completer<dynamic>();
      final requestIds = <String>[];
      final repository = SupportRepository((_, params) {
        requestIds.add(params['target_request'] as String);
        return pending.future;
      });
      await tester.pumpWidget(_host(repository));
      await tester.tap(find.text('Abrir soporte'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Necesito ayuda.');
      await tester.pumpAndSettle();
      final send = find.widgetWithText(FilledButton, 'Enviar mensaje');
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      final action = tester.widget<FilledButton>(send).onPressed!;
      await tester.tap(send);
      action();
      await tester.pump();
      expect(requestIds, hasLength(1));
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pump();
      expect(find.byType(HelpSupportDialog), findsOneWidget);
      expect(find.text('Recibimos tu mensaje.'), findsNothing);
      pending.complete({'request_id': requestIds.single, 'status': 'received'});
      await tester.pumpAndSettle();
      expect(find.text('Recibimos tu mensaje.'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpSupportDialog), findsNothing);
      expect(requestIds, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(SupportRepository repository) => MaterialApp(
  theme: dopmiTheme(),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showHelpSupportDialog(
          context,
          topics: const ['Cómo funcionan los apoyos'],
          initialTopic: 0,
          repository: repository,
        ),
        child: const Text('Abrir soporte'),
      ),
    ),
  ),
);
