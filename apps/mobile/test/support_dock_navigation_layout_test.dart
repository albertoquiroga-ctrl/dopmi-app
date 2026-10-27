import 'dart:math' as math;

import 'package:dopmi_mobile/core/navigation.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
  });
  for (final fixture in [
    (const Size(393, 852), 1.0),
    (const Size(393, 852), 1.15),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'real support dock clears floating donor navigation through the scroll end ${fixture.$1}/${fixture.$2}',
      (tester) async {
        tester.view.physicalSize = fixture.$1;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = fixture.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final routes = <String>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                extendBody: true,
                bottomNavigationBar: DopmiBottomBar(
                  rescuer: false,
                  selectedPath: '/rescue-cases',
                  onSelected: (_) {},
                ),
                body: SupportHomePage(
                  data: DataPage([
                    RescueRecord({
                      'id': 'case-one',
                      'kind': 'case',
                      'status': 'approved',
                      'target_cents': 10000,
                      'funded_cents': 2000,
                      'public_data': {'pet_name': 'Luna', 'photos': <String>[]},
                    }),
                  ], 1),
                  page: 1,
                  error: null,
                  changePage: (_) {},
                ),
              ),
            ),
            GoRoute(
              path: '/guardian',
              builder: (_, state) {
                routes.add(state.uri.toString());
                return const Scaffold(body: Text('Registro Guardian'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            ],
            child: MaterialApp.router(
              theme: dopmiTheme(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final heroImage = find.image(
          const AssetImage('assets/guardian/guardian-carousel-hero.jpg'),
        );
        final image = tester.widget<Image>(heroImage);
        const sourceSize = Size(720, 1280);
        final fitted = applyBoxFit(
          image.fit!,
          sourceSize,
          tester.getSize(heroImage),
        );
        final visibleSource = image.alignment
            .resolve(Directionality.of(tester.element(heroImage)))
            .inscribe(fitted.source, Offset.zero & sourceSize);
        expect(
          visibleSource.top,
          lessThanOrEqualTo(88.1),
          reason: 'The chip begins at source y=110; retain its top margin instead of cropping the embedded copy.',
        );
        expect(visibleSource.left, closeTo(0, .1));
        expect(visibleSource.right, closeTo(sourceSize.width, .1));
        final dock = find.byType(GuardianSupportDock);
        final cta = find.byKey(const ValueKey('guardian-support-cta'));
        final nav = find.byType(DopmiBottomBar);
        final scroll = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scroll).position;
        if (fixture.$2 < 2) {
          expect(
            tester.getRect(dock).bottom,
            closeTo(tester.getRect(nav).top - 10, .1),
          );
          expect(
            find.text('Suscr\u00edbete ahora').hitTestable(),
            findsOneWidget,
          );
        }
        if (position.maxScrollExtent > 0) {
          final card = tester.getRect(
            find.byKey(const ValueKey('guardian-support-carousel')),
          );
          final visibleCardTop = math.max(card.top, 24);
          final unobstructedBottom = fixture.$2 >= 2
              ? tester.getRect(nav).top - 16
              : math.min(
                  tester.getRect(nav).top - 16,
                  tester.getRect(dock).top - 16,
                );
          final visibleCardBottom = math.min(card.bottom, unobstructedBottom);
          expect(visibleCardBottom, greaterThan(visibleCardTop + 20));
          final origin = Offset(
            card.center.dx,
            (visibleCardTop + visibleCardBottom) / 2,
          );
          await tester.dragFrom(origin, const Offset(0, -220));
          await tester.pumpAndSettle();
          expect(
            position.pixels,
            greaterThan(0),
            reason: 'A vertical gesture over the actual deck must reach the outer scroll view.',
          );
          expect(routes, isEmpty);
        }
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(position.maxScrollExtent, .1));
        expect(
          tester.getRect(dock).bottom,
          closeTo(tester.getRect(nav).top - 10, .1),
        );
        expect(tester.getRect(cta).overlaps(tester.getRect(nav)), isFalse);
        if (fixture.$2 >= 2) {
          expect(
            tester.getRect(dock).top,
            greaterThanOrEqualTo(
              tester
                      .getRect(
                        find.byKey(const ValueKey('guardian-support-carousel')),
                      )
                      .bottom +
                  40,
            ),
            reason: 'The enlarged price must clear the rotated deck and its shadow.',
          );
        }
        expect(
          find.text('Suscr\u00edbete ahora').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Suscr\u00edbete ahora'));
        await tester.pumpAndSettle();
        expect(routes, ['/guardian?enroll=1']);
      },
    );
  }
}
