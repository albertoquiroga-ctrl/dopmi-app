import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class ContactRepository extends FakeCommunity {
  int starts = 0;
  bool fail = false;
  @override
  Future<String> startThread(String postId) async {
    starts++;
    if (fail) throw Exception('offline');
    return super.startThread(postId);
  }
}

void main() {
  Future<ContactRepository> open(
    WidgetTester tester, {
    bool large = false,
  }) async {
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final repository = ContactRepository();
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repository),
        routerInitialLocationProvider.overrideWithValue('/adoptions'),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Contactar')),
      alignment: .25,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Contactar'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('cancel and close never create a thread', (tester) async {
    final repository = await open(tester);
    await tester.tap(find.text('Todavía no'));
    await tester.pumpAndSettle();
    expect(repository.starts, 0);
    await tester.tap(find.byTooltip('Contactar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(repository.starts, 0);
    expect(find.text('Luna'), findsOneWidget);
  });

  testWidgets(
    'failed contact retains card and only success opens conversation',
    (tester) async {
      final repository = await open(tester)
        ..fail = true;
      await tester.tap(find.text('Sí, contactar rescatista'));
      await tester.pumpAndSettle();
      expect(repository.starts, 1);
      expect(find.text('Luna'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Luna')),
        findsNothing,
      );
      repository.fail = false;
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Contactar')),
        alignment: .25,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Contactar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, contactar rescatista'));
      await tester.pumpAndSettle();
      expect(repository.starts, 2);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Luna')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'large text scrolls to confirmation with close always reachable',
    (tester) async {
      final repository = await open(tester, large: true);
      expect(
        tester.getRect(find.byTooltip('Cerrar')).top,
        greaterThanOrEqualTo(0),
      );
      expect(
        tester.getRect(find.byTooltip('Cerrar')).bottom,
        lessThanOrEqualTo(640),
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Sí, contactar rescatista')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, contactar rescatista'));
      await tester.pumpAndSettle();
      expect(repository.starts, 1);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Luna')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
