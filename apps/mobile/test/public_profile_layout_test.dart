import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
