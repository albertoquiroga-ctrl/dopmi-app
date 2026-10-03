import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:dopmi_mobile/features/profile/rescuer_settings_details.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_social_dialog.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class SettingsSocialProfile extends FakeRescuerProfile {
  @override
  String? get userId => 'one';
  bool failSave = false;
  int attempts = 0;
  @override
  Future<Json> save(Json payload, {int? version}) async {
    attempts++;
    if (failSave) throw StateError('version_conflict');
    return super.save(payload, version: version);
  }
}

void main() {
  testWidgets(
    'social dialog validates links, retries safely, and hides an expired session',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final profile = SettingsSocialProfile()..value['owner_id'] = 'one';
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          rescuerProfileRepositoryProvider.overrideWithValue(profile),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      editRescuerSocial(context, profile.value, 'facebook_url'),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('rescuer-social-input'));
      await tester.enterText(input, 'https://facebook.com.ejemplo.test/perfil');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(profile.attempts, 0);
      await tester.enterText(input, 'https://www.facebook.com/refugio');
      await tester.pump();
      profile.failSave = true;
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(profile.attempts, 1);
      expect(profile.saves, 0);
      expect(find.byType(RescuerSocialDialog), findsOneWidget);
      profile.failSave = false;
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(profile.attempts, 2);
      expect(profile.saves, 1);
      expect(profile.value['facebook_url'], 'https://www.facebook.com/refugio');
      expect(profile.value['display_name'], 'Refugio Luna');
      expect(profile.value['version'], 4);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await container.read(identityControllerProvider).logout();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('La sesión cambió'), findsOneWidget);
      expect(profile.attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'settings row preserves reference height and its edit target: $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: ListView(
                  children: const [
                    SettingsDataRow(
                      label: 'Instagram',
                      value: 'Cuenta',
                      icon: 'icon-instagram',
                      path: '/edit',
                      editLabel: 'Editar Instagram',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final row = tester.getRect(find.byType(SettingsDataRow));
        final target = tester.getRect(find.byTooltip('Editar Instagram'));
        expect(target.size, const Size(48, 48));
        expect(target.center.dx, closeTo(row.right - 35, .01));
        expect(target.center.dy, closeTo(row.center.dy, .01));
        expect(row.contains(target.topLeft), isTrue);
        expect(row.contains(target.bottomRight), isTrue);
        if (scale == 1) expect(row.height, closeTo(70, .01));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'edit hover and keyboard focus use the visible circle and keep touch activation',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SettingsEditButton(
                label: 'Editar Instagram',
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      );
      final circle = find.byKey(const ValueKey('settings-edit-circle'));
      Color? background() =>
          (tester.widget<Container>(circle).decoration as BoxDecoration).color;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(circle));
      await tester.pump();
      expect(background(), const Color(0xfff0ede7));
      expect(calls, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final outline = find.byKey(const ValueKey('reference-keyboard-outline'));
      expect(tester.getSize(outline), const Size(50, 50));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, 1);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(background(), Colors.transparent);
      await tester.tapAt(
        tester.getTopLeft(find.byTooltip('Editar Instagram')) +
            const Offset(2, 2),
      );
      await tester.pump();
      expect(calls, 2);
      expect(outline, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final mismatch in [false, true]) {
    testWidgets(
      'settings private social owner validation and real editor refresh: $mismatch',
      (tester) async {
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        await identity.setExperience('rescuer');
        final profile = SettingsSocialProfile()
          ..value['owner_id'] = mismatch ? 'other' : 'one'
          ..value['instagram_url'] = 'https://www.instagram.com/own-profile';
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            rescuerProfileRepositoryProvider.overrideWithValue(profile),
            routerInitialLocationProvider.overrideWithValue('/settings'),
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
        expect(find.byTooltip('Notificaciones'), findsNothing);
        if (mismatch) {
          expect(
            find.text('https://www.instagram.com/own-profile'),
            findsNothing,
          );
          profile.value['owner_id'] = 'one';
          await tester.ensureVisible(find.text('Volver a intentar'));
          await tester.tap(find.text('Volver a intentar'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text('https://www.instagram.com/own-profile'),
          findsOneWidget,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byTooltip('Editar Instagram')),
          alignment: .35,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Editar Instagram'));
        await tester.pumpAndSettle();
        expect(find.byType(RescuerSocialDialog), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          '@own-profile',
        );
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(profile.saves, 0);
        await tester.tap(find.byTooltip('Editar Instagram'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('rescuer-social-input')),
          '@updated_profile',
        );
        await tester.pump();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(profile.saves, 1);
        expect(find.byType(RescuerSocialDialog), findsNothing);
        expect(
          find.text('https://www.instagram.com/updated_profile'),
          findsOneWidget,
        );
        expect(profile.saves, 1);
        expect(profile.value['display_name'], 'Refugio Luna');
        expect(profile.value['bio'], 'Rescate responsable.');
        expect(profile.value['facebook_url'], '');
        expect(profile.value['version'], 4);
        expect(profile.value['status'], 'draft');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
