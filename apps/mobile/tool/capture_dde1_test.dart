// Capture-only synthetic fixtures. No server requests, accounts or secrets.
import 'dart:io';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/catalog_screens.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/chat_photo_repository.dart';
import 'package:dopmi_mobile/features/communication/message_screens.dart';
import 'package:dopmi_mobile/features/communication/notification_activity_repository.dart';
import 'package:dopmi_mobile/features/communication/notification_activity_screen.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_screen.dart';
import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';
import '../test/fake_account_photo_repository.dart';
import '../test/rescue_test.dart' show FakeRescue;
import '../test/rescuer_profile_test.dart' show FakeRescuerProfile;
import '../test/chat_photo_dde1_test.dart' show FakeChatPhotos;
import 'capture_design_test.dart' show saveCapture;
import 'fixture_photo_client.dart';

const _owner = 'owner-one';
const _at = '2026-10-08T12:00:00Z';
const _captureFilter = String.fromEnvironment('CAPTURE_FILTER');

class DdeCaptureCommunity extends FakeCommunity {
  @override
  Future<String> photoUrl(String path) async =>
      'https://example.test/synthetic-photo';
  @override
  String? get userId => _owner;
  @override
  Future<Json?> publicProfile(String id) async => {
    'id': id,
    'name': 'Refugio Luna',
    'bio':
        'Rescatamos mascotas y las acompa\u00f1amos hasta encontrar un hogar.',
    'city': 'Monterrey',
    'region': 'Nuevo Le\u00f3n',
    'verified': true,
    'avatar_path': 'synthetic/avatar.jpg',
    'member_since': '2024-01-01T12:00:00Z',
    'public_email': 'contacto@example.test',
    'public_phone': '+525500000001',
    'public_address': 'Calle de ejemplo 100, Monterrey',
    'website_url': 'https://example.test',
    'instagram_url': 'https://instagram.com/example',
    'facebook_url': 'https://facebook.com/example',
    'adopted_count': 7,
    'metrics': {
      'active_adoptions': 2,
      'active_donation_cases': 1,
      'received_support_pets': 4,
    },
    'adoptions': [
      for (final name in ['Luna', 'Milo'])
        {
          ...post.data,
          'id': 'synthetic-$name',
          'pet_name': name,
          'species': 'dog',
          'sex': 'female',
          'size': 'small',
          'personality': ['affectionate'],
          'photos': ['synthetic/$name.jpg'],
          'status': 'published',
        },
    ],
    'cases': [
      {
        'id': 'synthetic-case',
        'status': 'approved',
        'public_data': {
          'pet_name': 'Luna',
          'photos': ['synthetic/case.jpg'],
        },
      },
    ],
  };
  @override
  Future<Json> thread(String id) async => {
    'id': id,
    'post_id': 'synthetic-Luna',
    'pet_name': 'Luna',
    'participant_name': 'Familia de ejemplo',
    'status': 'active',
  };
  @override
  Future<List<Json>> messages(String id, {Json? before}) async => before == null
      ? [
          {
            'id': 'message-a',
            'sender_id': 'other',
            'body': 'Hola, \u00bfpodemos conocer a Luna este fin de semana?',
            'created_at': _at,
          },
          {
            'id': 'message-b',
            'sender_id': _owner,
            'body': 'Claro. Te comparto una foto de su paseo de hoy.',
            'attachment_path': 'synthetic/thread/photo.jpg',
            'created_at': _at,
          },
        ]
      : [];
}

class DdeCaptureProfile extends FakeRescuerProfile {
  DdeCaptureProfile() {
    value = {
      ...value,
      'owner_id': _owner,
      'status': 'changes_requested',
      'display_name': 'Refugio Luna',
      'avatar_path': 'synthetic/avatar.jpg',
      'bio': 'Rescatamos mascotas y las acompa\u00f1amos hasta encontrar un hogar.',
      'public_email': '',
      'public_phone': '',
      'public_address': '',
      'website_url': '',
      'contact_consent': false,
      'field_feedback': {
        'bio': 'Describe c\u00f3mo acompa\u00f1as a las mascotas.',
      },
      'review_feedback':
          'Revisa la descripci\u00f3n de tu perfil p\u00fablico.',
    };
  }
}

class DdeCaptureRescue extends FakeRescue {
  @override
  Future<String> fileUrl(String path) async =>
      'https://example.test/synthetic-rescue-photo';
}

class DdeCapturePhone extends PhoneVerificationRepository {
  @override
  String? get verifiedPhone => null;
  @override
  Future<void> requestPhoneCode(String value) async {}
  @override
  Future<void> resendPhoneCode(String value) async {}
  @override
  Future<void> verifyPhoneCode(String value, String code) async {}
}

