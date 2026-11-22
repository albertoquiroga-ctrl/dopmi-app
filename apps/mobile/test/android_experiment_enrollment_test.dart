import 'dart:convert';

import 'package:dopmi_mobile/core/adoption_measurement_consent.dart';
import 'package:dopmi_mobile/core/android_experiment_enrollment.dart';
import 'package:dopmi_mobile/core/android_rescuer_acquisition.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/core/usage_analytics_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

const _alice = '79000000-0000-4000-8000-000000000001';
const _bob = '79000000-0000-4000-8000-000000000002';
const _token = '0123456789abcdef0123456789abcdef';
final _now = DateTime.utc(2026, 11, 21);
const _referrer =
    'utm_source=facebook&utm_medium=organic_comment'
    '&utm_campaign=dopmi_rescatistas_mty_p60_v1&utm_content=$_token';

Map<String, Object> _session(String owner) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.'
        '${encode({'sub': owner, 'exp': 1893456000})}.synthetic-signature',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'synthetic-refresh',
    'user': {
      'id': owner,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.test',
      'app_metadata': <String, Object>{},
      'user_metadata': <String, Object>{},
      'created_at': '2026-10-01T00:00:00Z',
    },
  };
}

class _Server {
  String owner = _alice;
  bool consent = true;
  int revision = 73;
  Object? responseOverride;
  bool overrideResponse = false;
  final claims = <http.Request>[];
  final legacy = <http.Request>[];
  final writes = <http.Request>[];

