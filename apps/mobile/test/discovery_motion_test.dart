import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class PendingFavorite extends FakeCommunity {
  final result = Completer<void>();
  int saves = 0;
  @override
  Future<void> favorite(String id, bool saved) async {
    saves++;
    await result.future;
    await super.favorite(id, saved);
  }
}

void main() {
  Future<FakeCommunity> open(
    WidgetTester tester, {
    bool large = false,
    FakeCommunity? repository,
  }) async {
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await tester.runAsync(font.load);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final repo = repository ?? FakeCommunity();
    repo.discoveryItems = [
      repo.post,
      Adoption({...repo.post.data, 'id': 'next', 'pet_name': 'Milo'}),
    ];
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        routerInitialLocationProvider.overrideWithValue('/adoptions'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'card follows finger immediately, threshold returns, cancel never saves, exit lasts 280ms',
    (tester) async {
      final repo = await open(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Luna')),
      );
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      final motion = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('discovery-motion-post')),
      );
      expect(motion.duration, Duration.zero);
      expect(motion.transform!.storage[12], closeTo(60, .1));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(repo.post.saved, false);
      expect(find.text('Luna'), findsOneWidget);
      await tester.drag(find.text('Luna'), const Offset(-105, 0));
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsOneWidget);
      await tester.tap(find.byTooltip('Pasar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Milo'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Milo'), findsOneWidget);
      final next = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('discovery-motion-next')),
      );
      expect(next.transform!.storage[12], 0);
    },
  );

  testWidgets('small screen large text keeps species and actions reachable', (
    tester,
  ) async {
    await open(tester, large: true);
    await tester.scrollUntilVisible(find.byTooltip('Pasar'), 200);
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Pasar')),
      alignment: .25,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Milo'), findsOneWidget);
  });
  testWidgets(
    'pending favorite locks duplicate actions and failure restores the card',
    (tester) async {
      final repo = PendingFavorite();
      await open(tester, repository: repo);
      await tester.tap(find.byTooltip('Me gusta'));
      await tester.pump();
      await tester.tap(find.byTooltip('Me gusta'));
      await tester.tap(find.byTooltip('Pasar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.saves, 1);
      expect(find.text('Luna'), findsOneWidget);
      expect(repo.post.saved, false);
      repo.result.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Volver a intentar'), findsOneWidget);
      final motion = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('discovery-motion-post')),
      );
      expect(motion.transform!.storage[12], 0);
    },
  );
  testWidgets('reduced motion advances without a timed exit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester);
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pump();
    expect(find.text('Milo'), findsOneWidget);
    expect(find.text('Luna'), findsNothing);
  });
}
