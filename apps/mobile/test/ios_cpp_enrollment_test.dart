import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/adoption_measurement_consent.dart';
import 'package:dopmi_mobile/core/ios_cpp_acquisition.dart';
import 'package:dopmi_mobile/core/ios_cpp_enrollment.dart';
import 'package:dopmi_mobile/core/ios_cpp_link_capture.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

const _alice = '79000000-0000-4000-8000-000000000001';
const _bob = '79000000-0000-4000-8000-000000000002';
final _personalA = Uri.parse('io.dopmi.app://acquire/personal-a');

Map<String, Object> _session(String owner, String generation, int expiresAt) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.'
        '${encode({'sub': owner, 'exp': expiresAt, 'generation': generation})}'
        '.synthetic-signature',
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
  String loginOwner = _alice;
  String generation = 'initial';
  int expiresAt = 1893456000;
  final states = <String, ({bool consent, int revision})>{};
  final reads = <http.Request>[];
  final writes = <http.Request>[];
  final claims = <http.Request>[];
  final auth = <http.Request>[];
  final recordedOwners = <String>{};
  Future<Object> Function(http.Request)? writeOverride;
  Future<Object> Function(http.Request)? claimOverride;

  Map<String, dynamic> identity(http.Request request) {
    final token = request.headers['authorization']!.substring(7);
    return jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
    ) as Map<String, dynamic>;
  }

  String actor(http.Request request) => identity(request)['sub'] as String;

  Map<String, Object> state(String owner) {
    final saved = states[owner] ?? (consent: false, revision: 0);
    return {'consent': saved.consent, 'revision': saved.revision};
  }

  Map<String, Object> applyConsent(http.Request request) {
    final owner = actor(request);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final saved = states[owner] ?? (consent: false, revision: 0);
    final applied = saved.revision == body['expected_revision'];
    if (applied) {
      states[owner] = (
        consent: body['consent'] as bool,
        revision: saved.revision + 1,
      );
    }
    return {'applied': applied, ...state(owner)};
  }

  Map<String, String> applyClaim(http.Request request) {
    final owner = actor(request);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final saved = states[owner] ?? (consent: false, revision: 0);
    if (!saved.consent ||
        saved.revision != body['p_expected_consent_revision']) {
      return {'status': 'consent_changed'};
    }
    return {
      'status': recordedOwners.add(owner) ? 'recorded' : 'already_recorded',
    };
  }

  Future<http.Response> handle(http.Request request) async {
    Object result;
    if (request.url.path.startsWith('/auth/')) {
      auth.add(request);
      result = _session(loginOwner, generation, expiresAt);
    } else if (request.url.path.endsWith('dopmi_adoption_measurement_state')) {
      reads.add(request);
      result = state(actor(request));
    } else if (request.url.path.endsWith('dopmi_set_adoption_measurement_v2')) {
      writes.add(request);
      result = writeOverride == null
          ? applyConsent(request)
          : await writeOverride!(request);
    } else {
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/dopmi_record_ios_cpp_acquisition');
      claims.add(request);
      result = claimOverride == null
          ? applyClaim(request)
          : await claimOverride!(request);
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
  _Harness._(this.server, this.client, this.acquisition, this.links);

  final _Server server;
  final SupabaseClient client;
  final IosCppAcquisition acquisition;
  final StreamController<Uri> links;
  late final MeasurementController measurement;
  late final IosCppEnrollment enrollment;
  late final IosCppLinkCapture capture;

  static Future<_Harness> create({
    Future<Uri?> Function()? readInitial,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final server = _Server();
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(server.handle),
    );
    final acquisition = IosCppAcquisition(
      preferences,
      'test',
      supported: true,
      now: () => DateTime.utc(2026, 11, 20, 23),
    );
    final harness = _Harness._(
      server,
      client,
      acquisition,
      StreamController<Uri>.broadcast(sync: true),
    );
    final consent = AdoptionMeasurementConsent(client);
    harness.enrollment = IosCppEnrollment(
      client: client,
      acquisition: acquisition,
      measurement: () => harness.measurement,
      captureReady: () => harness.capture.ready,
      timeout: timeout,
    );
    harness.measurement = MeasurementController(
      preferences,
      'test',
      AnalyticsSpy(),
      DiagnosticsSpy(),
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
          onAcceptedRevision: (serverRevision) {
            if (enabled) {
              harness.enrollment.consentAccepted(
                owner,
                localRevision: localRevision,
                serverRevision: serverRevision,
              );
            }
          },
        );
        if (request == null) return null;
        return () async {
          if (await request() && enabled) {
            await harness.enrollment.record(owner);
          }
        };
      },
    );
    harness.capture = IosCppLinkCapture(
      events: harness.links.stream,
      readInitial: readInitial ?? () async => null,
      acquisition: Future.value(acquisition),
      onCaptured: () {
        final owner = harness.measurement.ownerId;
        if (owner != null && harness.measurement.analyticsConsentCurrent) {
          unawaited(harness.measurement.prepareAttributableAction(owner));
        }
      },
    )..start();
    return harness;
  }

  Future<void> login(String owner) async {
    await rawLogin(owner);
    unawaited(acquisition.observeOwner(owner));
    await measurement.owner(owner);
  }

  Future<void> rawLogin(String owner) async {
    server.loginOwner = owner;
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
  }

  Future<void> optIn() async {
    await measurement.setAnalytics(true);
    await measurement.consentReady;
  }

  Future<void> drain(String owner) async {
    await capture.ready;
    await measurement.prepareAttributableAction(owner);
  }

  Future<void> dispose() async {
    await capture.dispose();
    await links.close();
    measurement.dispose();
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a warm CPP link uses the accepted CAS revision and refreshed actor token',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      harness.server.states[_alice] = (consent: false, revision: 14);
      await harness.login(_alice);
      await harness.optIn();
      expect(harness.server.claims, isEmpty);

      harness.server.expiresAt = 1;
      harness.server.generation = 'expired';
      await harness.rawLogin(_alice);
      harness.server.expiresAt = 1893456000;
      harness.server.generation = 'refreshed';
      harness.links.add(_personalA);
      await harness.drain(_alice);
      await harness.drain(_alice);

      expect(harness.server.claims, hasLength(1));
      final claim = harness.server.claims.single;
      expect(jsonDecode(claim.body), {
        'p_variant': 'personal-a',
        'p_expected_consent_revision': 15,
      });
      expect(harness.server.actor(claim), _alice);
      expect(harness.server.identity(claim)['generation'], 'refreshed');
      expect(
        harness.server.auth.last.url.queryParameters['grant_type'],
        'refresh_token',
      );
      expect(harness.server.recordedOwners, {_alice});
    },
  );

  test(
    'a cold initial CPP is awaited across login and consent before enrollment',
    () async {
      final initial = Completer<Uri?>();
      final harness = await _Harness.create(readInitial: () => initial.future);
      addTearDown(harness.dispose);
      final consentAccepted = Completer<void>();
      harness.server.writeOverride = (request) async {
        final response = harness.server.applyConsent(request);
        consentAccepted.complete();
        return response;
      };
      await harness.login(_alice);
      final optIn = harness.optIn();
      await consentAccepted.future;
      expect(harness.server.claims, isEmpty);

      initial.complete(_personalA);
      await optIn;
      await harness.drain(_alice);

      expect(harness.server.claims, hasLength(1));
      expect(jsonDecode(harness.server.claims.single.body), {
        'p_variant': 'personal-a',
        'p_expected_consent_revision': 1,
      });
      expect(harness.server.recordedOwners, {_alice});
    },
  );

  test(
    'a consent conflict cannot become enrollment using a read revision',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      harness.server.writeOverride = (_) async => {
        'applied': false,
        'consent': true,
        'revision': 45,
      };
      await harness.login(_alice);
      await harness.optIn();
      harness.links.add(_personalA);
      await harness.drain(_alice);

      expect(harness.measurement.analyticsConsentCurrent, isTrue);
      expect(harness.server.writes, hasLength(1));
      expect(harness.server.claims, isEmpty);
    },
  );

  test('OFF consumes an unclaimed source before a later opt-in', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    harness.links.add(_personalA);
    await harness.capture.ready;
    await harness.login(_alice);

    await harness.measurement.setAnalytics(false);
    await harness.measurement.consentReady;
    await harness.optIn();
    await harness.drain(_alice);

    expect(harness.server.claims, isEmpty);
    expect(harness.server.state(_alice), {'consent': true, 'revision': 2});
  });

  test(
    'OFF and switching accounts cannot transfer an in-flight claim to Bob',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      final started = Completer<void>();
      final release = Completer<void>();
      harness.server.claimOverride = (request) async {
        started.complete();
        await release.future;
        return {'status': 'recorded'};
      };
      harness.links.add(_personalA);
      await harness.capture.ready;
      await harness.login(_alice);
      final aliceOptIn = harness.optIn();
      await started.future;

      try {
        await harness.measurement.setAnalytics(false);
        await harness.measurement.consentReady;
        await harness.login(_bob);
        final bobOptIn = harness.optIn();
        release.complete();
        await Future.wait([aliceOptIn, bobOptIn]);
        await harness.drain(_bob);
        expect(harness.server.claims, hasLength(1));
        expect(harness.server.actor(harness.server.claims.single), _alice);
        expect(harness.server.writes.map(harness.server.actor), [
          _alice,
          _alice,
          _bob,
        ]);
        expect(harness.server.state(_alice), {'consent': false, 'revision': 2});
      } finally {
        if (!release.isCompleted) release.complete();
        await aliceOptIn;
      }
    },
  );

  test('a lost response retries the same owner until already_recorded is confirmed', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    var loseResponse = true;
    harness.server.claimOverride = (request) async {
      final response = harness.server.applyClaim(request);
      if (loseResponse) {
        loseResponse = false;
        throw http.ClientException('synthetic response loss');
      }
      return response;
    };
    harness.links.add(_personalA);
    await harness.capture.ready;
    await harness.login(_alice);
    await harness.optIn();
    expect(harness.server.claims, hasLength(1));
    await harness.drain(_alice);
    await harness.drain(_alice);

    expect(harness.server.claims, hasLength(2));
    expect(harness.server.claims.map(harness.server.actor), [_alice, _alice]);
    expect(harness.server.claims.map((request) => jsonDecode(request.body)), [
      {'p_variant': 'personal-a', 'p_expected_consent_revision': 1},
      {'p_variant': 'personal-a', 'p_expected_consent_revision': 1},
    ]);
    expect(harness.server.recordedOwners, {_alice});
  });

  for (final malformed in <Object>[
    {'status': 'unknown'},
    {'status': 1},
    ['recorded'],
  ]) {
    test(
      'an invalid response retains the same owner for retry: $malformed',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.dispose);
        harness.server.claimOverride = (_) async => malformed;
        harness.links.add(_personalA);
        await harness.capture.ready;
        await harness.login(_alice);
        await harness.optIn();
        expect(harness.server.claims, hasLength(1));

        harness.server.claimOverride = null;
        await harness.drain(_alice);
        await harness.drain(_alice);
        expect(harness.server.claims, hasLength(2));
        expect(harness.server.actor(harness.server.claims.last), _alice);
        expect(harness.server.recordedOwners, {_alice});
      },
    );
  }

  test(
    'consent_changed retries only with a later accepted CAS revision',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      harness.server.states[_alice] = (consent: false, revision: 7);
      harness.server.writeOverride = (request) async {
        final accepted = harness.server.applyConsent(request);
        harness.server.states[_alice] = (consent: true, revision: 9);
        return accepted;
      };
      harness.links.add(_personalA);
      await harness.capture.ready;
      await harness.login(_alice);
      await harness.optIn();
      expect(harness.server.claims, hasLength(1));
      expect(harness.server.recordedOwners, isEmpty);

      harness.server.writeOverride = null;
      await harness.optIn();
      await harness.drain(_alice);

      expect(harness.server.claims.map((request) => jsonDecode(request.body)), [
        {'p_variant': 'personal-a', 'p_expected_consent_revision': 8},
        {'p_variant': 'personal-a', 'p_expected_consent_revision': 10},
      ]);
      expect(harness.server.recordedOwners, {_alice});
    },
  );

  test(
    'ineligible is terminal without recording or retrying a source',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      harness.server.claimOverride = (_) async => {'status': 'ineligible'};
      harness.links.add(_personalA);
      await harness.capture.ready;
      await harness.login(_alice);
      await harness.optIn();
      await harness.drain(_alice);
      await harness.drain(_alice);

      expect(harness.server.claims, hasLength(1));
      expect(harness.server.recordedOwners, isEmpty);
    },
  );

  test(
    'a timed out RPC leaves a pending claim rather than claiming success',
    () async {
      final harness = await _Harness.create(
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(harness.dispose);
      final release = Completer<void>();
      harness.server.claimOverride = (_) async {
        await release.future;
        return {'status': 'recorded'};
      };
      harness.links.add(_personalA);
      await harness.capture.ready;
      await harness.login(_alice);
      try {
        await harness.optIn();
        expect(harness.server.claims, hasLength(1));
        release.complete();
        await Future<void>.delayed(Duration.zero);
        harness.server.claimOverride = null;
        await harness.drain(_alice);
        expect(harness.server.claims, hasLength(2));
        expect(harness.server.recordedOwners, {_alice});
      } finally {
        if (!release.isCompleted) release.complete();
      }
    },
  );
}
