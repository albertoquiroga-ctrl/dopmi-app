import 'dart:convert';
import 'dart:io';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_enrollment_amount.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';
import '../test/guardian_test.dart' show FakeGuardian;
import '../test/rescue_test.dart' show FakeRescue;

import 'capture_design_test.dart' show saveCapture;

void main() {
  testWidgets(
    'Q38-12 integrated enrollment sequential consent and CTA access without payment',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final output = Directory('../../.tools/q38-12-integrated');
      await tester.runAsync(() => output.create(recursive: true));
      for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
        final font = FontLoader(family)
          ..addFont(
            rootBundle.load(
              family == 'MaterialIcons'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$family.ttf',
            ),
          );
        await tester.runAsync(font.load);
      }
      final records = <Map<String, Object?>>[];
      for (final spec in [
        ('normal', const Size(377, 852), 1.0),
        ('115', const Size(377, 852), 1.15),
        ('200', const Size(320, 640), 2.0),
      ]) {
        tester.view.physicalSize = spec.$2;
        tester.platformDispatcher.textScaleFactorTestValue = spec.$3;
        // Synthetic preferences belong only to this flutter_test capturer.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        final repo = FakeGuardian();
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            guardianRepositoryProvider.overrideWithValue(repo),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            guardianEnabledProvider.overrideWithValue(true),
            routerInitialLocationProvider.overrideWithValue('/guardian'),
          ],
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: const DopmiApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Suscribirme'));
        await tester.tap(find.text('Suscribirme'));
        await tester.pumpAndSettle();
        final imageContext = tester.element(
          find.byType(GuardianEnrollmentAmount),
        );
        final images = tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => image.image)
            .toList();
        await tester.runAsync(() async {
          for (final image in images) {
            await precacheImage(image, imageContext);
          }
        });
        await tester.pumpAndSettle();
        final scroller = find.byKey(
          const ValueKey('guardian-enrollment-scroll'),
        );
        final scrollable = find
            .descendant(of: scroller, matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        final dockAction = find.widgetWithText(
          FilledButton,
          'Activar en Stripe',
        );
        final dockTop = tester.getTopLeft(dockAction).dy;
        var frame = 0;
        Future<void> shot(String state) async {
          final dockRect = tester.getRect(dockAction);
          expect(dockRect.top, closeTo(dockTop, .5));
          expect(dockRect.bottom, lessThanOrEqualTo(spec.$2.height));
          expect(dockAction.hitTestable(), findsOneWidget);
          final file = '${spec.$1}-${frame++}-$state.png';
          records.add({
            'file': file,
            'scale': spec.$3,
            'scroll': position.pixels,
            'maxScroll': position.maxScrollExtent,
            'calls': repo.calls.length,
            'checkouts': repo.opened,
            'dockTop': dockRect.top,
            'dockBottom': dockRect.bottom,
          });
          await tester.runAsync(
            () => saveCapture(boundary, '${output.path}/$file'),
          );
        }

        await shot('top');
        while (position.pixels < position.maxScrollExtent - .5) {
          final previous = position.pixels;
          await tester.drag(scroller, Offset(0, -spec.$2.height * .65));
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(previous));
          await shot('scroll');
          if (frame > 25) fail('Unexpected unbounded enrollment scroll');
        }
        final cta = find.widgetWithText(FilledButton, 'Activar en Stripe');
        final action = find.text('Activar en Stripe');
        await tester.ensureVisible(action);
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getBottomRight(action).dy, lessThan(spec.$2.height));
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
        expect(cta, findsOneWidget);
        expect(tester.widget<FilledButton>(cta).onPressed, isNull);
        await tester.ensureVisible(find.byType(Checkbox));
        expect(
          tester.getBottomRight(find.byType(Checkbox)).dy,
          lessThanOrEqualTo(dockTop),
        );
        await shot('consent-off');
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
        await tester.ensureVisible(action);
        expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
        await shot('consent-on-cta');
        expect(action.hitTestable(), findsOneWidget);
        expect(repo.calls, isEmpty);
        expect(repo.opened, 0);
        await tester.tap(find.byTooltip('Regresar'));
        await tester.pumpAndSettle();
        expect(find.text('Sin suscripción'), findsOneWidget);
        await tester.ensureVisible(find.text('Suscribirme'));
        await tester.tap(find.text('Suscribirme'));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
        expect(repo.calls, isEmpty);
        expect(repo.opened, 0);
        records.add({
          'scale': spec.$3,
          'returnRevokesConsent': true,
          'calls': repo.calls.length,
          'checkouts': repo.opened,
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await identity.changes.close();
      }
      await tester.runAsync(
        () =>
            File('${output.path}/access.json')
                .writeAsString(jsonEncode(records)),
      );
    },
  );
  testWidgets(
    'N39 fresh enrollment decorative motion and scaled amount access',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final output = Directory('../../.tools/n39-enrollment');
      await tester.runAsync(() => output.create(recursive: true));
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await tester.runAsync(font.load);
      final frames = <Map<String, Object?>>[];
      for (final spec in [
        ('normal', const Size(377, 852), 1.0),
        ('115', const Size(377, 852), 1.15),
        ('200', const Size(320, 640), 2.0),
      ]) {
        tester.view.physicalSize = spec.$2;
        final boundary = GlobalKey();
        final amount = TextEditingController(text: '50.00');
        final scroll = ScrollController();
        var changed = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: dopmiTheme(),
              debugShowCheckedModeBanner: false,
              home: MediaQuery(
                data: MediaQueryData(
                  size: spec.$2,
                  textScaler: TextScaler.linear(spec.$3),
                ),
                child: Scaffold(
                  backgroundColor: Colors.white,
                  body: SingleChildScrollView(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    child: GuardianEnrollmentAmount(
                      amount: amount,
                      locked: false,
                      decorate: true,
                      onChanged: () => changed++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final imageContext = tester.element(
          find.byType(GuardianEnrollmentAmount),
        );
        final images = tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => image.image)
            .toList();
        await tester.runAsync(() async {
          for (final image in images) {
            await precacheImage(image, imageContext);
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => saveCapture(boundary, '${output.path}/${spec.$1}-top.png'),
        );
        await tester.ensureVisible(find.text(r'$200'));
        await tester.tap(find.text(r'$200'));
        await tester.pump();
        expect(amount.text, '200.00');
        expect(changed, 1);
        scroll.jumpTo(0);
        var elapsed = 0;
        for (final ms in [0, 100, 250, 500, 1100]) {
          await tester.pump(Duration(milliseconds: ms - elapsed));
          elapsed = ms;
          final node = find.byKey(const ValueKey('guardian-bubble-0'));
          final opacity = tester
              .widget<Opacity>(
                find.ancestor(of: node, matching: find.byType(Opacity)),
              )
              .opacity;
          final transform = tester
              .widgetList<Transform>(
                find.ancestor(of: node, matching: find.byType(Transform)),
              )
              .first
              .transform
              .storage
              .toList();
          frames.add({
            'scale': spec.$3,
            'milliseconds': ms,
            'opacity': opacity,
            'transform': transform,
            'amount': amount.text,
          });
          await tester.runAsync(
            () => saveCapture(
              boundary,
              '${output.path}/${spec.$1}-burst-$ms.png',
            ),
          );
        }
        await tester.ensureVisible(find.text('Otra cantidad'));
        await tester.tap(find.text('Otra cantidad'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '20.00');
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => saveCapture(boundary, '${output.path}/${spec.$1}-custom20.png'),
        );
        expect(find.text(r'$20.00 MXN'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        amount.dispose();
        scroll.dispose();
      }
      await tester.runAsync(
        () =>
            File('${output.path}/frames.json')
                .writeAsString(jsonEncode(frames)),
      );
    },
  );
}
