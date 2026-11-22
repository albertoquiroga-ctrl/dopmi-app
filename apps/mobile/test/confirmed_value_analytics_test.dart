import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/confirmed_value_analytics.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/chat_photo_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

const _actor = '79000000-0000-4000-8000-000000000001';
const _other = '79000000-0000-4000-8000-000000000005';
const _post = '79000000-0000-4000-8000-000000000002';
const _thread = '79000000-0000-4000-8000-000000000003';
const _messageId = '79000000-0000-4000-8000-000000000004';
const _photo = '$_actor/$_thread/$_messageId.jpg';
const _message = {
  'id': _messageId,
  'thread_id': _thread,
  'sender_id': _actor,
  'body': 'Respuesta sintética',
};
const _operations = [
  (
    kind: 'contact',
    rpc: 'dopmi_start_adoption_contact_v2',
    legacy: 'dopmi_start_adoption_contact',
  ),
  (kind: 'message', rpc: 'dopmi_send_message_v3', legacy: 'dopmi_send_message'),
  (
    kind: 'photo',
    rpc: 'dopmi_send_message_v3',
    legacy: 'dopmi_send_message_v2',
  ),
  (
    kind: 'close',
    rpc: 'dopmi_close_adoption_v2',
    legacy: 'dopmi_close_adoption',
  ),
];

class _ValueAnalytics extends AnalyticsSpy {
  bool fail = false;
  final payloads = <Map<String, Object>?>[];

  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    payloads.add(parameters);
    if (fail) throw StateError('Synthetic unavailable analytics');
    await super.event(name, parameters: parameters);
  }
}

