import 'package:dopmi_mobile/features/rescue/verification_intro.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
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
        const title = 'Verifícate para recibir donaciones';
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title),
        );
        final start = title.indexOf('donaciones');
        expect(
          paragraph.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: title.length),
          ),
          hasLength(1),
          reason: 'Text enlargement must keep donaciones on one line',
        );
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
      final button = find.ancestor(
        of: continueButton,
        matching: find.byType(FilledButton),
      );
      final labelRect = tester.getRect(continueButton);
      final buttonRect = tester.getRect(button);
      expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top + 9.9));
      expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom - 9.9));
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.byType(VerificationIntroScreen), findsNothing);
      expect(find.byType(RescueEditorScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Documentos'),
        200,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('verification-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Documentos'), findsOneWidget);
      expect(find.text('Formulario de verificación'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
