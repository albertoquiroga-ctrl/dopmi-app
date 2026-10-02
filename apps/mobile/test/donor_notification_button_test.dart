import 'package:dopmi_mobile/core/donor_notification_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('notification keyboard focus opens the notification route', (
    tester,
  ) async {
    final destinations = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Center(child: DonorNotificationButton())),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, state) {
            destinations.add(state.uri.path);
            return const Scaffold(body: Text('Notificaciones recibidas'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.style!.overlayColor!.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(button.style!.splashFactory, NoSplash.splashFactory);
    expect(tester.getSize(find.byType(IconButton)), const Size(42, 42));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(destinations, isEmpty);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('reference-keyboard-outline')),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(26));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(destinations, ['/notifications']);
    expect(find.text('Notificaciones recibidas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
