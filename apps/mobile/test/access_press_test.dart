import 'dart:ui' as ui;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';

void main() {
  for (final route in [
    ('/welcome', 'Continuar', '/onboarding'),
    ('/start?intent=adopt', 'Crea una cuenta', '/signup'),
  ]) {
    testWidgets(
      'access route ${route.$1} keeps color while held and navigates on release',
      (tester) async {
        tester.view.physicalSize = const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final identity = FakeIdentityRepository();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            routerInitialLocationProvider.overrideWithValue(route.$1),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: UncontrolledProviderScope(
              container: container,
              child: const DopmiApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (route.$1 == '/welcome') {
          await tester.tap(find.byKey(const ValueKey('welcome-orb-adopt')));
          await tester.pumpAndSettle();
        }
        // Welcome footer has delayed entrance beyond pumpAndSettle timers.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, route.$2);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final rect = tester.getRect(button);
        Future<List<int>?> sample() => tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final current = tester.getRect(button);
          final offset =
              (current.center.dy.floor() * image.width +
                  (current.left + 5).floor()) *
              4;
          final color = bytes!.buffer.asUint8List().sublist(offset, offset + 4);
          image.dispose();
          return color;
        });
        expect(await sample(), [21, 17, 13, 255]);
        final gesture = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(button), rect);
        expect(await sample(), [21, 17, 13, 255]);
        expect(
          container.read(routerProvider).state.uri.path,
          route.$1.split('?').first,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, route.$3);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
