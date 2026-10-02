import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'public metrics preserve real cents and unknown counts at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dopmiTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: PublicProfileMetrics(
                      name: 'Refugio Luna',
                      metrics: {
                        'active_donation_cases': 2,
                        'active_adoptions': 1,
                        'funded_cents': 9901,
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('\$99.01'), findsOneWidget);
        expect(find.text('—'), findsNWidgets(5));
        expect(find.text('Donaciones activas'), findsOneWidget);
        expect(find.text('Neto asignado'), findsOneWidget);
        if (scale == 2) {
          final stats = find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(18),
          );
          expect(stats, findsNWidgets(6));
          for (final element in stats.evaluate()) {
            expect(tester.getSize(find.byWidget(element.widget)).width, 288);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
