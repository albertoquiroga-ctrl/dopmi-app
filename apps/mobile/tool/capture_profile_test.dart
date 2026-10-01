import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_photo_client.dart';

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
import '../test/rescue_test.dart' show FakeRescue, FakeCaseUpdates;
import '../test/payments_test.dart' show FakePayments;

import 'package:dopmi_mobile/features/payments/payment_repository.dart';

import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

import '../test/guardian_test.dart' show FakeGuardian, activePlan;
import 'capture_design_test.dart' show saveCapture;

class SupportCaptureRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      caseId != null
      ? super.catalog(page, caseId: caseId)
      : DataPage([
          for (final item in [
            ('Luna', 1200, 1800),
            ('Milo', 800, 1200),
            ('Nina', 4500, 9500),
            ('Rocky', 25000, 145000),
          ])
            RescueRecord({
              'id': item.$1,
              'kind': 'case',
              'status': 'approved',
              'target_cents': item.$3,
              'funded_cents': item.$2,
              'public_data': {
                'pet_name': item.$1,
                'photos': ['fixture/approved'],
              },
            }),
        ], 4);
  @override
  Future<String> fileUrl(String path) async =>
      'https://fixture.invalid/approved';
}

class CaseCaptureRescue extends SupportCaptureRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage([
        RescueRecord({
          'id': 'case-one',
          'owner_id': 'rescuer-one',
          'kind': 'case',
          'status': 'approved',
          'target_cents': 250000,
          'funded_cents': 50000,
          'rescuer_name': 'Patricia V.',
          'public_data': {
            'pet_name': 'Rocky',
            'city': 'Monterrey',
            'state': 'MX',
            'story': 'Rocky llegó con heridas y desnutrición. Con tu apoyo cubriremos su cirugía, controles y alimentación mientras se recupera y busca un hogar.',
            'photos': ['fixture/one', 'fixture/two', 'fixture/three'],
          },
        }),
        for (final item in [
          ('Cirugía', 'veterinary', 145000, 25000),
          ('Cita veterinario', 'veterinary', 70000, 20000),
          ('Desparasitante', 'medicine', 25000, 5000),
          ('Croquetas', 'food', 10000, 0),
        ])
          RescueRecord({
            'id': item.$1,
            'kind': 'expense',
            'status': 'approved',
            'parent_id': 'case-one',
            'target_cents': item.$3,
            'funded_cents': item.$4,
            'public_data': {
              'title': item.$1,
              'category': item.$2,
              'photos': <String>[],
            },
          }),
      ], 5);
}

class ContributionCapturePayments extends FakePayments {
  @override
  Future<Json> funding(String expense) async => {
    'title': 'Cirugía',
    'reimbursable_cents': 145000,
    'funded_cents': 25000,
    'transferred_cents': 0,
    'available_cents': 120000,
    'payable': true,
  };
}

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

