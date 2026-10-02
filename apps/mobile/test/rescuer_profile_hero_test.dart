import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in ['submitted', 'changes_requested', 'approved']) {
    testWidgets(
      'rescuer identity reflows and edits only with approved status: $status',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1280);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var edits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RescuerIdentityCard(
                    name: 'Rescatista con nombre extenso',
                    city: 'Monterrey, Nuevo León',
                    status: status,
                    onEdit: () => edits++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Rescatista con nombre extenso'), findsOneWidget);
        expect(
          find.text('Verificado'),
          status == 'approved' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Editar'),
          status == 'approved' ? findsOneWidget : findsNothing,
        );
        if (status == 'approved') {
          await tester.ensureVisible(find.text('Editar'));
          await tester.tap(find.text('Editar'));
          await tester.pumpAndSettle();
          expect(edits, 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final reduced in [false, true]) {
    testWidgets(
      'rescuer edit press matches source and cancel does not navigate: $reduced',
      (tester) async {
        var edits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: RescuerIdentityCard(
                  name: 'Ana',
                  city: 'Monterrey',
                  status: 'approved',
                  onEdit: () => edits++,
                ),
              ),
            ),
          ),
        );
        final button = find.byKey(const ValueKey('rescuer-profile-edit'));
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 150));
        final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        expect(scale.scale, .97);
        expect(
          scale.duration,
          reduced ? Duration.zero : const Duration(milliseconds: 120),
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(edits, 0);
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(edits, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
