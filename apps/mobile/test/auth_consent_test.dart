import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'inline privacy link matches independently scaled text at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var privacy = 0, toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthConsentRow(
                      value: false,
                      onChanged: (_) => toggles++,
                      onOpenTerms: () {},
                      onOpenPrivacy: () => privacy++,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 28),
                      child: Text(
                        'Aviso de Privacidad',
                        key: ValueKey('legal-scale-reference'),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.4,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final link = find.widgetWithText(TextButton, 'Aviso de Privacidad');
      final label = find.descendant(
        of: link,
        matching: find.text('Aviso de Privacidad'),
      );
      expect(
        tester.getRect(label).height,
        closeTo(
          tester
              .getRect(find.byKey(const ValueKey('legal-scale-reference')))
              .height,
          .1,
        ),
      );
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      expect(privacy, 1);
      expect(toggles, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('consent keyboard visits row and each legal action once', (
    tester,
  ) async {
    var accepted = false;
    var terms = 0;
    var privacy = 0;
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                AuthConsentRow(
                  value: accepted,
                  onChanged: (value) => setState(() => accepted = value),
                  onOpenTerms: () => terms++,
                  onOpenPrivacy: () => privacy++,
                ),
                TextButton(
                  onPressed: () => next++,
                  child: const Text('Siguiente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> key(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await key(LogicalKeyboardKey.tab);
    await key(LogicalKeyboardKey.space);
    expect(accepted, isTrue);
    await key(LogicalKeyboardKey.tab);
    await key(LogicalKeyboardKey.enter);
    expect(terms, 1);
    expect(privacy, 0);
    expect(accepted, isTrue);
    await key(LogicalKeyboardKey.tab);
    await key(LogicalKeyboardKey.enter);
    expect(privacy, 1);
    expect(terms, 1);
    expect(accepted, isTrue);
    await key(LogicalKeyboardKey.tab);
    await key(LogicalKeyboardKey.enter);
    expect(next, 1);
    expect(terms, 1);
    expect(privacy, 1);
    expect(tester.takeException(), isNull);
  });
}
