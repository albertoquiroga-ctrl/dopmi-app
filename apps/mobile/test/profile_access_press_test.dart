import 'dart:ui' as ui;

import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'payment access preserves words and all destinations at 320px and $scale text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const items = [
          ('Métodos de pago', Icons.credit_card, '/settings/payment-methods'),
          ('Suscripción Guardián', Icons.receipt_long_outlined, '/guardian'),
          ('Mi historial de pagos', Icons.access_time, '/payments'),
        ];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: DonorAccessGroup(
                      title: 'Pagos y suscripciones',
                      items: items,
                    ),
                  ),
                ),
              ),
            ),
            for (final item in items)
              GoRoute(
                path: item.$3,
                builder: (_, _) => Scaffold(body: Text('Destino ${item.$3}')),
              ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: ThemeData(fontFamily: 'Inter'),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final accesses = find.byType(InkWell);
        final accessRects = [
          for (var index = 0; index < accesses.evaluate().length; index++)
            tester.getRect(accesses.at(index)),
        ];
        expect(accessRects, hasLength(3));
        if (scale == 1) {
          expect(accessRects[1].top, accessRects[0].top);
          expect(accessRects[2].top, accessRects[0].top);
        } else {
          expect(accessRects[1].top, greaterThan(accessRects[0].bottom));
          expect(accessRects[2].top, greaterThan(accessRects[1].bottom));
        }
        for (final item in items) {
          final label = find.text(item.$1);
          final paragraph = tester.renderObject<RenderParagraph>(label);
          for (final word in RegExp(r'\S+').allMatches(item.$1)) {
            expect(
              paragraph.getBoxesForSelection(
                TextSelection(baseOffset: word.start, extentOffset: word.end),
              ),
              hasLength(1),
              reason: '${word.group(0)} must remain whole at $scale text',
            );
          }
          await tester.ensureVisible(label);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(router.state.uri.path, item.$3);
          expect(find.text('Destino ${item.$3}'), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'profile access changes only its circle while held and opens on release',
    (tester) async {
      final key = GlobalKey();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: DonorAccessGroup(
                title: 'Accesos',
                items: [('Mi cuenta', Icons.person_outline, '/account')],
              ),
            ),
          ),
          GoRoute(
            path: '/account',
            builder: (_, _) => const Scaffold(body: Text('Cuenta abierta')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final circle = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      expect(circle, findsOneWidget);
      final rect = tester.getRect(circle);
      Future<List<int>?> sample() => tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final offset =
            ((rect.top + 10).floor() * image.width + rect.center.dx.floor()) *
            4;
        final color = bytes!.buffer.asUint8List().sublist(offset, offset + 4);
        image.dispose();
        return color;
      });
      expect(await sample(), [240, 238, 234, 255]);
      final gesture = await tester.startGesture(rect.center);
      await tester.pump();
      expect(await sample(), [231, 227, 220, 255]);
      expect(router.state.uri.path, '/');
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(await sample(), [240, 238, 234, 255]);
      expect(router.state.uri.path, '/');
      final second = await tester.startGesture(rect.center);
      await tester.pump();
      await second.up();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/account');
      expect(find.text('Cuenta abierta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'profile feature preserves dark surface while pressed and b9 subtitle alpha',
    (tester) async {
      var calls = 0;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            home: Scaffold(
              body: DonorFeature(
                title: 'Sé un Guardián',
                subtitle: 'Apoyo mensual con reportes de impacto',
                icon: Icons.star_border,
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.text('Apoyo mensual con reportes de impacto'))
            .style!
            .color,
        const Color.from(alpha: .92, red: 1, green: 1, blue: 1),
      );
      final rect = tester.getRect(find.byType(DonorFeature));
      Future<List<int>?> sample() => tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final offset =
            (rect.center.dy.floor() * image.width + (rect.left + 12).floor()) *
            4;
        final color = bytes!.buffer.asUint8List().sublist(offset, offset + 4);
        image.dispose();
        return color;
      });
      expect(await sample(), [70, 40, 29, 255]);
      final gesture = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(await sample(), [70, 40, 29, 255]);
      expect(calls, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
