// DDE1 frozen reference: dde1bb9d01e5f4c427424bffed99bf1c3ed1beca.
// Capture-only synthetic users/media. Actual app router and production widgets.
import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/navigation.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/profile/account_profile_avatar.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fake_identity_repository.dart';
import '../test/rescuer_home_screen_test.dart' show HomeRescue, homeFixture;
import '../test/rescuer_threads_test.dart'
    show InboxCommunity, inboxGroup, inboxThread;
import '../test/rescuer_profile_test.dart' show FakeRescuerProfile;
import '../test/profile_dde1_test.dart' show FakePhoneDde;
import '../test/payments_test.dart' show FakePayments;
import '../test/guardian_test.dart' show FakeGuardian;
import 'capture_design_test.dart' show saveCapture;
import 'fixture_photo_client.dart';

class ChromeCaptureInbox extends InboxCommunity {
  @override
  Future<String> photoUrl(String path) async =>
      'https://fixture.test/photo.jpg';
}

class ChromeCaptureProfile extends FakeRescuerProfile {
  ChromeCaptureProfile() {
    value = {...value, 'owner_id': 'one', 'status': 'draft'};
  }
  @override
  String? get userId => 'one';
}

void main() {
  testWidgets('capture actual DDE1 navigation home and active inbox selector', (
    tester,
  ) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final originalShadows = debugDisableShadows;
    final originalImages = debugNetworkImageHttpClientProvider;
    final semantics = tester.ensureSemantics();
    final cleanups = <Future<void> Function()>[];
    tester.view.devicePixelRatio = 1;
    final filter =
        Platform.environment['CAPTURE_FILTER'] ??
        const String.fromEnvironment('CAPTURE_FILTER');
    try {
      debugDisableShadows = false;
      for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
        final fonts = FontLoader(family)
          ..addFont(
            rootBundle.load(
              family == 'MaterialIcons'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$family.ttf',
            ),
          );
        await tester.runAsync(fonts.load);
      }
      final bytes = (await tester.runAsync(
        () => File('tool/fixtures/milo.png').readAsBytes(),
      ))!;
      debugNetworkImageHttpClientProvider = () => FixturePhotoClient(bytes);
      final output = Directory('../../.tools/dde1/chrome-captures');
      await tester.runAsync(() => output.create(recursive: true));
      for (final spec in [
        ('normal', const Size(377, 852), 1.0),
        ('text115', const Size(377, 852), 1.15),
        ('small200', const Size(320, 640), 2.0),
      ]) {
        for (final route in ['/profile', '/rescuer', '/messages']) {
          if (filter.isNotEmpty && !'${spec.$1}:$route'.contains(filter)) {
            continue;
          }
          tester.view.physicalSize = spec.$2;
          tester.platformDispatcher.textScaleFactorTestValue = spec.$3;
          final rescuer = route != '/profile';
          final identity = FakeIdentityRepository()
            ..user = const Identity(
              'one',
              'fixture@example.invalid',
              verified: true,
            )
            ..profile = Profile(
              id: 'one',
              name: 'Ana Garcia',
              phone: '+525500000001',
              city: 'Monterrey',
              mode: rescuer ? 'rescuer' : 'donor',
              intent: rescuer ? 'rescue' : 'adopt',
              status: 'active',
              termsVersion: currentTermsVersion,
              privacyVersion: currentPrivacyVersion,
              adultConfirmed: true,
            );
          await identity.setExperience(rescuer ? 'rescuer' : 'donor');
          final inbox = ChromeCaptureInbox()
            ..groups = [
              inboxGroup('one', [], name: 'Luna', count: 1)
                ..['selector_active'] = true
                ..['photo'] = 'synthetic/one/photo.jpg',
              inboxGroup('retired', [], name: 'Toby', count: 1)
                ..['selector_active'] = false
                ..['photo'] = 'synthetic/retired/photo.jpg',
            ]
            ..members = [
              inboxThread('ana', name: 'Luna', person: 'Ana')
                ..['photo'] = 'synthetic/one/photo.jpg',
            ]
            ..historical = [
              inboxGroup('retired', [], name: 'Toby', count: 1)
                ..['selector_active'] = false
                ..['photo'] = 'synthetic/retired/photo.jpg',
            ]
            ..oldMembers = [
              inboxThread(
                'old',
                closed: true,
                group: 'retired',
                name: 'Toby',
                person: 'Luis',
              ),
            ];
          final runtime = PhotoRuntime(
            store: MemoryPhotoStore(),
            actor: 'one',
            download: (_, cancel) async {
              cancel.check();
              return bytes;
            },
          );
          final photos = AccountPhotoRepository(
            owner: () => identity.current?.id,
            rpc: (_, _) async => {
              'photo_path': 'one/one/73000000-0000-4000-8000-000000000001.jpg',
            },
            upload: (_, _) async => throw StateError('Capture never uploads'),
            sign: (_) async => 'https://fixture.test/avatar.jpg',
          );
          final container = ProviderContainer(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              communityRepositoryProvider.overrideWithValue(inbox),
              rescueRepositoryProvider.overrideWithValue(
                HomeRescue()..home = homeFixture(verification: 'submitted'),
              ),
              rescuerProfileRepositoryProvider.overrideWithValue(
                ChromeCaptureProfile(),
              ),
              phoneVerificationRepositoryProvider.overrideWithValue(
                FakePhoneDde(),
              ),
              accountPhotoRepositoryProvider.overrideWithValue(photos),
              photoRuntimeProvider.overrideWithValue(runtime),
              paymentRepositoryProvider.overrideWithValue(FakePayments()),
              guardianRepositoryProvider.overrideWithValue(FakeGuardian()),
              routerInitialLocationProvider.overrideWithValue(route),
            ],
          );
          Future<void> cleanup() async {
            container.dispose();
            runtime.dispose();
            photos.dispose();
            await identity.changes.close();
          }

          cleanups.add(cleanup);
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: UncontrolledProviderScope(
                container: container,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: spec.$2,
                    textScaler: TextScaler.linear(spec.$3),
                  ),
                  child: const DopmiApp(),
                ),
              ),
            ),
          );
          Future<void> ready() async {
            for (var i = 0; i < 3; i++) {
              await tester.pump(const Duration(milliseconds: 100));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 40)),
              );
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          Future<void> capture(String suffix) async {
            await ready();
            await tester.runAsync(
              () => saveCapture(
                key,
                '${output.path}/${spec.$1}-${route.substring(1)}-$suffix.png',
              ),
            );
          }

          Future<void> reveal(Finder target) async {
            await tester.scrollUntilVisible(
              target,
              120,
              scrollable: find
                  .byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  )
                  .first,
            );
            await tester.ensureVisible(target);
            await ready();
          }

          await capture('top');
          final router = container.read(routerProvider);
          expect(router.state.uri.path, route);
          if (route == '/profile') {
            expect(find.byType(AccountProfileAvatar), findsOneWidget);
            expect(donorDestinations.map((d) => d.label), [
              'Adoptar',
              'Mis match',
              'Apoyar',
              'Perfil',
            ]);
            expect(
              find.descendant(
                of: find.byType(DopmiBottomBar),
                matching: find.byType(AccountProfileAvatar),
              ),
              findsNothing,
            );
          } else if (route == '/rescuer') {
            await reveal(find.byKey(const ValueKey('home-funnel-adoption')));
            expect(
              find.byKey(const ValueKey('home-funnel-adoption')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('home-funnel-support')),
              findsNothing,
            );
            await capture('adoption');
            final complete = find.byKey(
              const ValueKey('home-complete-profile'),
            );
            await reveal(complete);
            expect(complete.hitTestable(), findsOneWidget);
            await tester.tap(complete);
            await capture('editor');
            expect(router.state.uri.path, '/rescuer/profile/edit');
            expect(router.canPop(), isTrue);
            router.pop();
            await ready();
            await reveal(find.byKey(const ValueKey('home-funnel-adoption')));
            await capture('back');
            expect(router.state.uri.path, '/rescuer');
            expect(
              find.byKey(const ValueKey('home-funnel-adoption')),
              findsOneWidget,
            );
          } else {
            expect(
              find.byKey(const ValueKey('rescuer-pet-one')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('rescuer-pet-retired')),
              findsNothing,
            );
            expect(find.text('Todos'), findsOneWidget);
            expect(find.byType(Image), findsAtLeastNWidgets(1));
            expect(find.byTooltip('Cargar foto'), findsNothing);
            final history = find.text('Historial de mensajes');
            await reveal(history);
            await tester.tap(history);
            await capture('history');
            expect(
              find.byKey(const ValueKey('rescuer-pet-retired')),
              findsOneWidget,
            );
            await reveal(find.byKey(const ValueKey('rescuer-thread-old')));
            expect(
              find.byKey(const ValueKey('rescuer-thread-old')),
              findsOneWidget,
            );
            await capture('history-thread');
          }
          await tester.pumpWidget(const SizedBox());
          await cleanup();
          cleanups.remove(cleanup);
        }
      }
    } finally {
      debugDisableShadows = originalShadows;
      debugNetworkImageHttpClientProvider = originalImages;
      semantics.dispose();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      for (final cleanup in cleanups) {
        await cleanup();
      }
    }
  });
}