Map<String, dynamic> _session() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.'
        '${encode({'sub': _actor, 'exp': 1893456000})}.synthetic-signature',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'synthetic-refresh',
    'user': {
      'id': _actor,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.test',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-10-01T00:00:00Z',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> actions;
  late Future<http.Response> Function(http.Request) respond;
  ReadValueMeasurement? readMeasurement;
  late MeasurementController controller;
  late _ValueAnalytics analytics;

  http.Response json(http.Request request, Object? body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  Object responseFor(String rpc) => switch (rpc) {
    'dopmi_start_adoption_contact_v2' => {
      'thread_id': _thread,
      'created_new': true,
      'signals': ['adoption_contact_created'],
    },
    'dopmi_start_adoption_contact' => _thread,
    'dopmi_send_message_v3' => {
      'message': _message,
      'signals': ['rescuer_first_reply'],
    },
    'dopmi_send_message' || 'dopmi_send_message_v2' => _message,
    'dopmi_close_adoption_v2' => {
      'adoption': {'id': _post, 'version': 3, 'status': 'adopted'},
      'signals': ['adoption_marked_adopted'],
    },
    'dopmi_close_adoption' => {'id': _post, 'version': 3, 'status': 'adopted'},
    _ => throw StateError('Unexpected fixture RPC'),
  };

  setUp(() async {
    actions = [];
    readMeasurement = null;
    respond = (request) async =>
        json(request, responseFor(request.url.pathSegments.last));
    client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/auth/')) {
          return json(request, _session());
        }
        actions.add(request);
        return respond(request);
      }),
    );
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
  });
  tearDown(() => client.dispose());

  Future<void> measure({bool enabled = true, String namespace = 'test'}) async {
    SharedPreferences.setMockInitialValues({
      'dopmi.analyticsOwner': enabled
          ? 'dopmi.$namespace.$_actor.analytics'
          : '',
      'dopmi.$namespace.$_actor.analytics': enabled,
    });
    analytics = _ValueAnalytics();
    controller = MeasurementController(
      await SharedPreferences.getInstance(),
      namespace,
      analytics,
      DiagnosticsSpy(),
    );
    addTearDown(controller.dispose);
    await controller.prepareStartup();
    await controller.owner(_actor);
    readMeasurement = () => controller;
  }

  String signalFor(String kind) => switch (kind) {
    'contact' => 'adoption_contact_created',
    'close' => 'adoption_marked_adopted',
    _ => 'rescuer_first_reply',
  };

  Future<Object?> act(String kind) async {
    switch (kind) {
      case 'contact':
        return SupabaseCommunityRepository(
          client,
          readMeasurement: readMeasurement,
        ).startThread(_post);
      case 'message':
        return SupabaseCommunityRepository(
          client,
          readMeasurement: readMeasurement,
        ).sendMessage(_thread, _messageId, 'Respuesta sintética');
      case 'photo':
        return SupabaseChatPhotoRepository(
          client,
          readMeasurement: readMeasurement,
        ).send(_thread, _messageId, 'Respuesta sintética', _photo);
      case 'close':
        await RescueRepository(
          client,
          readMeasurement: readMeasurement,
        ).closeAdoption(_post, 2, 'adopted', dopmiSupport: false);
        return null;
      default:
        throw ArgumentError.value(kind);
    }
  }

  test(
    'only the three confirmed value names join the existing event allowlist',
    () {
      expect(
        FirebaseProductAnalytics.allowed,
        containsAll([
          'adoption_contact_created',
          'rescuer_first_reply',
          'adoption_marked_adopted',
        ]),
      );
      expect(FirebaseProductAnalytics.allowed, contains('contact_started'));
    },
  );

  for (final operation in _operations) {
    test(
      '${operation.kind} emits one payload-free signal only after server success',
      () async {
        await measure();
        final entered = Completer<void>();
        final released = Completer<void>();
        respond = (request) async {
          entered.complete();
          await released.future;
          return json(request, responseFor(request.url.pathSegments.last));
        };
        final pending = act(operation.kind);
        await entered.future;
        expect(analytics.events, isEmpty);

        released.complete();
        await pending;

        expect(analytics.events, [signalFor(operation.kind)]);
        expect(analytics.payloads, [null]);
      },
    );

    test(
      '${operation.kind} omits events when server returns no confirmed signal',
      () async {
        await measure();
        respond = (request) async => json(request, {
          ...(responseFor(request.url.pathSegments.last) as Map),
          'signals': [],
        });

        await act(operation.kind);

        expect(analytics.events, isEmpty);
        expect(actions, hasLength(1));
      },
    );

    test(
      '${operation.kind} uses the confirmed RPC and preserves its public result',
      () async {
        final result = await act(operation.kind);

        expect(actions, hasLength(1));
        expect(actions.single.url.pathSegments.last, operation.rpc);
        expect(
          actions.single.headers['authorization'],
          'Bearer ${_session()['access_token']}',
        );
        if (operation.kind == 'contact') expect(result, _thread);
        if (operation.kind == 'message' || operation.kind == 'photo') {
          expect(result, _message);
          final payload = jsonDecode(actions.single.body);
          expect(payload['thread_id'], _thread);
          expect(payload['message_id'], _messageId);
          expect(payload['message_body'], 'Respuesta sintética');
          expect(
            payload['attachment_path'],
            operation.kind == 'photo' ? _photo : null,
          );
        }
        if (operation.kind == 'close') {
          expect(result, isNull);
          expect(jsonDecode(actions.single.body), {
            'post_id': _post,
            'expected_version': 2,
            'reason': 'adopted',
            'dopmi_support': false,
            'description': '',
          });
        }
      },
    );

    test(
      '${operation.kind} falls back only when the new RPC is missing',
      () async {
        await measure();
        respond = (request) async {
          if (request.url.pathSegments.last == operation.rpc) {
            return json(request, {
              'code': 'PGRST202',
              'message': 'Synthetic missing RPC',
              'details': null,
              'hint': null,
            }, 404);
          }
          return json(request, responseFor(request.url.pathSegments.last));
        };

        final result = await act(operation.kind);

        expect(actions.map((request) => request.url.pathSegments.last), [
          operation.rpc,
          operation.legacy,
        ]);
        for (final request in actions) {
          expect(
            request.headers['authorization'],
            'Bearer ${_session()['access_token']}',
          );
        }
        if (operation.kind == 'contact') expect(result, _thread);
        if (operation.kind == 'message' || operation.kind == 'photo') {
          expect(result, _message);
        }
        expect(analytics.events, isEmpty);
      },
    );

    for (final failure in [
      (status: 403, code: '42501'),
      (status: 404, code: 'PGRST205'),
      (status: 409, code: '40001'),
      (status: 503, code: 'PGRST000'),
    ]) {
      test(
        '${operation.kind} never retries an uncertain or rejected write (${failure.code})',
        () async {
          respond = (request) async => json(request, {
            'code': failure.code,
            'message': 'Synthetic rejected or uncertain write',
            'details': null,
            'hint': null,
          }, failure.status);

          await expectLater(
            act(operation.kind),
            throwsA(isA<PostgrestException>()),
          );

          expect(actions, hasLength(1));
        },
      );
    }

    test('${operation.kind} never retries after a transport timeout', () async {
      respond = (_) async => throw TimeoutException('Synthetic timeout');

      await expectLater(act(operation.kind), throwsA(isA<TimeoutException>()));

      expect(actions, hasLength(1));
    });
  }

  for (final signals in <Object?>[
    null,
    'rescuer_first_reply',
    {'name': 'rescuer_first_reply'},
    [42],
    ['unknown_event'],
    ['adoption_contact_created'],
    ['rescuer_first_reply', 'rescuer_first_reply'],
    ['rescuer_first_reply', 'unknown_event'],
    [
      {'name': 'rescuer_first_reply', 'parameters': <String, Object>{}},
    ],
    [
      {
        'name': 'rescuer_first_reply',
        'parameters': {'body': 'Synthetic text'},
      },
    ],
  ]) {
    test(
      'malformed or unrelated signals are omitted (${signals.runtimeType}: $signals)',
      () async {
        await measure();
        respond = (request) async =>
            json(request, {'message': _message, 'signals': signals});

        expect(await act('message'), _message);

        expect(analytics.events, isEmpty);
        expect(analytics.payloads, isEmpty);
        expect(actions, hasLength(1));
      },
    );
  }

  for (final signals in [
    <String>[],
    ['adoption_contact_created'],
  ]) {
    test(
      'a reopened contact never becomes a new-contact event ($signals)',
      () async {
        await measure();
        respond = (request) async => json(request, {
          'thread_id': _thread,
          'created_new': false,
          'signals': signals,
        });

        expect(await act('contact'), _thread);

        expect(analytics.events, isEmpty);
      },
    );
  }

  test('closing for another reason cannot emit an adopted outcome', () async {
    await measure();

    await RescueRepository(
      client,
      readMeasurement: readMeasurement,
    ).closeAdoption(_post, 2, 'withdrawn');

    expect(analytics.events, isEmpty);
    expect(actions, hasLength(1));
  });

  test(
    'an inconsistent adoption envelope cannot confirm an adopted outcome',
    () async {
      await measure();
      respond = (request) async => json(request, {
        'adoption': {'id': _post, 'status': 'archived'},
        'signals': ['adoption_marked_adopted'],
      });

      await act('close');

      expect(analytics.events, isEmpty);
      expect(actions, hasLength(1));
    },
  );

  test(
    'analytics failure cannot change the accepted message or repeat its write',
    () async {
      await measure();
      analytics.fail = true;

      expect(await act('message'), _message);

      expect(actions, hasLength(1));
      expect(analytics.payloads, [null]);
      expect(controller.lastAnalyticsResult, 'error_StateError');
    },
  );

  test(
    'the helper captures consent before invoking its dispatch callback',
    () async {
      await measure();
      final order = <String>[];

      final value = await confirmedValueAction(
        currentActor: () => _actor,
        readMeasurement: () {
          order.add('measurement');
          return controller;
        },
        operation: ConfirmedValueOperation.reply,
        dispatch: () async {
          order.add('dispatch');
          return const ConfirmedValueResult(
            _message,
            signals: ['rescuer_first_reply'],
          );
        },
      );

      expect(value, _message);
      expect(order, ['measurement', 'dispatch', 'measurement']);
      expect(analytics.events, ['rescuer_first_reply']);
      expect(analytics.payloads, [null]);
    },
  );

  for (final change in [
    'OFF',
    'OFF then ON',
    'owner',
    'auth actor',
    'account',
    'namespace',
  ]) {
    test(
      'a confirmed response omits its signal after $change changes in flight',
      () async {
        await measure();
        var actor = _actor;
        var current = controller;
        final entered = Completer<void>();
        final released = Completer<void>();
        final pending = confirmedValueAction(
          currentActor: () => actor,
          readMeasurement: () => current,
          operation: ConfirmedValueOperation.reply,
          dispatch: () async {
            entered.complete();
            await released.future;
            return const ConfirmedValueResult(
              _message,
              signals: ['rescuer_first_reply'],
            );
          },
        );
        await entered.future;

        switch (change) {
          case 'OFF':
            await controller.setAnalytics(false);
            break;
          case 'OFF then ON':
            await controller.setAnalytics(false);
            await controller.setAnalytics(true);
            break;
          case 'owner':
            await controller.owner(_other);
            break;
          case 'auth actor':
            actor = _other;
            break;
          case 'account':
            actor = _other;
            await controller.owner(_other);
            await controller.setAnalytics(true);
            break;
          case 'namespace':
            current = MeasurementController(
              controller.preferences,
              'another-environment',
              _ValueAnalytics(),
              DiagnosticsSpy(),
            );
            addTearDown(current.dispose);
            await current.owner(_actor);
            await current.setAnalytics(true);
            break;
        }
        released.complete();

        expect(await pending, _message);
        expect(analytics.events, isEmpty);
      },
    );
  }

  test(
    'an action dispatched with OFF cannot be backfilled by a later ON',
    () async {
      await measure(enabled: false);
      final entered = Completer<void>();
      final released = Completer<void>();
      final pending = confirmedValueAction(
        currentActor: () => _actor,
        readMeasurement: readMeasurement,
        operation: ConfirmedValueOperation.reply,
        dispatch: () async {
          entered.complete();
          await released.future;
          return const ConfirmedValueResult(
            _message,
            signals: ['rescuer_first_reply'],
          );
        },
      );
      await entered.future;
      await controller.setAnalytics(true);
      released.complete();

      expect(await pending, _message);
      expect(analytics.events, isEmpty);
    },
  );

  for (final change in ['OFF', 'owner']) {
    test(
      '$change requested between RPC success and SDK dispatch suppresses the signal',
      () async {
        await measure();
        var reads = 0;
        Future<void>? transition;

        final value = await confirmedValueAction(
          currentActor: () => _actor,
          readMeasurement: () {
            if (++reads == 2) {
              transition = change == 'OFF'
                  ? controller.setAnalytics(false)
                  : controller.owner(_other);
            }
            return controller;
          },
          operation: ConfirmedValueOperation.reply,
          dispatch: () async => const ConfirmedValueResult(
            _message,
            signals: ['rescuer_first_reply'],
          ),
        );
        await transition;

        expect(value, _message);
        expect(analytics.events, isEmpty);
        expect(analytics.payloads, isEmpty);
      },
    );
  }

  for (final failAfterDispatch in [false, true]) {
    test(
      'measurement lookup failure does not change product success ($failAfterDispatch)',
      () async {
        await measure();
        var dispatched = false;

        final value = await confirmedValueAction(
          currentActor: () => _actor,
          readMeasurement: () {
            if (dispatched == failAfterDispatch) {
              throw StateError('Synthetic unavailable provider');
            }
            return controller;
          },
          operation: ConfirmedValueOperation.reply,
          dispatch: () async {
            dispatched = true;
            return const ConfirmedValueResult(
              _message,
              signals: ['rescuer_first_reply'],
            );
          },
        );

        expect(value, _message);
        expect(analytics.events, isEmpty);
      },
    );
  }
}