class DetailCaptureCommunity extends FakeCommunity {
  @override
  Future<String> photoUrl(String path) async => 'https://fixture.invalid/$path';
  @override
  Future<Json?> publicProfile(String id) async => {'verified': true};
}

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
        'back',
        'location',
        'icon-share',
        'icon-alert-circle',
        'icon-verified',
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
    final fixturePhoto = await tester.runAsync(
      () => File('tool/fixtures/rocky.png').readAsBytes(),
    );
    debugNetworkImageHttpClientProvider = () =>
        FixturePhotoClient(fixturePhoto!);
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    for (final spec in [
      ('adoption-swipe', '/adoptions'),
      ('adoption-large', '/adoptions'),
      ('adoption-drag', '/adoptions'),
      ('adoption-filters', '/adoptions'),
      ('adoption-filters-large', '/adoptions'),
      ('adoption-contact', '/adoptions'),
      ('adoption-contact-large', '/adoptions'),
      ('adoption-detail', '/adoptions/post'),
      ('adoption-detail-large', '/adoptions/post'),
      ('adoption-empty', '/adoptions'),
      ('adoption-empty-large', '/adoptions'),
      ('adoption-end', '/adoptions'),
      ('match-threads', '/messages'),
      ('match-threads-large', '/messages'),
      ('match-all', '/messages'),
      ('match-all-large', '/messages'),
      ('match-empty', '/messages'),
      ('match-empty-large', '/messages'),
      ('chat-bubbles', '/messages/thread-one'),
      ('chat-bubbles-large', '/messages/thread-one'),
      ('chat-bubbles-rescuer', '/messages/thread-one'),
      ('support-home', '/rescue-cases'),
      ('support-home-large', '/rescue-cases'),
      ('case-detail', '/rescue-cases/case-one'),
      (
        'contribution-review',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-review-large',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      ('contribution-amount', '/contribute/Cirugía?case=case-one'),
      ('contribution-amount-large', '/contribute/Cirugía?case=case-one'),
      ('case-detail-large', '/rescue-cases/case-one'),
      ('case-detail-expenses', '/rescue-cases/case-one'),
      ('case-detail-amount', '/rescue-cases/case-one'),
      ('case-detail-amount-large', '/rescue-cases/case-one'),
      ('case-detail-expenses-large', '/rescue-cases/case-one'),
      ('match-home', '/messages'),
      ('match-home-large', '/messages'),
      ('adoption-support', '/adoptions'),
      ('adoption-support-large', '/adoptions'),
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
      // Synthetic preferences belong only to this flutter_test capturer.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await repo.saveProfile(name: 'Ana', phone: '', city: 'Monterrey, NL');
      final large = spec.$1.endsWith('-large');
      tester.view.physicalSize = large
          ? const Size(320, 640)
          : const Size(377, 852);
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      if (spec.$1.startsWith('adoption-support')) {
        final milo = await tester.runAsync(
          () => File('tool/fixtures/milo.png').readAsBytes(),
        );
        debugNetworkImageHttpClientProvider = () => FixturePhotoClient(milo!);
      } else {
        debugNetworkImageHttpClientProvider = () =>
            FixturePhotoClient(fixturePhoto!);
      }
      final guardian = FakeGuardian();
      final community =
          (spec.$1.startsWith('adoption-detail') ||
              spec.$1 == 'adoption-end' ||
              spec.$1.startsWith('adoption-support'))
          ? DetailCaptureCommunity()
          : FakeCommunity();
      if (spec.$1.startsWith('adoption-empty')) community.discoveryItems = [];
      if ((spec.$1.startsWith('adoption-detail') ||
          spec.$1 == 'adoption-end')) {
        community.post = Adoption({
          ...community.post.data,
          'pet_name': 'Rocky',
          'publisher_name': 'Patricia V.',
          'sex': 'male',
          'size': 'large',
          'region': 'MX',
          'distance_km': 3.4,
          'story': 'Rescatado de la calle el mes pasado. Muy amistoso y listo para encontrar hogar.',
          'photos': ['fixture/one', 'fixture/two', 'fixture/three'],
          'saved': true,
        });
      }
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
      if (spec.$1 == 'publish-choice' || spec.$1 == 'chat-bubbles-rescuer') {
        await repo.setExperience('rescuer');
      }
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          communityRepositoryProvider.overrideWithValue(community),
          if (spec.$1.startsWith('contribution'))
            paymentRepositoryProvider.overrideWithValue(
              ContributionCapturePayments(),
            ),
          if (spec.$1.startsWith('case-detail') ||
              spec.$1.startsWith('contribution')) ...[
            rescueRepositoryProvider.overrideWithValue(CaseCaptureRescue()),
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
          ],
          if (spec.$1.startsWith('support-home'))
            rescueRepositoryProvider.overrideWithValue(SupportCaptureRescue()),
          guardianEnabledProvider.overrideWithValue(true),
          guardianRepositoryProvider.overrideWithValue(guardian),
          profilePaymentHistoryProvider.overrideWithValue(
            fixturePaymentHistory,
          ),
          routerInitialLocationProvider.overrideWithValue(spec.$2),
        ],
      );
      final key = GlobalKey();
      if (spec.$1.startsWith('adoption-support')) {
        community.discoveryItems = [
          community.post,
          Adoption({...community.post.data, 'id': 'second'}),
        ];
        community.supportItems = [
          SupportOpportunity({
            'case_id': 'case-one',
            'expense_id': 'expense-one',
            'pet_name': 'Milo',
            'photo': 'approved/milo.png',
            'expense_title': 'Spray para heridas',
            'reimbursable_cents': 1200,
            'funded_cents': 800,
          }),
        ];
      }
      if (spec.$1.startsWith('match-threads')) {
        community.threadItems = [
          {
            'id': 'one',
            'post_id': 'post',
            'pet_name': 'Rocky',
            'participant_name': 'Patricia V.',
            'last_message': 'Perfecto. ¿Cuándo podrías visitarlo?',
            'unread_count': 1,
            'status': 'active',
            'updated_at': '2026-09-30T18:30:00Z',
          },
          {
            'id': 'two',
            'pet_name': 'Toby',
            'participant_name': 'Carlos Ruiz',
            'last_message':
                'Gracias por tu interés en adoptar. ¿Quieres conocerlo?',
            'unread_count': 0,
            'status': 'active',
          },
        ];
      }
      if (spec.$1.startsWith('match-empty')) community.savedItems = [];
      if (spec.$1.startsWith('chat-bubbles')) {
        community.stored.addAll({
          'one': {
            'id': 'one',
            'sender_id': 'rescuer',
            'body': 'Hola, gracias por interesarte en Luna.',
            'created_at': '2026-10-01T16:30:00Z',
          },
          'two': {
            'id': 'two',
            'sender_id': 'one',
            'body': 'Me gustaría conocerla este fin de semana.',
            'created_at': '2026-10-01T16:31:00Z',
          },
        });
      }
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
      if (spec.$1.startsWith('adoption-support')) {
        for (var i = 0; i < 2; i++) {
          await Scrollable.ensureVisible(
            tester.element(find.byTooltip('Pasar')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Pasar'));
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1.startsWith('adoption-support')) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'match-threads-large') {
        await tester.scrollUntilVisible(
          find.text('Perfecto. ¿Cuándo podrías visitarlo?'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('match-all')) {
        await tester.tap(find.text('Ver más'));
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'match-empty-large') {
        await tester.scrollUntilVisible(
          find.text('Explorar'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Explorar')),
          alignment: .35,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('case-detail-amount')) {
        await tester.tap(find.text('Donar'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('case-detail-expenses')) {
        final card = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Ocultar evidencia de Cirugía',
        );
        await tester.scrollUntilVisible(
          card,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(card), alignment: .1);
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'support-home-large') {
        await tester.scrollUntilVisible(
          find.text('Suscríbete ahora'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Suscríbete ahora')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('chat-bubbles')) {
        await tester.scrollUntilVisible(
          find.text('Hola, gracias por interesarte en Luna.'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Hola, gracias por interesarte en Luna.')),
          alignment: .15,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'adoption-end') {
        await tester.tap(find.byTooltip('Pasar'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('adoption-contact')) {
        await Scrollable.ensureVisible(
          tester.element(find.byTooltip('Contactar')),
          alignment: .25,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Contactar'));
        await tester.pumpAndSettle();
      }
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
    debugNetworkImageHttpClientProvider = null;
    debugDisableShadows = true;
  });
}
