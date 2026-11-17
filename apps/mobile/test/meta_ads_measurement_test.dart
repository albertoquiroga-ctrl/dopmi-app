import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/meta_ads_measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/chat_photo_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/account_privacy_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_identity_repository.dart';

const _channel = MethodChannel('io.dopmi.app/meta_ads_measurement');
const _actor = '00000000-0000-4000-8000-000000000001';
const _other = '00000000-0000-4000-8000-000000000002';
const _eligibility = 'dopmi_meta_ads_action_eligible';
const _context = {
  'advertising_id': '00000000-0000-4000-8000-000000000003',
  'os_version': '16',
  'app_version': '2.3.5',
  'app_build': 399,
};

Map<String, Object> _session(String owner, {String? token}) => {
  'access_token': token ?? 'token-$owner',
  'refresh_token': 'refresh-$owner',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'aud': 'authenticated',
    'created_at': '2026-10-08T00:00:00Z',
    'app_metadata': {},
    'user_metadata': {},
  },
};

Future<void> _restore(SupabaseClient client, String owner) async =>
    await client.auth.recoverSession(jsonEncode(_session(owner)));

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  void native(Future<Object?> Function(MethodCall) callback) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, callback);
  }

  late SupabaseClient client;
  late MetaAdsMeasurement measurement;
  late List<http.Request> requests;
  late bool consent;
  late bool failMeasured;
  late bool missingPreference;
  late bool eligibleTarget;
  Completer<void>? settingStarted;
  Completer<void>? settingAllowed;
  Completer<void>? refreshStarted;
  Completer<void>? refreshAllowed;

  setUp(() async {
    requests = [];
    consent = false;
    failMeasured = false;
    missingPreference = false;
    eligibleTarget = true;
    settingStarted = null;
    settingAllowed = null;
    refreshStarted = null;
    refreshAllowed = null;
    client = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final name = request.url.pathSegments.last;
        if (name == 'token') {
          refreshStarted?.complete();
          await refreshAllowed?.future;
          return http.Response(
            jsonEncode(_session(_actor)),
            200,
            request: request,
          );
        }
        if (name == 'dopmi_set_meta_ads_preference') {
          settingStarted?.complete();
          await settingAllowed?.future;
          consent = (jsonDecode(request.body) as Map)['enabled'] == true;
        }
        if ((failMeasured && name == 'dopmi_send_message_meta') ||
            (missingPreference && name == 'dopmi_meta_ads_preference')) {
          return http.Response(
            '{"code":"PGRST202","message":"function not found"}',
            404,
            request: request,
          );
        }
        final payload = name == _eligibility
            ? consent && eligibleTarget
            : name.contains('preference')
            ? consent
            : {'id': 'ok'};
        return http.Response(jsonEncode(payload), 200, request: request);
      }),
    );
    await _restore(client, _actor);
    measurement = MetaAdsMeasurement(client);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    await client.dispose();
  });

  List<String> routes() =>
      requests.map((request) => request.url.pathSegments.last).toList();

  test('disabled by default and unavailable outside Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final disabled = ProviderContainer();
    addTearDown(disabled.dispose);
    expect(disabled.read(metaAdsMeasurementProvider), isNull);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          const AppConfig(
            url: '',
            key: '',
            redirect: '',
            metaAdsMeasurementEnabled: true,
          ),
        ),
      ],
    );
    addTearDown(ios.dispose);
    expect(ios.read(metaAdsMeasurementProvider), isNull);
    expect(requests, isEmpty);
  });

  test(
    'declining preference keeps legacy route and never reads AAID',
    () async {
      native((_) async => fail('native call without permission'));
      await SupabaseCommunityRepository(
        client,
        metaAds: measurement,
      ).sendMessage('thread', 'msg', 'body');
      expect(routes(), [_eligibility, 'dopmi_send_message']);
      expect(jsonDecode(requests.last.body), {
        'thread_id': 'thread',
        'message_id': 'msg',
        'message_body': 'body',
      });
    },
  );

  test('granted but ineligible actions do not read AAID', () async {
    consent = true;
    eligibleTarget = false;
    native((_) async => fail('native call for an ineligible action'));
    await SupabaseCommunityRepository(
      client,
      metaAds: measurement,
    ).sendMessage('thread', 'msg', 'body');
    expect(routes(), [_eligibility, 'dopmi_send_message']);
  });

  test('a measured operation without a session makes no RPC', () async {
    final guest = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async => fail('guest product request')),
    );
    addTearDown(guest.dispose);
    native((_) async => fail('guest AAID request'));
    await expectLater(
      SupabaseCommunityRepository(
        guest,
        metaAds: MetaAdsMeasurement(guest),
      ).sendMessage('thread', 'msg', 'body'),
      throwsStateError,
    );
  });

  test('older backends do not report a prior grant', () async {
    missingPreference = true;
    expect(await measurement.preference(_actor), isFalse);
    expect(routes(), ['dopmi_meta_ads_preference']);
  });

  test(
    'a skipped revocation reports failure rather than false success',
    () async {
      settingStarted = Completer<void>();
      settingAllowed = Completer<void>();
      final pending = measurement.setPreference(_actor, false);
      await settingStarted!.future;
      await expectLater(
        measurement.setPreference(_actor, false),
        throwsStateError,
      );
      await expectLater(
        measurement.setPreference(_other, false),
        throwsStateError,
      );
      settingAllowed!.complete();
      expect(await pending, isFalse);
      expect(routes(), ['dopmi_set_meta_ads_preference']);
    },
  );

  testWidgets(
    'without capture the privacy control only permits revocation',
    (tester) async {
      consent = true;
      var nativeRequests = 0;
      native((_) async {
        nativeRequests++;
        return null;
      });
      final identity = FakeIdentityRepository()
        ..user = const Identity(_actor, 'fixture@example.test', verified: true);
      addTearDown(identity.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configProvider.overrideWithValue(
              AppConfig(
                url: '',
                key: '',
                redirect: '',
                metaAdsMeasurementEnabled:
                    defaultTargetPlatform == TargetPlatform.iOS,
              ),
            ),
            identityRepositoryProvider.overrideWithValue(identity),
            metaAdsPreferenceServiceProvider.overrideWithValue(measurement),
          ],
          child: const MaterialApp(home: AccountPrivacyScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final control = find.widgetWithText(
        SwitchListTile,
        'Medición de anuncios con Meta',
      );
      expect(tester.widget<SwitchListTile>(control).value, isTrue);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(consent, isFalse);
      expect(control, findsNothing);
      expect(nativeRequests, 0);
      expect(
        routes().where((rpc) => rpc == 'dopmi_set_meta_ads_preference'),
        hasLength(1),
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  test(
    'explicit grant routes text, photo and submit with exact context',
    () async {
      expect(await measurement.setPreference(_actor, true), isTrue);
      native((call) async {
        expect(call.method, 'getAdvertisingContext');
        return {..._context, 'unapproved': 'must not be forwarded'};
      });
      final community = SupabaseCommunityRepository(
        client,
        metaAds: measurement,
      );
      final photos = SupabaseChatPhotoRepository(client, metaAds: measurement);
      final post = Adoption({'id': 'post', 'version': 3});
      await community.sendMessage('thread', 'msg1', 'text');
      await photos.send('thread', 'msg2', '', 'attachment');
      await community.transition(post, 'submit');
      await community.transition(post, 'archive');

      expect(routes(), [
        'dopmi_set_meta_ads_preference',
        _eligibility,
        'dopmi_send_message_meta',
        _eligibility,
        'dopmi_send_message_meta',
        _eligibility,
        'dopmi_transition_adoption_meta',
        'dopmi_transition_adoption',
      ]);
      final textArgs = jsonDecode(requests[2].body) as Map;
      final photoArgs = jsonDecode(requests[4].body) as Map;
      final submissionArgs = jsonDecode(requests[6].body) as Map;
      expect(jsonDecode(requests[1].body), {
        'p_event_kind': 'first_adoption_message',
        'p_target_id': 'thread',
      });
      expect(jsonDecode(requests[5].body), {
        'p_event_kind': 'first_adoption_submission',
        'p_target_id': 'post',
      });
      expect(textArgs['attachment_path'], isNull);
      expect(photoArgs['attachment_path'], 'attachment');
      expect(submissionArgs['action'], 'submit');
      for (final args in [textArgs, photoArgs, submissionArgs]) {
        expect(args['advertising_context'], _context);
      }
    },
  );

  test('missing or deleted AAID does not use measured endpoints', () async {
    consent = true;
    native(
      (_) async => {
        ..._context,
        'advertising_id': '00000000-0000-0000-0000-000000000000',
      },
    );
    await SupabaseCommunityRepository(
      client,
      metaAds: measurement,
    ).sendMessage('thread', 'msg', 'body');
    expect(routes(), [_eligibility, 'dopmi_send_message']);
  });

  test('missing wrapper falls back once without context', () async {
    consent = true;
    failMeasured = true;
    native((_) async => _context);
    await SupabaseCommunityRepository(
      client,
      metaAds: measurement,
    ).sendMessage('thread', 'msg', 'body');
    expect(routes(), [
      _eligibility,
      'dopmi_send_message_meta',
      'dopmi_send_message',
    ]);
    expect(
      (jsonDecode(requests.last.body) as Map).keys,
      unorderedEquals(['thread_id', 'message_id', 'message_body']),
    );
    expect(requests.last.headers['authorization'], 'Bearer token-$_actor');
  });

  test('withdrawing consent during device lookup drops context', () async {
    consent = true;
    final requested = Completer<void>();
    final result = Completer<Object?>();
    native((_) {
      requested.complete();
      return result.future;
    });
    final pending = SupabaseCommunityRepository(
      client,
      metaAds: measurement,
    ).sendMessage('thread', 'msg', 'body');
    await requested.future;
    expect(await measurement.setPreference(_actor, false), isFalse);
    result.complete(_context);
    await pending;
    expect(routes(), [
      _eligibility,
      'dopmi_set_meta_ads_preference',
      'dopmi_send_message',
    ]);
  });

  test(
    'expired session refresh cannot send using a different account',
    () async {
      final expired = base64Url
          .encode(utf8.encode('{"exp":1}'))
          .replaceAll('=', '');
      await client.auth.setInitialSession(
        jsonEncode(_session(_actor, token: 'e30.$expired.fixture')),
      );
      expect(client.auth.currentSession?.isExpired, isTrue);
      refreshStarted = Completer<void>();
      refreshAllowed = Completer<void>();
      native((_) async => fail('must not read AAID from an expired session'));
      final pending = SupabaseCommunityRepository(
        client,
        metaAds: measurement,
      ).sendMessage('thread', 'msg', 'body');
      final rejected = expectLater(pending, throwsStateError);
      await refreshStarted!.future;
      await _restore(client, _other);
      refreshAllowed!.complete();
      await rejected;
      expect(routes(), ['token']);
    },
  );

  test(
    'switching accounts during device lookup discards the operation',
    () async {
      consent = true;
      final requested = Completer<void>();
      final result = Completer<Object?>();
      native((_) {
        requested.complete();
        return result.future;
      });
      final pending = SupabaseCommunityRepository(
        client,
        metaAds: measurement,
      ).sendMessage('thread', 'msg', 'body');
      final rejected = expectLater(pending, throwsStateError);
      await requested.future;
      await _restore(client, _other);
      result.complete(_context);
      await rejected;
      expect(routes(), [_eligibility]);
    },
  );
}
