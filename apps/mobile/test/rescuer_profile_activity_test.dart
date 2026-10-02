import 'package:dopmi_mobile/features/profile/rescuer_profile_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'activity shows actual allocation states and expense IDs; large=$large',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1704);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final opened = <String>[];
        var home = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(large ? 2 : 1),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RescuerProfileActivity(
                    data: {
                      'verification_status': 'approved',
                      'recent_activity': [
                        for (var n = 0; n < 4; n++)
                          {
                            'expense_id': 'expense-$n',
                            'expense_title': 'Consulta veterinaria $n',
                            'allocated_cents': 5015,
                            'transfer_status': n == 0 ? 'pending' : 'reversed',
                          },
                      ],
                    },
                    onHome: () => home++,
                    onExpense: opened.add,
                    onStart: () => fail('must not fabricate an empty state'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RescuerProfileActivityRow), findsNWidgets(3));
        expect(find.text('Transferencia en proceso'), findsOneWidget);
        expect(find.text('Transferencia revertida'), findsNWidgets(2));
        expect(find.textContaining(r'$50.15 MXN asignados'), findsNWidgets(3));
        expect(find.textContaining('Consulta veterinaria 3'), findsNothing);
        await tester.tap(find.text('Ver inicio'));
        await tester.ensureVisible(
          find.byType(RescuerProfileActivityRow).first,
        );
        await tester.tap(find.byType(RescuerProfileActivityRow).first);
        await tester.pumpAndSettle();
        expect(home, 1);
        expect(opened, ['expense-0']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final approved in [false, true]) {
    testWidgets('empty activity offers real next step; approved=$approved', (
      tester,
    ) async {
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RescuerProfileActivity(
              data: {
                'verification_status': approved ? 'approved' : 'not_started',
                'recent_activity': const [],
              },
              onHome: () {},
              onExpense: (_) {},
              onStart: () => starts++,
            ),
          ),
        ),
      );
      expect(find.text('Ver inicio'), findsNothing);
      await tester.tap(
        find.text(approved ? 'Publicar caso' : 'Ir a verificación'),
      );
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
