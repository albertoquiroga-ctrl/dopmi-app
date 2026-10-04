import 'package:dopmi_mobile/features/payments/guardian_amount_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  Future<void> start(
    WidgetTester tester, {
    ValueNotifier<bool>? identity,
  }) async {
    tester.view.physicalSize = const Size(377, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => chooseGuardianAmount(
                context,
                5000,
                identity: identity,
                canView: identity == null ? null : () => identity.value,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Changing amount revokes consent, preserves cents and disables unchanged or invalid amounts',
    (tester) async {
      await start(tester);
      final save = find.text('Guardar nueva cantidad');
      bool enabled() =>
          tester
              .widget<FilledButton>(
                find.ancestor(of: save, matching: find.byType(FilledButton)),
              )
              .onPressed !=
          null;
      expect(enabled(), false);
      await tester.enterText(find.byType(TextField), '75.25');
      await tester.pump();
      expect(enabled(), false);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(enabled(), true);
      await tester.enterText(find.byType(TextField), '200');
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '49.99');
      await tester.pump();
      expect(enabled(), false);
    },
  );
  testWidgets(
    'Actor change clears current amount and authorization before confirmation',
    (tester) async {
      final identity = ValueNotifier(true);
      addTearDown(identity.dispose);
      await start(tester, identity: identity);
      await tester.enterText(find.byType(TextField), '75.25');
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      identity.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Guardar nueva cantidad'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('La sesión cambió'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Explicit confirmation returns the authorized personalized cents',
    (tester) async {
      int? result;
      tester.view.physicalSize = const Size(377, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await chooseGuardianAmount(context, 5000);
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '75.25');
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar nueva cantidad'));
      await tester.tap(find.text('Guardar nueva cantidad'));
      await tester.pumpAndSettle();
      expect(result, 7525);
    },
  );
  testWidgets(
    'Large text and keyboard preserve reachable authorization and confirmation',
    (tester) async {
      int? result;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 250),
            ),
            child: child!,
          ),
          theme: ThemeData(fontFamily: 'Inter'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await chooseGuardianAmount(context, 5000);
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final tileTitle = find.text('Aportación mensual').first;
      await tester.ensureVisible(tileTitle);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(tileTitle);
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 10),
        ),
        hasLength(1),
        reason: 'Aportación debe conservarse completa con texto ampliado.',
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '200');
      await tester.pump();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar nueva cantidad'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.text('Guardar nueva cantidad')).dy,
        lessThanOrEqualTo(390),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Guardar nueva cantidad'));
      await tester.pumpAndSettle();
      expect(result, 20000);
    },
  );
}
