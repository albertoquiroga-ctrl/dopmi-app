import 'dart:async';

import 'package:dopmi_mobile/features/community/content_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';

import 'community_test.dart' show FakeCommunity;

class ReceiptReportCommunity extends FakeCommunity {
  String? actor = 'one';
  final requests = <Json>[];
  final pending = <Completer<String>>[];
  @override
  String? get userId => actor;
  @override
  Future<String> report(String type, String id, String reason, String details) {
    requests.add({
      'type': type,
      'id': id,
      'reason': reason,
      'details': details,
    });
    final response = Completer<String>();
    pending.add(response);
    return response.future;
  }
}

Future<void> reportHarness(
  WidgetTester tester,
  ReceiptReportCommunity repo,
  List<bool> results, {
  bool large = false,
}) async {
  tester.view.physicalSize = large
      ? const Size(320, 640)
      : const Size(377, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      theme: dopmiTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await reportPublicContent(
                  context,
                  repo,
                  type: 'rescuer',
                  id: 'person-one',
                  title: 'Reportar rescatista',
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Finder reportSend() => find.descendant(
  of: find.byType(Dialog),
  matching: find.byType(FilledButton),
);
Future<void> sendReport(WidgetTester tester) async {
  await tester.ensureVisible(reportSend());
  await tester.pumpAndSettle();
  await tester.tap(reportSend());
  await tester.pump();
}

void main() {
  const receipt = '119314cd-95b2-4c92-b7dd-5a9d820871d9';
  for (final large in [false, true]) {
    testWidgets(
      'report waits for a receipt and preserves motive on retry large=$large',
      (tester) async {
        final repo = ReceiptReportCommunity();
        final results = <bool>[];
        await reportHarness(tester, repo, results, large: large);
        await tester.enterText(
          find.byType(TextField),
          '  Información incorrecta  ',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(reportSend());
        await tester.pumpAndSettle();
        final sendSize = tester.getSize(reportSend());
        await sendReport(tester);
        expect(tester.getSize(reportSend()), sendSize);
        expect(repo.requests, [
          {
            'type': 'rescuer',
            'id': 'person-one',
            'reason': 'other',
            'details': 'Información incorrecta',
          },
        ]);
        expect(results, isEmpty);
        await tester.tap(reportSend());
        await tester.pump();
        expect(repo.requests.length, 1);
        expect(
          tester
              .widget<OutlinedButton>(
                find.descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(OutlinedButton),
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.tapAt(const Offset(4, 4));
        await tester.pump();
        expect(find.byType(Dialog), findsOneWidget);
        repo.pending.single.completeError(
          Exception('private transport diagnostic'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'No pudimos completar la solicitud. Comprueba tu conexión y vuelve a intentar.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '  Información incorrecta  ',
        );
        expect(
          find.textContaining('private transport diagnostic'),
          findsNothing,
        );
        expect(results, isEmpty);
        await sendReport(tester);
        expect(repo.requests.length, 2);
        expect(repo.requests[1], repo.requests[0]);
        expect(
          tester.getBottomRight(reportSend()).dy,
          lessThanOrEqualTo((large ? 640 : 852) - 300),
        );
        repo.pending.last.complete(receipt);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(results, [true]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'report rejects a malformed receipt and only closes after confirmed retry',
    (tester) async {
      final repo = ReceiptReportCommunity();
      final results = <bool>[];
      await reportHarness(tester, repo, results);
      await tester.enterText(find.byType(TextField), 'Motivo privado');
      await sendReport(tester);
      repo.pending.single.complete('');
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos confirmar el reporte. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(results, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Motivo privado',
      );
      await sendReport(tester);
      repo.pending.last.complete(receipt);
      await tester.pumpAndSettle();
      expect(results, [true]);
    },
  );
  for (final phase in ['before', 'receipt', 'failure']) {
    final beforeRequest = phase == 'before';
    testWidgets(
      'changed reporter clears private draft and ignores response phase=$phase',
      (tester) async {
        final repo = ReceiptReportCommunity();
        final results = <bool>[];
        await reportHarness(tester, repo, results);
        await tester.enterText(
          find.byType(TextField),
          'Motivo de la cuenta anterior',
        );
        if (beforeRequest) repo.actor = 'other';
        await sendReport(tester);
        if (!beforeRequest) {
          repo.actor = 'other';
          if (phase == 'failure') {
            repo.pending.single.completeError(
              Exception('private transport diagnostic'),
            );
          } else {
            repo.pending.single.complete(receipt);
          }
        }
        await tester.pumpAndSettle();
        expect(repo.requests.length, beforeRequest ? 0 : 1);
        expect(results, isEmpty);
        expect(
          find.text(
            'Tu sesión cambió. Cierra este reporte y vuelve a abrirlo.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(tester.widget<FilledButton>(reportSend()).onPressed, isNull);
        await tester.ensureVisible(find.text('Cancelar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(results, [false]);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
        final reportAction = find.widgetWithText(FilledButton, 'Enviar reporte');
        await tester.ensureVisible(reportAction);
        await tester.pumpAndSettle();
        final actionRect = tester.getRect(reportAction);
        final labelRect = tester.getRect(find.text('Enviar reporte'));
        expect(labelRect.top, greaterThanOrEqualTo(actionRect.top + 11.9));
        expect(labelRect.bottom, lessThanOrEqualTo(actionRect.bottom - 11.9));
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
            await tester.enterText(find.byType(TextField), 'Borrador conservado');
            await tester.tapAt(const Offset(4, 4));
            await tester.pumpAndSettle();
            expect(returned, false);
            expect(find.byType(Dialog), findsOneWidget);
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              'Borrador conservado',
            );
            await tester.ensureVisible(find.text('Cancelar'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Cancelar'));
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