class DdeCapturePayments extends PaymentActivityRepository {
  DdeCapturePayments() : super(FakeRescue().client);
  @override
  Future<Json> page({required bool received, Json? cursor}) async => {
    'items': [
      {
        'id': 'cycle-example',
        'kind': 'guardian',
        'title': 'Suscripci\u00f3n Guardi\u00e1n',
        'created_at': _at,
        'amount_cents': received ? 811 : 1011,
        'assigned_cents': 811,
        'transferred_cents': 811,
        'reversed_cents': 0,
        'status': 'transferred',
        'allocation_count': 2,
      },
      {
        'id': 'support-example',
        'kind': 'contribution',
        'title': 'Consulta veterinaria de Luna',
        'created_at': _at,
        'amount_cents': 5075,
        'assigned_cents': 4800,
        'transferred_cents': 0,
        'reversed_cents': 0,
        'status': 'assigned',
        'photo': 'synthetic/case.jpg',
        'case_id': 'synthetic-case',
      },
      {
        'id': 'refund-example',
        'kind': 'contribution',
        'title': 'Medicamento de Milo',
        'created_at': _at,
        'amount_cents': 1050,
        'assigned_cents': 0,
        'transferred_cents': 0,
        'reversed_cents': 900,
        'refund_cents': 1050,
        'refunded_cents': 1050,
        'pending_refund_cents': 0,
        'status': 'refunded',
      },
    ],
    'next_cursor': null,
  };
  @override
  Future<Json> allocations(
    String cycle, {
    required bool received,
    String? afterExpense,
  }) async => {
    'items': [
      {
        'expense_id': 'synthetic-expense',
        'title': 'Consulta de Luna',
        'allocated_cents': 811,
        'reversed_cents': 0,
        'status': 'transferred',
      },
    ],
    'next_cursor': null,
  };
}

class DdeCaptureNotifications extends NotificationActivityRepository {
  DdeCaptureNotifications() : super(FakeRescue().client);
  final items = <Json>[
    {
      'id': 'n-a',
      'kind': 'guardian',
      'title': 'Tu pago Guardi\u00e1n fue confirmado',
      'body': 'Consulta el pago y las asignaciones en tu historial.',
      'tone': 'positive',
      'thumb_style': 'brand',
      'target_kind': 'history',
    },
    {
      'id': 'n-b',
      'kind': 'review',
      'title': 'Tu perfil p\u00fablico necesita atenci\u00f3n',
      'body': 'Describe c\u00f3mo acompa\u00f1as a las mascotas.',
      'tone': 'negative',
      'thumb_style': 'brand',
      'target_kind': 'profile',
    },
    {
      'id': 'n-c',
      'kind': 'contribution',
      'title': 'Recibiste una asignaci\u00f3n de +Apoyo',
      'body': 'Consulta el neto y su estado en tu historial.',
      'tone': 'pending',
      'thumb_style': 'photo',
      'photo_path': 'synthetic/case.jpg',
      'photo_purpose': 'rescue',
      'target_kind': 'received_history',
    },
    {
      'id': 'n-d',
      'kind': 'message',
      'title': 'Tienes un mensaje nuevo',
      'body': 'Hola, \u00bfpodemos conocer a Luna?',
      'thumb_style': 'photo',
      'photo_path': 'synthetic/Luna.jpg',
      'photo_purpose': 'adoption',
      'target_kind': 'thread',
      'target_id': 'synthetic-thread',
    },
  ];
  @override
  Future<DataPage<Json>> page(int page) async => DataPage([
    for (final item in items) {...item, 'created_at': _at, 'available': true},
  ], items.length);
  @override
  Future<Json> open(String id) async => {
    ...items.firstWhere((item) => item['id'] == id),
    'available': true,
    'read_at': _at,
  };
}

class DdeCaptureChatPhotos extends FakeChatPhotos {
  DdeCaptureChatPhotos() {
    userId = _owner;
  }
  @override
  Future<String> photoUrl(String path) async =>
      'https://example.test/private-photo';
}

