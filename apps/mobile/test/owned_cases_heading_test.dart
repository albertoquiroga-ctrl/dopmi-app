import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets('compact new case retains a full touch target; large=$large', (
      tester,
    ) async {
      tester.view.physicalSize = Size(large ? 320 : 377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await tester.runAsync(font.load);
      final router = GoRouter(
        initialLocation: '/cases',
        routes: [
          GoRoute(
            path: '/cases',
            builder: (_, _) => Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(large ? 320 : 377, 852),
                  textScaler: TextScaler.linear(large ? 2 : 1),
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: OwnedCasesHeading(total: 5),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/publish',
            builder: (_, _) => const Scaffold(body: Text('Publicación')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Nuevo');
      final target = tester.getRect(button);
      expect(target.height, greaterThanOrEqualTo(48));
      final surface = find.descendant(of: button, matching: find.byType(Material));
      final visual = tester.getRect(surface);
      expect(visual.top, closeTo(20, .5));
      expect(visual.height, large ? greaterThan(48) : closeTo(34, .01));
      if (!large) expect(visual.width, closeTo(91.21875, 1));
      // The padded area below the visible pill must also navigate.
      await tester.tapAt(Offset(target.center.dx, target.bottom - 2));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/publish');
      expect(find.text('Publicación'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
