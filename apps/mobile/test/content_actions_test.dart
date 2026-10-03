import 'dart:async';

import 'package:dopmi_mobile/features/community/content_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'report requires a motive and cancels without a submission large=$large',
      (tester) async {
        tester.view.physicalSize = large
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        (String, String)? result;
        var returned = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showContentReportSheet(
                      context,
                      title: 'Reportar caso',
                    );
                    returned = true;
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Enviar reporte'),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField), '  ');
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Enviar reporte'),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(
          find.byType(TextField),
          '  Información incorrecta  ',
        );
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Enviar reporte'));
        await tester.pumpAndSettle();
        expect(
          tester
              .getBottomRight(
                find.widgetWithText(FilledButton, 'Enviar reporte'),
              )
              .dy,
          lessThanOrEqualTo((large ? 640 : 852) - 300),
        );
        await tester.tap(find.text('Enviar reporte'));
        await tester.pumpAndSettle();
        expect(result, ('other', 'Información incorrecta'));
        expect(returned, true);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        for (final cancel in ['Cancelar', 'Cerrar', 'back', 'barrier']) {
          returned = false;
          result = null;
          await tester.tap(find.text('Abrir'));
          await tester.pumpAndSettle();
          if (cancel == 'back') {
            await tester.binding.handlePopRoute();
          } else if (cancel == 'barrier') {
            await tester.tapAt(const Offset(4, 4));
          } else if (cancel == 'Cerrar') {
            await tester.tap(find.byTooltip('Cerrar'));
          } else {
            await tester.ensureVisible(find.text('Cancelar'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Cancelar'));
          }
          await tester.pumpAndSettle();
          expect(returned, true);
          expect(result, isNull);
          expect(find.byType(Dialog), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'native share preserves text, prevents duplicate sheets and handles failure',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final calls = <MethodCall>[];
      final result = Completer<String>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (calls.length == 1) return result.future;
        throw PlatformException(
          code: 'unavailable',
          message: 'private diagnostic',
        );
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    shareContent(context, 'Conoce este perfil en Dopmi.'),
                child: const Text('Compartir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Compartir'));
      await tester.pump();
      await tester.tap(find.text('Compartir'));
      await tester.pump();
      expect(calls.length, 1);
      expect(calls.single.method, 'share');
      expect(calls.single.arguments['text'], 'Conoce este perfil en Dopmi.');
      expect(calls.single.arguments['originWidth'], greaterThan(0));
      result.complete('dev.fluttercommunity.plus/share/dismissed');
      await tester.pumpAndSettle();
      expect(find.text('Información copiada para compartir.'), findsNothing);
      await tester.tap(find.text('Compartir'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(
        find.text(
          'No pudimos abrir las opciones para compartir. Intenta de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private diagnostic'), findsNothing);
    },
  );

  testWidgets(
    'approved social URL opens externally and rejects non-web schemes',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => openPublicSocialUrl(
                      context,
                      'https://instagram.com/refugio',
                    ),
                    child: const Text('Instagram'),
                  ),
                  TextButton(
                    onPressed: () =>
                        openPublicSocialUrl(context, 'file:///private'),
                    child: const Text('Inválido'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Instagram'));
      await tester.pumpAndSettle();
      expect(calls.single.arguments['url'], 'https://instagram.com/refugio');
      expect(calls.single.arguments['useWebView'], false);
      await tester.tap(find.text('Inválido'));
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      expect(
        find.text('No pudimos abrir esta red social. Intenta de nuevo.'),
        findsOneWidget,
      );
    },
  );
}
