import 'dart:math' as math;

import 'package:dopmi_mobile/core/navigation.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    (const Size(377, 852), 1.0),
    (const Size(393, 852), 1.15),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'real support dock clears floating donor navigation through the scroll end ${fixture.$1}/${fixture.$2}',
      (tester) async {
        tester.view.physicalSize = fixture.$1;
        tester.view.devicePixelRatio = 1;
        // Reproduce the 377px reference capture's zero system insets. Keep
        // real safe-area coverage on the Samsung/enlarged-text fixtures.
        final safeInset = fixture.$2 == 1 ? 0.0 : 24.0;
        tester.view.padding = FakeViewPadding(
          top: safeInset,
          bottom: safeInset,
        );
        tester.view.viewPadding = FakeViewPadding(
          top: safeInset,
          bottom: safeInset,
        );
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
        // The zero-inset reference reserves 92px beneath the dock (bottom760
        // on852px). The navigation widget's painted rectangle starts2px below
        // that reserved footprint; do not equate its bounds with the footprint.
        final expectedDockBottom = fixture.$2 == 1
            ? fixture.$1.height - 92
            : tester.getRect(nav).top - 10;
        // Fractional poster scaling may round the nominal12px gap by1px.
        // Keep a real gap at both scroll positions rather than tuning artwork.
        const minimumDeckClearance = 11.0;
        if (fixture.$2 == 1) {
          expect(tester.getRect(dock).bottom, closeTo(expectedDockBottom, .1));
          expect(
            find.text('Suscr\u00edbete ahora').hitTestable(),
            findsOneWidget,
          );
          final price = tester.getRect(find.text('Desde \$20 / mes'));
          final button = tester.getRect(cta);
          final card = tester.getRect(
            find.byKey(const ValueKey('guardian-support-carousel')),
          );
          expect(price.center.dy, closeTo(button.center.dy, .1));
          expect(
            price.top,
            greaterThanOrEqualTo(card.bottom + minimumDeckClearance),
          );
          expect(
            button.top,
            greaterThanOrEqualTo(card.bottom + minimumDeckClearance),
          );
          expect(button.right, closeTo(fixture.$1.width - 21, .1));
        }
        if (position.maxScrollExtent > 0) {
          final card = tester.getRect(
            find.byKey(const ValueKey('guardian-support-carousel')),
          );
          final visibleCardTop = math.max(card.top, safeInset);
          final unobstructedBottom = fixture.$2 > 1
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
        expect(tester.getRect(dock).bottom, closeTo(expectedDockBottom, .1));
        expect(tester.getRect(cta).overlaps(tester.getRect(nav)), isFalse);
        final price = find.text('Desde \$20 / mes');
        final label = find.text('Suscr\u00edbete ahora');
        final dockRect = tester.getRect(dock);
        final priceRect = tester.getRect(price);
        final ctaRect = tester.getRect(cta);
        final labelRect = tester.getRect(label);
        expect(priceRect.overlaps(ctaRect), isFalse);
        expect(priceRect.left, greaterThanOrEqualTo(dockRect.left - .1));
        expect(priceRect.right, lessThanOrEqualTo(dockRect.right + .1));
        expect(ctaRect.height, greaterThanOrEqualTo(52));
        expect(labelRect.left, greaterThanOrEqualTo(ctaRect.left + 26 - .1));
        expect(labelRect.right, lessThanOrEqualTo(ctaRect.right - 26 + .1));
        expect(labelRect.top, greaterThanOrEqualTo(ctaRect.top + 12 - .1));
        expect(labelRect.bottom, lessThanOrEqualTo(ctaRect.bottom - 12 + .1));
        if ((priceRect.center.dy - ctaRect.center.dy).abs() < 1) {
          expect(ctaRect.left - priceRect.right, greaterThanOrEqualTo(11.9));
        } else {
          expect(ctaRect.top - priceRect.bottom, closeTo(8, .1));
        }
        if (fixture.$2 == 1) {
          expect(priceRect.center.dy, closeTo(ctaRect.center.dy, .1));
          expect(
            dockRect.top,
            greaterThanOrEqualTo(
              tester
                      .getRect(
                        find.byKey(const ValueKey('guardian-support-carousel')),
                      )
                      .bottom +
                  minimumDeckClearance,
            ),
            reason: 'The real 377px row must clear the hero at both scroll positions.',
          );
          expect(
            ctaRect.width,
            inInclusiveRange(183, 201),
            reason: 'The reference CTA is about 189px wide; the former 151px button is visibly too narrow.',
          );
        }
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse);
        final glyphBoxes = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: paragraph.text.toPlainText().length,
          ),
        );
        expect(glyphBoxes, isNotEmpty);
        // Tight font boxes may extend beyond the logical paragraph's line
        // height. The label's 26/12px layout padding is checked above; every
        // glyph must also stay inside the button's actual colored surface.
        final buttonSurface = ctaRect.deflate(2);
        for (final box in glyphBoxes) {
          final bounds = box.toRect().shift(labelRect.topLeft);
          expect(bounds.left, greaterThanOrEqualTo(buttonSurface.left - .1));
          expect(bounds.right, lessThanOrEqualTo(buttonSurface.right + .1));
          expect(bounds.top, greaterThanOrEqualTo(buttonSurface.top - .1));
          expect(bounds.bottom, lessThanOrEqualTo(buttonSurface.bottom + .1));
        }
        expect(price.hitTestable(), findsOneWidget);
        if (fixture.$2 > 1) {
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
