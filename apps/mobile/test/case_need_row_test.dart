import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/features/rescue/case_need_row.dart';

void main() {
  testWidgets('need rows wrap authored details and preserve removal at 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var removed = false;
    final item = <String, dynamic>{
      'type': 'medicine',
      'title': 'Medicina prescrita',
      'amount_cents': 12345,
      'detail': 'Tratamiento indicado para su recuperación.',
      'urgent': true,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CaseNeedRow(
              item: item,
              showRemove: true,
              showUrgency: true,
              onRemove: () => removed = true,
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('\$123.45 • Tratamiento indicado para su recuperación.'),
      findsOneWidget,
    );
    expect(find.text('Urgente'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    expect(removed, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CaseNeedRow(item: item, showRemove: true)),
      ),
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Eliminar'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CaseNeedRow(item: item)),
      ),
    );
    expect(find.text('Eliminar'), findsNothing);
    expect(find.text('Urgente'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
