import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';
import '../test/guardian_test.dart' show FakeGuardian, activePlan;
import 'capture_design_test.dart' show saveCapture;

Future<DataPage<Json>> fixturePaymentHistory() async => const DataPage([
  {
    'expense_title': 'Max · Comida',
    'payment_status': 'confirmed',
    'gross_cents': 10000,
  },
  {
    'expense_title': 'Luna · Medicina',
    'payment_status': 'confirmed',
    'gross_cents': 12000,
  },
  {
    'expense_title': 'Milo · Tratamiento veterinario',
    'payment_status': 'pending',
    'gross_cents': 2500,
  },
], 3);

void main() {
  testWidgets('capture actual profile/settings/publication screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = const Size(377, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load(
            family == 'MaterialIcons'
                ? 'fonts/MaterialIcons-Regular.otf'
                : 'assets/fonts/$family.ttf',
          ),
        );
      await tester.runAsync(loader.load);
    }
    final out = Directory('../../.tools/design-review');
    for (final path in [
      for (final name in [
        'logo-paw',
        'icon-star',
        'icon-shield',
        'rtab-home',
        'onb-camera',
        'rtab-publish',
        'onb-adopt-heart',
        'icon-user',
        'icon-card',
        'icon-billing',
        'icon-clock',
        'icon-heart',
        'icon-bell',
        'icon-doc',
        'icon-help',
        'icon-logout',
        'icon-chevron-right',
        'tab-adoption',
        'tab-donate',
        'intent-rescuer',
        'icon-x-muted',
        'discovery-message',
      ])
        'assets/profile/$name.svg',
      for (final name in [
        'rtab-home',
        'tab-donate',
        'icon-heart',
        'tab-profile',
      ])
        'assets/navigation/$name.svg',
    ]) {
      final asset = SvgAssetLoader(path);
      await tester.runAsync(
        () => svg.cache.putIfAbsent(
          asset.cacheKey(null),
          () => asset.loadBytes(null),
        ),
      );
    }
    await tester.runAsync(() => out.create(recursive: true));
    for (final spec in [
      ('adoption-swipe', '/adoptions'),
      ('adoption-large', '/adoptions'),
      ('adoption-drag', '/adoptions'),
      ('adoption-filters', '/adoptions'),
      ('adoption-filters-large', '/adoptions'),
      ('profile-overview', '/profile'),
      ('profile-overview-active', '/profile'),
      ('profile-overview-large', '/profile'),
      ('profile-mode-dialog', '/profile'),
      ('profile-settings', '/settings'),
      ('profile-support', '/profile'),
      ('about', '/about'),
      ('about-large', '/about'),
      ('transparency', '/transparency'),
      ('transparency-criteria', '/transparency'),
      ('publish-choice', '/publish'),
    ]) {
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await repo.saveProfile(name: 'Ana', phone: '', city: 'Monterrey, NL');
      final large = spec.$1.endsWith('-large');
      tester.view.physicalSize = large
          ? const Size(320, 640)
          : const Size(377, 852);
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final guardian = FakeGuardian();
      final community = FakeCommunity();
      if (spec.$1 == 'adoption-drag') {
        // The actual deck includes a second card beneath a drag.
        community.discoveryItems = [
          community.post,
          Adoption({...community.post.data, 'id': 'next', 'pet_name': 'Milo'}),
        ];
      }
      if (spec.$1 == 'profile-overview-active') {
        guardian.value = {'plan': activePlan(), 'activation': null};
      }
      if (spec.$1 == 'publish-choice') {
        await repo.setExperience('rescuer');
      }
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          communityRepositoryProvider.overrideWithValue(community),
          guardianEnabledProvider.overrideWithValue(true),
          guardianRepositoryProvider.overrideWithValue(guardian),
          profilePaymentHistoryProvider.overrideWithValue(
            fixturePaymentHistory,
          ),
          routerInitialLocationProvider.overrideWithValue(spec.$2),
        ],
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (spec.$1.startsWith('adoption-filters')) {
        await tester.tap(find.byTooltip('Filtros'));
        await tester.pumpAndSettle();
        if (spec.$1 == 'adoption-filters') {
          await tester.tap(
            find.descendant(
              of: find.byType(Dialog),
              matching: find.text('Hembra'),
            ),
          );
          await tester.tap(find.byTooltip('Mediano'));
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1 == 'adoption-drag') {
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Luna')),
        );
        await gesture.moveBy(const Offset(65, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        await tester.runAsync(
          () => saveCapture(key, '${out.path}/${spec.$1}.png'),
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'profile-support') {
        await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'transparency-criteria') {
        final target = find.text('Ver criterios');
        await tester.scrollUntilVisible(target, 300);
        await Scrollable.ensureVisible(tester.element(target), alignment: .25);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'profile-mode-dialog') {
        final target = find.text('Publica un caso de adopción');
        await Scrollable.ensureVisible(tester.element(target), alignment: .25);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(DonorModeDialog), findsOneWidget);
      }
      if (spec.$1 != 'adoption-drag') {
        await tester.runAsync(
          () => saveCapture(key, '${out.path}/${spec.$1}.png'),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await repo.changes.close();
    }
    debugDisableShadows = true;
  });
}
