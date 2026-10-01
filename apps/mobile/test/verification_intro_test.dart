import 'package:dopmi_mobile/features/rescue/verification_intro.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;

void main() {
  testWidgets(
    'verification introduction returns to its origin and continues to real private documents at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await startPublication(tester, FakeCommunity(), '/publish');
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      for (final dismiss in ['Después', 'Cerrar']) {
        router.push<void>('/rescue/new?kind=verification').ignore();
        await tester.pumpAndSettle();
        expect(find.byType(VerificationIntroScreen), findsOneWidget);
        if (dismiss == 'Después') {
          final button = find.text('Después');
          await Scrollable.ensureVisible(tester.element(button), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(button);
        } else {
          await tester.tap(find.byTooltip('Cerrar'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(VerificationIntroScreen), findsNothing);
        expect(router.routeInformationProvider.value.uri.path, '/publish');
        expect(tester.takeException(), isNull);
      }
      router.push<void>('/rescue/new?kind=verification').ignore();
      await tester.pumpAndSettle();
      final continueButton = find.text('Continuar a verificación');
      await Scrollable.ensureVisible(
        tester.element(continueButton),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.byType(VerificationIntroScreen), findsNothing);
      expect(find.byType(RescueEditorScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Documentos y evidencia'),
        200,
        maxScrolls: 20,
      );
      await tester.pumpAndSettle();
      expect(find.text('Documentos y evidencia'), findsOneWidget);
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
