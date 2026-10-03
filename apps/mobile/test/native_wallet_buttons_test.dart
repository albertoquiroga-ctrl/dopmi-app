import 'package:dopmi_mobile/features/payments/native_wallet_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'wallets at text scale $scale only activate available provider',
      (tester) async {
        final selected = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SizedBox(
                  width: 288,
                  child: NativeWalletButtons(
                    availableProvider: 'google_pay',
                    onPressed: selected.add,
                  ),
                ),
              ),
            ),
          ),
        );
        final buttons = tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .toList();
        expect(buttons[0].onPressed, null);
        expect(buttons[1].onPressed, isNotNull);
        await tester.tap(find.text('Google Pay'));
        expect(selected, ['google_pay']);
        expect(tester.takeException(), null);
        for (final element in find.byType(OutlinedButton).evaluate()) {
          expect(
            tester.getSize(find.byWidget(element.widget)).height,
            greaterThanOrEqualTo(56),
          );
        }
      },
    );
  }
}
