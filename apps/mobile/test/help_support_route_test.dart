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
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'support touch focus and keyboard scroll preserve send at $scale',
      (tester) async {
        tester.view.physicalSize = scale == 2
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var submissions = 0;
        final repository = SupportRepository((_, params) async {
          submissions++;
          expect((params['payload'] as Map)['message'], 'Necesito ayuda.');
          return {'request_id': params['target_request'], 'status': 'received'};
        });
        await tester.pumpWidget(_host(repository));
        await tester.tap(find.text('Abrir soporte'));
        await tester.pumpAndSettle();
        final message = find.byType(TextField).last;
        await tester.ensureVisible(message);
        await tester.pumpAndSettle();
        await tester.tap(message);
        await tester.enterText(message, 'Necesito ayuda.');
        await tester.pumpAndSettle();
        final outline = find.byKey(
          const ValueKey('reference-keyboard-outline'),
        );
        expect(outline, findsOneWidget);
        final border =
            (tester.widget<DecoratedBox>(outline).decoration as BoxDecoration)
                    .border
                as Border;
        expect(border.top.width, 3);
        expect(border.top.color, const Color(0x4d7841f2));
        expect(tester.getRect(outline), tester.getRect(message).inflate(5));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final send = find.widgetWithText(FilledButton, 'Enviar mensaje');
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        expect(send.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(send).bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height - 300),
        );
        final scroll = tester.getRect(find.byType(SingleChildScrollView));
        await tester.dragFrom(
          Offset(scroll.left + 8, scroll.center.dy),
          const Offset(0, 60),
        );
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(
          tester.widget<TextField>(message).controller!.text,
          'Necesito ayuda.',
        );
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(submissions, 1);
        expect(find.text('Recibimos tu mensaje.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'topic menu dismissal preserves dialog and selection sends the correct topic at $scale',
      (tester) async {
        tester.view.physicalSize = scale == 2
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var submissions = 0;
        final repository = SupportRepository((_, params) async {
          submissions++;
          expect((params['payload'] as Map)['topic'], 'guardian');
          expect(
            (params['payload'] as Map)['message'],
            'Mi mensaje permanece.',
          );
          expect((params['payload'] as Map)['case_name'], 'Luna');
          return {'request_id': params['target_request'], 'status': 'received'};
        });
        await tester.pumpWidget(
          _host(
            repository,
            topics: const [
              'Cómo funcionan los apoyos',
              'Apoyar',
              'Guardián',
              'Adoptar',
              'Verificación',
              'Publicar casos',
              'Fondos y evidencia',
              'Mi cuenta',
              'Confianza y seguridad',
            ],
          ),
        );
        await tester.tap(find.text('Abrir soporte'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Luna');
        await tester.enterText(
          find.byType(TextField).last,
          'Mi mensaje permanece.',
        );
        await tester.pumpAndSettle();
        final menu = find.byType(DropdownButtonFormField<int>);
        for (final dismissal in ['outside', 'back', 'select']) {
          await tester.ensureVisible(menu);
          await tester.pumpAndSettle();
          await tester.tap(menu);
          await tester.pumpAndSettle();
          if (dismissal == 'outside') {
            await tester.tapAt(const Offset(2, 2));
          } else if (dismissal == 'back') {
            await tester.binding.handlePopRoute();
          } else {
            final option = find.text('Guardián').last;
            await tester.ensureVisible(option);
            await tester.pumpAndSettle();
            expect(option.hitTestable(), findsOneWidget);
            await tester.tap(option);
          }
          await tester.pumpAndSettle();
          expect(find.byType(HelpSupportDialog), findsOneWidget);
          expect(
            tester
                .widget<TextField>(find.byType(TextField).last)
                .controller!
                .text,
            'Mi mensaje permanece.',
          );
          expect(submissions, 0);
        }
        expect(find.text('Guardián'), findsOneWidget);
        final send = find.widgetWithText(FilledButton, 'Enviar mensaje');
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(submissions, 1);
        expect(find.text('Recibimos tu mensaje.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _host(
  SupportRepository repository, {
  List<String> topics = const ['Cómo funcionan los apoyos'],
}) => MaterialApp(
  theme: dopmiTheme(),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showHelpSupportDialog(
          context,
          topics: topics,
          initialTopic: 0,
          repository: repository,
        ),
        child: const Text('Abrir soporte'),
      ),
    ),
  ),
);
