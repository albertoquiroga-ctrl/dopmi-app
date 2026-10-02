import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
