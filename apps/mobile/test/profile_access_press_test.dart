import 'dart:ui' as ui;

import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
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
}
