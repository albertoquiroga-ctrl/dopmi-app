import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/profile/help_support_dialog.dart';
import 'package:dopmi_mobile/features/profile/support_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets('photo preview is local and retry reuses its uploaded path', (
    tester,
  ) async {
    var picks = 0, uploads = 0, submissions = 0;
    final ids = <String>[];
    final paths = <String>[];
    final repo = SupportRepository(
      (name, params) async {
        ids.add(params['target_request'] as String);
        paths.add((params['payload'] as Map)['attachment_path'] as String);
        if (++submissions == 1) throw StateError('retry');
        return {'request_id': ids.last, 'status': 'received'};
      },
      upload: (id, bytes) async {
        uploads++;
        expect(img.decodeJpg(bytes), isNotNull);
        return 'owner/$id/photo.jpg';
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: dopmiTheme(),
        home: Scaffold(
          body: HelpSupportDialog(
            topics: const ['Cómo funcionan los apoyos'],
            initialTopic: 0,
            repository: repo,
            pickImage: () async {
              picks++;
              return Uint8List.fromList(
                img.encodePng(img.Image(width: 4, height: 4)),
              );
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).last, 'Ayuda con mi foto');
    tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Adjuntar imagen (opcional)'),
        )
        .onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(uploads, 0);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Cambiar imagen'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continuar en correo'),
          )
          .onPressed,
      isNull,
    );
    final send = find.widgetWithText(FilledButton, 'Enviar mensaje');
    tester.widget<FilledButton>(send).onPressed!();
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu mensaje sigue aquí'), findsOneWidget);
    tester.widget<FilledButton>(send).onPressed!();
    await tester.pumpAndSettle();
    expect(uploads, 1);
    expect(ids, hasLength(2));
    expect(ids.first, ids.last);
    expect(paths.first, paths.last);
    expect(find.text('Recibimos tu mensaje.'), findsOneWidget);
    expect(find.text('Cambiar imagen'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'internal submission preserves draft and stable retry key at text scale $scale',
      (tester) async {
        tester.view.physicalSize = scale == 2
            ? const Size(320, 640)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final ids = <String>[];
        var pending = Completer<dynamic>();
        final repo = SupportRepository((name, params) {
          expect(name, 'dopmi_submit_support_request');
          ids.add(params['target_request'] as String);
          expect((params['payload'] as Map)['topic'], 'support_rules');
          return pending.future;
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            theme: dopmiTheme(),
            home: Scaffold(
              body: HelpSupportDialog(
                topics: const ['Cómo funcionan los apoyos'],
                initialTopic: 0,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField).last, 'Necesito ayuda.');
        await tester.pumpAndSettle();
        final send = find.widgetWithText(FilledButton, 'Enviar mensaje');
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        expect(send.hitTestable(), findsOneWidget);
        final action = tester.widget<FilledButton>(send).onPressed!;
        action();
        action();
        await tester.pump();
        expect(ids, hasLength(1));
        expect(find.bySemanticsLabel('Enviando mensaje'), findsOneWidget);
        expect(find.text('Recibimos tu mensaje.'), findsNothing);
        pending.completeError(StateError('failed'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Tu mensaje sigue aquí'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          'Necesito ayuda.',
        );
        pending = Completer<dynamic>();
        tester.widget<FilledButton>(send).onPressed!();
        await tester.pump();
        expect(ids, hasLength(2));
        expect(ids[0], ids[1]);
        pending.completeError(StateError('failed again'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Mensaje corregido.',
        );
        await tester.pumpAndSettle();
        pending = Completer<dynamic>();
        tester.widget<FilledButton>(send).onPressed!();
        await tester.pump();
        expect(ids, hasLength(3));
        expect(ids[2], isNot(ids[1]));
        pending.complete({'request_id': ids.last, 'status': 'received'});
        await tester.pumpAndSettle();
        expect(find.text('Recibimos tu mensaje.'), findsOneWidget);
        expect(find.text('Enviar mensaje'), findsNothing);
        expect(find.text('Entendido'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
      final next = find.widgetWithText(OutlinedButton, 'Continuar en correo');
      final action = tester.widget<OutlinedButton>(next).onPressed!;
      action();
      action();
      await tester.pump();
      expect(calls, hasLength(1));
      expect(tester.widget<OutlinedButton>(next).onPressed, isNull);
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
      tester.widget<OutlinedButton>(next).onPressed!();
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
