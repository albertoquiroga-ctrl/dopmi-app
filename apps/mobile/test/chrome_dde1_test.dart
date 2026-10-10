import 'package:dopmi_mobile/core/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rescuer_home_screen_test.dart' show HomeRescue, homeFixture, pumpHome;

void main() {
  test('donor destinations retain real branches in reference order', () {
    expect(donorDestinations.map((d) => d.label), [
      'Adoptar',
      'Mis match',
      'Apoyar',
      'Perfil',
    ]);
    expect(donorDestinations.map((d) => d.branch), [0, 6, 1, 2]);
    expect(donorDestinations.map((d) => d.path), [
      '/adoptions',
      '/messages',
      '/rescue-cases',
      '/profile',
    ]);
  });

  testWidgets(
    'home initially shows adoption and completing profile preserves Back',
    (tester) async {
      final rescue = HomeRescue()
        ..home = homeFixture(verification: 'submitted');
      final (router, _) = await pumpHome(tester, rescue);
      expect(
        find.byKey(const ValueKey('home-funnel-adoption')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-funnel-support')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-complete-profile')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/rescuer/profile/edit');
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/rescuer');
      expect(
        find.byKey(const ValueKey('home-funnel-adoption')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