  String actor(http.Request request) {
    final token = request.headers['authorization']!.substring(7);
    return (jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(token.split('.')[1])),
          ),
        ) as Map<String, dynamic>)['sub']
        as String;
  }

  Map<String, Object?> state() => {
    'consent': consent,
    'revision': revision,
    'has_choice': true,
    'notice_version': usageAnalyticsNoticeVersion,
  };

  Future<http.Response> handle(http.Request request) async {
    Object? result;
    if (request.url.path.startsWith('/auth/')) {
      result = _session(owner);
    } else if (request.url.path.endsWith('dopmi_adoption_measurement_state')) {
      result = state();
    } else if (request.url.path.endsWith('dopmi_set_adoption_measurement_v2') ||
        request.url.path.endsWith('dopmi_choose_usage_analytics')) {
      writes.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final applied = body['expected_revision'] == revision;
      if (applied) {
        consent = body['consent'] as bool;
        revision++;
      }
      result = {'applied': applied, ...state()};
    } else if (request.url.path.endsWith(
      'dopmi_record_android_rescuer_acquisition',
    )) {
      legacy.add(request);
      result = null;
    } else {
      expect(
        request.url.path,
        '/rest/v1/rpc/dopmi_record_android_experiment_acquisition',
      );
      claims.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      result = overrideResponse
          ? responseOverride
          : {
              'status':
                  consent && body['p_expected_consent_revision'] == revision
                  ? 'recorded'
                  : 'consent_changed',
            };
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _Harness {
  _Harness._(this.store, this.server, this.client, this.acquisition);
  final SharedPreferences store;
  final _Server server;
  final SupabaseClient client;
  final AndroidRescuerAcquisition acquisition;
  late final MeasurementController measurement;
  late final AndroidExperimentEnrollment enrollment;

  static Future<_Harness> create({String referrer = _referrer}) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SharedPreferences.getInstance();
    final server = _Server();
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(server.handle),
    );
    final acquisition = AndroidRescuerAcquisition(
      store,
      'test',
      now: () => _now,
      readInstall: () async => (
        referrer: referrer,
        clickedAtSeconds:
            _now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/
            1000,
        installedAtSeconds: _now.millisecondsSinceEpoch ~/ 1000,
      ),
    );
    final harness = _Harness._(store, server, client, acquisition);
    final consent = AdoptionMeasurementConsent(client);
    harness.enrollment = AndroidExperimentEnrollment(
      client: client,
      acquisition: acquisition,
      measurement: () => harness.measurement,
    );
    harness.measurement = MeasurementController(
      store,
      'test',
      AnalyticsSpy(),
      DiagnosticsSpy(),
      analyticsChoices: consent,
      prepareAcquisition: harness.enrollment.record,
      prepareAdoptionConsent: (owner, enabled) {
        if (!enabled) harness.enrollment.revoke(owner);
        final localRevision = harness.measurement.analyticsRevision;
        final request = consent.prepare(
          owner,
          enabled,
          stillEligible: () =>
              harness.measurement.ownerId == owner &&
              harness.measurement.analyticsConsentCurrent &&
              harness.measurement.analyticsRevision == localRevision,
          restoreOnly: enabled,
          onAcceptedRevision: (serverRevision) {
            if (enabled) {
              harness.enrollment.consentAccepted(
                owner,
                localRevision: localRevision,
                serverRevision: serverRevision,
              );
            }
          },
          onRevoked: () => harness.measurement.observeAnalyticsRevoked(
            owner,
            expectedRevision: localRevision,
          ),
        );
        if (request == null) return null;
        return () async {
          if (await request() && enabled) {
            await harness.enrollment.record(owner);
          }
        };
      },
    );
    return harness;
  }

  Future<void> login(String owner) async {
    server.owner = owner;
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
    await measurement.owner(owner);
    await measurement.consentReady;
  }

  Future<void> dispose() async {
    measurement.dispose();
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'claim uses accepted SERVER revision, authenticated owner and no free arm',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      await h.login(_alice);
      expect(h.server.claims, hasLength(1));
      final claim = h.server.claims.single;
      expect(h.server.actor(claim), _alice);
      expect(jsonDecode(claim.body), {
        'p_placement_token': _token,
        'p_clicked_at': _now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'p_expected_consent_revision': 73,
      });
      expect(h.measurement.analyticsRevision, isNot(73));
      expect(h.server.legacy, isEmpty);
      expect(h.store.getBool('dopmi.test.play_acquisition_processed'), isTrue);
    },
  );

  test(
    'server OFF survives owner restoration without a claim or opt-in write',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.server.consent = false;
      await h.login(_alice);
      await h.measurement.prepareAttributableAction(_alice);
      expect(h.measurement.analyticsEnabled, isFalse);
      expect(h.server.claims, isEmpty);
      expect(h.server.writes, isEmpty);
      expect(
        h.store.getBool('dopmi.test.play_acquisition_processed'),
        isNot(isTrue),
      );
    },
  );

  test('consent_changed waits for a fresh accepted server revision, never retries stale', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    h.server.overrideResponse = true;
    h.server.responseOverride = {'status': 'consent_changed'};
    await h.login(_alice);
    expect(h.server.claims, hasLength(1));
    expect(
      h.store.getBool('dopmi.test.play_acquisition_processed'),
      isNot(isTrue),
    );
    await h.enrollment.record(_alice);
    expect(h.server.claims, hasLength(1));
    h.server.revision = 101;
    h.server.overrideResponse = false;
    await h.measurement.owner(_alice, refresh: true);
    await h.measurement.consentReady;
    expect(h.server.claims, hasLength(2));
    expect(
      jsonDecode(h.server.claims.last.body)['p_expected_consent_revision'],
      101,
    );
    expect(h.store.getBool('dopmi.test.play_acquisition_processed'), isTrue);
  });

  for (final status in [
    'already_recorded',
    'ineligible',
    'invalid_placement',
  ]) {
    test('$status is terminal and does not fall back to legacy RPC', () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.server.overrideResponse = true;
      h.server.responseOverride = {'status': status};
      await h.login(_alice);
      await h.enrollment.record(_alice);
      expect(h.server.claims, hasLength(1));
      expect(h.server.legacy, isEmpty);
      expect(h.store.getBool('dopmi.test.play_acquisition_processed'), isTrue);
    });
  }

  test('unrecognized response is uncertain, never silently accepted or sent as legacy', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    h.server.overrideResponse = true;
    h.server.responseOverride = {'status': 'unexpected'};
    await h.login(_alice);
    expect(h.server.claims, hasLength(1));
    expect(
      h.store.getBool('dopmi.test.play_acquisition_processed'),
      isNot(isTrue),
    );
    expect(h.store.getString('dopmi.test.play_acquisition_owner'), _alice);
    expect(h.server.legacy, isEmpty);
  });

  test('another account cannot inherit an uncertain placement owner', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    h.server.overrideResponse = true;
    h.server.responseOverride = {'status': 'consent_changed'};
    await h.login(_alice);
    h.server.overrideResponse = false;
    await h.login(_bob);
    expect(h.server.claims, hasLength(1));
    expect(h.store.getString('dopmi.test.play_acquisition_owner'), _alice);
  });

  test(
    'legacy enrollment remains on its original RPC with no new payload',
    () async {
      final h = await _Harness.create(
        referrer:
            'utm_source=facebook&utm_medium=organic_comment'
            '&utm_campaign=dopmi_rescatistas_mty_personal-a&utm_content=personal-a',
      );
      addTearDown(h.dispose);
      await h.login(_alice);
      expect(h.server.claims, isEmpty);
      expect(h.server.legacy, hasLength(1));
      expect(jsonDecode(h.server.legacy.single.body), {
        'p_variant': 'personal-a',
        'p_clicked_at': _now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      });
    },
  );
}
