import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/privacy_notice_screen.dart';
import 'package:dopmi_mobile/features/profile/help_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';

void main() {
  for (final mode in ['donor', 'rescuer']) {
    testWidgets(
      'help footer opens legal pages and returns without losing topic: $mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        await identity.setExperience(mode);
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            routerInitialLocationProvider.overrideWithValue('/help'),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        );
        await tester.pumpAndSettle();
        final topic = find.widgetWithText(
          OutlinedButton,
          'Cómo funcionan los apoyos',
        );
        await tester.scrollUntilVisible(
          topic,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(topic), alignment: .5);
        await tester.pumpAndSettle();
        expect(topic.hitTestable(), findsOneWidget);
        await tester.tap(topic);
        await tester.pumpAndSettle();
        for (final link in {
          'Sobre nosotros': '/about',
          'Términos y Condiciones': '/terms',
          'Aviso de privacidad': '/privacy-notice',
        }.entries) {
          final target = find.widgetWithText(TextButton, link.key);
          await tester.scrollUntilVisible(
            target,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(tester.element(target), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, link.value);
          if (link.value == '/privacy-notice') {
            expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
          }
          container.read(routerProvider).pop();
          await tester.pumpAndSettle();
          expect(find.byType(HelpCenterScreen), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Cuando apoyas a un caso'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Cuando apoyas a un caso'), findsOneWidget);
          expect(identity.profile.mode, mode);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
