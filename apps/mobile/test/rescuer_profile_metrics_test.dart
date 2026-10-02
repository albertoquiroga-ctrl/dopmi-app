import 'package:dopmi_mobile/features/profile/rescuer_profile_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets('profile uses owner totals and transfers; large=$large', (
      tester,
    ) async {
      tester.view.physicalSize = Size(large ? 640 : 754, 1704);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cases = 0, transfers = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RescuerProfileMetrics(
                  data: {
                    'case_counts': {
                      'active': 2,
                      'draft': 3,
                      'review': 1,
                      'corrections': 2,
                    },
                    'financial': {
                      'assigned_cents': 9200,
                      'transferred_cents': 5015,
                    },
                  },
                  onCases: () => cases++,
                  onTransfers: () => transfers++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text(r'$50.15'), findsOneWidget);
      expect(find.text(r'$92'), findsNothing);
      expect(find.text('Recibido'), findsNothing);
      final cards = find.byType(RescuerProfileMetric);
      if (large) {
        expect(
          tester.getRect(cards.at(0)).left,
          tester.getRect(cards.at(2)).left,
        );
        expect(
          tester.getRect(cards.at(0)).bottom,
          lessThan(tester.getRect(cards.at(1)).top),
        );
      } else {
        expect(tester.getSize(cards.first).height, 84);
      }
      final gesture = await tester.startGesture(tester.getCenter(cards.first));
      await tester.pump(const Duration(milliseconds: 150));
      final animation = find.descendant(
        of: cards.first,
        matching: find.byType(AnimatedScale),
      );
      expect(tester.widget<AnimatedScale>(animation).scale, .98);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(cases, 0);
      await tester.tap(find.text('Casos'));
      await tester.tap(find.text('Activos'));
      await tester.ensureVisible(find.text('Transferido'));
      await tester.tap(find.text('Transferido'));
      await tester.pumpAndSettle();
      expect(cases, 2);
      expect(transfers, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('missing totals are unavailable instead of fabricated zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RescuerProfileMetrics(
            data: const {},
            onCases: () {},
            onTransfers: () {},
          ),
        ),
      ),
    );
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'metrics keyboard traversal preserves actions and touch targets',
    (tester) async {
      var cases = 0, transfers = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RescuerProfileMetrics(
                data: const {},
                onCases: () => cases++,
                onTransfers: () => transfers++,
              ),
            ),
          ),
        ),
      );
      final cards = find.byType(RescuerProfileMetric);
      for (var n = 0; n < 3; n++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final outline = find.descendant(
          of: cards.at(n),
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        expect(outline, findsOneWidget);
        expect(
          find.byKey(const ValueKey('reference-keyboard-outline')),
          findsOneWidget,
        );
        final cardRect = tester.getRect(cards.at(n));
        final outlineRect = tester.getRect(outline);
        expect(outlineRect, cardRect.inflate(5));
        expect(cases, n < 2 ? n : 2);
        expect(transfers, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }
      expect(cases, 2);
      expect(transfers, 1);
      final target = tester.getRect(cards.last);
      await tester.tapAt(Offset(target.left + 6, target.center.dy));
      await tester.pumpAndSettle();
      expect(transfers, 2);
      expect(
        find.byKey(const ValueKey('reference-keyboard-outline')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