void main() {
  testWidgets('capture DDE1 actual N03 to N08 routes with synthetic fixtures', (
    tester,
  ) async {
    // This tool is a Flutter test harness, outside the conventional test folder.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    final oldDebugShadows = debugDisableShadows;
    final oldImageClient = debugNetworkImageHttpClientProvider;
    final cleanups = <Future<void> Function()>[];
    try {
      debugDisableShadows = false;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
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
      final bytes = (await tester.runAsync(
        () => File('tool/fixtures/milo.png').readAsBytes(),
      ))!;
      debugNetworkImageHttpClientProvider = () => FixturePhotoClient(bytes);
      // Photo transport uses the same no-socket HTTP fixture as earlier captures.
      final output = Directory('../../.tools/dde1/visual-captures');
      await tester.runAsync(() => output.create(recursive: true));
      for (final spec in [
        ('normal', const Size(377, 852), 1.0),
        ('text115', const Size(377, 852), 1.15),
        ('small200', const Size(320, 640), 2.0),
      ]) {
        tester.view.physicalSize = spec.$2;
        for (final route in [
          '/rescuer/profile',
          '/rescuer/profile/edit',
          '/rescuers/public',
          '/payments',
          '/rescuer/received-payments',
          '/notifications',
          '/messages/synthetic-thread',
        ]) {
          final captureId = '${spec.$1}:$route';
          if (_captureFilter.isNotEmpty &&
              !captureId.contains(_captureFilter)) {
            continue;
          }
          debugPrint('DDE_CAPTURE $captureId');
          final identity = FakeIdentityRepository()
            ..user = const Identity(
              _owner,
              'private@example.test',
              verified: true,
            )
            ..profile = const Profile(
              id: _owner,
              name: 'Refugio Luna',
              phone: '+525500000099',
              city: 'Monterrey',
              mode: 'rescuer',
              intent: 'rescue',
              status: 'active',
              termsVersion: currentTermsVersion,
              privacyVersion: currentPrivacyVersion,
              adultConfirmed: true,
            );
          final profile = DdeCaptureProfile();
          final router = GoRouter(
            initialLocation: route,
            routes: [
              GoRoute(
                path: '/rescuer/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
              GoRoute(
                path: '/rescuer/profile/edit',
                builder: (_, _) => const RescuerPublicProfileEditScreen(),
              ),
              GoRoute(
                path: '/rescuers/:id',
                builder: (_, state) =>
                    PublicProfileScreen(state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/payments',
                builder: (_, _) => const PaymentActivityScreen(),
              ),
              GoRoute(
                path: '/rescuer/received-payments',
                builder: (_, _) => const PaymentActivityScreen(received: true),
              ),
              GoRoute(
                path: '/notifications',
                builder: (_, _) => const NotificationActivityScreen(),
              ),
              GoRoute(
                path: '/messages/:id',
                builder: (_, state) =>
                    ThreadScreen(state.pathParameters['id']!),
              ),
            ],
          );
          final container = ProviderContainer(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              accountPhotoRepositoryProvider.overrideWithValue(
                emptyAccountPhotoRepository(identity),
              ),
              communityRepositoryProvider.overrideWithValue(
                DdeCaptureCommunity(),
              ),
              rescuerProfileRepositoryProvider.overrideWithValue(profile),
              rescueRepositoryProvider.overrideWithValue(DdeCaptureRescue()),
              phoneVerificationRepositoryProvider.overrideWithValue(
                DdeCapturePhone(),
              ),
              paymentActivityRepositoryProvider.overrideWithValue(
                DdeCapturePayments(),
              ),
              notificationActivityRepositoryProvider.overrideWithValue(
                DdeCaptureNotifications(),
              ),
              chatPhotoRepositoryProvider.overrideWithValue(
                DdeCaptureChatPhotos(),
              ),
              photoRuntimeProvider.overrideWith((ref) {
                final runtime = PhotoRuntime(
                  store: MemoryPhotoStore(),
                  actor: _owner,
                  download: (url, cancellation) async {
                    cancellation.check();
                    final request = await FixturePhotoClient(bytes).getUrl(url);
                    final response = await request.close();
                    final result = BytesBuilder();
                    await for (final chunk in response) {
                      result.add(chunk);
                    }
                    return result.takeBytes();
                  },
                );
                ref.onDispose(runtime.dispose);
                return runtime;
              }),
            ],
          );
          Future<void> cleanup() async {
            container.dispose();
            router.dispose();
            await identity.changes.close();
          }

          cleanups.add(cleanup);
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: dopmiTheme(rescuer: true),
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(spec.$3)),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
          Future<void> ready() async {
            for (var phase = 0; phase < 3; phase++) {
              await tester.pump(const Duration(milliseconds: 300));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 50)),
              );
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          final name = route.replaceAll('/', '-').substring(1);
          Future<void> capture(String suffix) async {
            await ready();
            await tester.runAsync(
              () => saveCapture(
                key,
                '${output.path}/${spec.$1}-$name-$suffix.png',
              ),
            );
          }

          Future<void> reveal(
            Finder target, {
            double delta = 200,
            bool first = false,
          }) async {
            await ready();
            // Lazy images can be evicted between dragUntilVisible's final
            // drag and its implicit ensureVisible. Resolve the live descendant
            // after layout, then reveal all ancestor axes explicitly below.
            for (
              var attempt = 0;
              target.evaluate().isEmpty && attempt < 50;
              attempt++
            ) {
              await tester.drag(
                find.byType(Scrollable).first,
                Offset(0, -delta),
              );
              await ready();
            }
            expect(
              target.evaluate(),
              isNotEmpty,
              reason: '$captureId target must exist after bounded scrolling',
            );
            // The public body is one lazy list child. Its descendants can exist
            // before they enter the viewport; images and text also change extent.
            await ready();
            if (first) target = target.first;
            final targetContext = tester.element(target);
            final scroll = Scrollable.of(targetContext);
            // Reveal every ancestor axis: large-text tabs also scroll horizontally.
            await Scrollable.ensureVisible(targetContext, alignment: .5);
            await tester.pumpAndSettle();
            final bounds = tester.getRect(target);
            final diagnostics =
                '$captureId target=$target bounds=$bounds viewport=${spec.$2} '
                'offset=${scroll.position.pixels} min=${scroll.position.minScrollExtent} '
                'max=${scroll.position.maxScrollExtent} viewportExtent=${scroll.position.viewportDimension}';
            debugPrint('DDE_REVEAL $diagnostics');
            expect(target.hitTestable(), findsOneWidget, reason: diagnostics);
          }

          await ready();
          await capture('top');
          if ((route == '/payments' || route == '/rescuer/received-payments') &&
              find.byType(Image).evaluate().isEmpty) {
            await reveal(find.byType(Image), first: true);
            await capture('photo-visible');
          }
          if (route == '/payments' ||
              route == '/rescuer/received-payments' ||
              route == '/notifications' ||
              route.startsWith('/messages/')) {
            expect(
              find.byType(Image),
              findsAtLeastNWidgets(route == '/notifications' ? 2 : 1),
              reason: '$captureId must show decoded fixture photographs',
            );
            expect(find.byTooltip('Reintentar foto'), findsNothing);
          }
          if (route == '/rescuer/profile/edit') {
            final editPhoto = find.byKey(
              const ValueKey('public-profile-edit-photo'),
            );
            await reveal(editPhoto);
            expect(editPhoto.hitTestable(), findsOneWidget);
            await capture('photo-edit');
            final phone = find.byKey(
              const ValueKey('public-profile-Tel\u00e9fono p\u00fablico'),
            );
            await reveal(phone);
            expect(tester.widget<TextField>(phone).controller!.text, isEmpty);
            final consent = find.byType(CheckboxListTile);
            await reveal(consent);
            expect(tester.widget<CheckboxListTile>(consent).value, isFalse);
            await capture('contacts-off');
            await tester.tap(consent);
            await capture('contacts-consent');
            expect(profile.saves, 0);
          }
          if (route == '/rescuers/public') {
            for (final tab in ['Adopci\u00f3n', 'Apoyo', 'Resumen']) {
              await reveal(find.text(tab));
              await tester.tap(find.text(tab));
              await ready();
              await capture(
                tab == 'Adopci\u00f3n'
                    ? 'adoption'
                    : tab == 'Apoyo'
                    ? 'support'
                    : 'summary',
              );
              if (tab == 'Adopci\u00f3n') {
                await reveal(find.text('Filtros'));
                await tester.tap(find.text('Filtros'));
                await capture('filters');
                router.pop();
                await ready();
              }
            }
          }
          if (route == '/payments') {
            await reveal(
              find.textContaining('Suscripci\u00f3n Guardi\u00e1n'),
              first: true,
              delta: -200,
            );
            await tester.tap(
              find.textContaining('Suscripci\u00f3n Guardi\u00e1n').first,
            );
            await capture('allocation-detail');
          }
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            for (var step = 0; step < 6; step++) {
              await tester.drag(scrollables.first, const Offset(0, -350));
              await tester.pump();
            }
            await capture('bottom');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          cleanups.remove(cleanup);
          await cleanup();
        }
      }
    } finally {
      debugDisableShadows = oldDebugShadows;
      debugNetworkImageHttpClientProvider = oldImageClient;
      await tester.pumpWidget(const SizedBox.shrink());
      for (final cleanup in cleanups.reversed) {
        await cleanup();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
