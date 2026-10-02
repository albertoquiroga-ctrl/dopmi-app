import 'dart:ui' show PointerDeviceKind;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public header pointer hover matches 40px reference circle', (
    tester,
  ) async {
    var shared = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: dopmiTheme(),
        home: PublicProfileFrame(
          share: () => shared++,
          child: const Text('Perfil público'),
        ),
      ),
    );
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.byTooltip('Compartir')));
    await tester.pump();
    final hover = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xfff0ede7),
    );
    expect(hover, findsOneWidget);
    expect(tester.getSize(hover), const Size(40, 40));
    await tester.tap(find.byTooltip('Compartir'));
    expect(shared, 1);
    await pointer.moveTo(const Offset(100, 200));
    await tester.pump();
    expect(hover, findsNothing);
  });
  testWidgets(
    'keyboard report shows reference focus and invokes real callback',
    (tester) async {
      final manager = FocusManager.instance;
      final previous = manager.highlightStrategy;
      manager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => manager.highlightStrategy = previous);
      var reported = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: dopmiTheme(),
          home: Scaffold(
            body: PublicProfileTabs(
              selected: 0,
              select: (_) {},
              report: () => reported++,
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      final report = find.widgetWithText(TextButton, 'Reportar');
      final outline = find.byKey(const ValueKey('reference-keyboard-outline'));
      expect(outline, findsOneWidget);
      expect(
        tester.getRect(outline).contains(tester.getCenter(report)),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(reported, 1);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('public profile controls fit narrow width at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? opened;
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: dopmiTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      PublicProfileIdentity(
                        avatar: const SizedBox(width: 96, height: 96),
                        name: 'Refugio Luna',
                        city: 'Monterrey',
                        bio: 'Rescate responsable.',
                        caseCount: 1,
                        verified: false,
                      ),
                      PublicProfileSocials(
                        instagram: 'https://instagram.com/refugio',
                        facebook: '',
                        open: (url) => opened = url,
                      ),
                      PublicProfileTabs(
                        selected: 0,
                        select: (value) => selected = value,
                        report: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Facebook'), findsNothing);
      expect(find.bySemanticsLabel('Rescatista verificado'), findsNothing);
      await tester.tap(find.text('Instagram'));
      expect(opened, 'https://instagram.com/refugio');
      await tester.ensureVisible(find.text('Casos'));
      await tester.tap(find.text('Casos'));
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
