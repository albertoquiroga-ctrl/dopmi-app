import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/attribution_action_barrier.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/chat_photo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'measurement_test.dart'
    show AnalyticsSpy, BlockingEnableAnalytics, DiagnosticsSpy;

const _actor = '78000000-0000-4000-8000-000000000001';
const _other = '78000000-0000-4000-8000-000000000002';
const _post = '78000000-0000-4000-8000-000000000003';
const _thread = '78000000-0000-4000-8000-000000000004';
const _message = '78000000-0000-4000-8000-000000000005';
const _photo = '$_actor/$_thread/$_message.jpg';

class _Community extends SupabaseCommunityRepository {
  _Community(super.client, PrepareAttributableAction prepare)
    : super(beforeAttributableAction: prepare);
}

class _Photos extends SupabaseChatPhotoRepository {
  _Photos(super.client, PrepareAttributableAction prepare)
    : super(beforeAttributableAction: prepare);
}

Map<String, dynamic> _session(
  String owner, {
  int expiresAt = 1893456000,
  String generation = 'original',
}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.'
        '${encode({'sub': owner, 'exp': expiresAt, 'generation': generation})}.synthetic-signature',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'synthetic-refresh',
    'user': {
      'id': owner,
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
  late SupabaseClient client;
  late List<http.Request> actions;
  var authenticatedOwner = _actor;
  var expiresAt = 1893456000;
  var generation = 'original';
  late List<http.Request> authRequests;

  setUp(() async {
    authenticatedOwner = _actor;
    expiresAt = 1893456000;
    generation = 'original';
    actions = [];
    authRequests = [];
    client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object result;
        if (request.url.path.startsWith('/auth/')) {
          authRequests.add(request);
          result = _session(
            authenticatedOwner,
            expiresAt: expiresAt,
            generation: generation,
          );
        } else {
          actions.add(request);
          result = request.url.path.endsWith('dopmi_start_adoption_contact')
              ? _thread
              : {'id': _post, 'version': 2, 'status': 'submitted'};
        }
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'synthetic-password',
    );
  });
  tearDown(() => client.dispose());

  Future<Object?> act(String kind, Future<void> Function(String) prepare) =>
      switch (kind) {
        'greeting' => _Community(client, prepare).startThread(_post),
        'message' => _Community(
          client,
          prepare,
        ).sendMessage(_thread, _message, 'Mensaje sintético'),
        'submission' => _Community(
          client,
          prepare,
        ).transition(Adoption({'id': _post, 'version': 1}), 'submit'),
        'photo' => _Photos(client, prepare).send(_thread, _message, '', _photo),
        _ => throw ArgumentError.value(kind),
      };

  for (final kind in ['greeting', 'message', 'submission', 'photo']) {
    test(
      '$kind refreshes an expired session before pinning Authorization',
      () async {
        expiresAt = 1;
        await client.auth.signInWithPassword(
          email: 'fixture@example.test',
          password: 'synthetic-password',
        );
        expect(client.auth.currentSession!.isExpired, isTrue);
        expiresAt = 1893456000;
        generation = 'refreshed';
        await act(kind, (_) async {});
        expect(
          authRequests.last.url.queryParameters['grant_type'],
          'refresh_token',
        );
        expect(actions, hasLength(1));
        expect(
          actions.single.headers['authorization'],
          'Bearer ${_session(_actor, generation: 'refreshed')['access_token']}',
        );
      },
    );

    test('$kind aborts if refresh establishes a different actor', () async {
      expiresAt = 1;
      await client.auth.signInWithPassword(
        email: 'fixture@example.test',
        password: 'synthetic-password',
      );
      authenticatedOwner = _other;
      expiresAt = 1893456000;
      generation = 'different-actor';
      await expectLater(act(kind, (_) async {}), throwsStateError);
      expect(actions, isEmpty);
    });

    test('$kind waits for campaign before the product RPC', () async {
      final acquired = Completer<void>();
      final owners = <String>[];
      final operation = act(kind, (owner) {
        owners.add(owner);
        return acquired.future;
      });
      try {
        await Future<void>.delayed(Duration.zero);
        expect(owners, [_actor]);
        expect(actions, isEmpty);
      } finally {
        acquired.complete();
        await operation;
      }
      expect(actions, hasLength(1));
      expect(
        actions.single.headers['authorization'],
        'Bearer ${_session(_actor)['access_token']}',
      );
      final payload = jsonDecode(actions.single.body);
      if (kind == 'message' || kind == 'photo') {
        expect(payload['thread_id'], _thread);
        expect(payload['message_id'], _message);
        expect(
          payload['message_body'],
          kind == 'photo' ? '' : 'Mensaje sintético',
        );
      }
      if (kind == 'photo') expect(payload['attachment_path'], _photo);
      if (kind == 'submission') {
        expect(payload, {
          'post_id': _post,
          'expected_version': 1,
          'action': 'submit',
        });
      }
    });

    test('$kind continues if optional attribution fails', () async {
      await act(kind, (_) async => throw StateError('measurement unavailable'));
      expect(actions, hasLength(1));
    });

    test('$kind never executes as another account after the wait', () async {
      final acquired = Completer<void>();
      final entered = Completer<void>();
      final operation = act(kind, (_) {
        entered.complete();
        return acquired.future;
      });
      final rejected = expectLater(operation, throwsStateError);
      await entered.future;
      authenticatedOwner = _other;
      await client.auth.signInWithPassword(
        email: 'other@example.test',
        password: 'synthetic-password',
      );
      acquired.complete();
      await rejected;
      expect(actions, isEmpty);
    });
  }

  test(
    'unrelated reads and non-submit transitions never wait for acquisition',
    () async {
      var preparations = 0;
      final repository = _Community(client, (_) async {
        preparations++;
      });
      await repository.transition(
        Adoption({'id': _post, 'version': 1}),
        'archive',
      );
      expect(preparations, 0);
      expect(actions, hasLength(1));
    },
  );

  test(
    'a just-restored owner waits for settings and source before greeting',
    () async {
      SharedPreferences.setMockInitialValues({
        'dopmi.test.$_actor.analytics': true,
      });
      final analytics = BlockingEnableAnalytics();
      final source = Completer<void>();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        DiagnosticsSpy(),
        prepareAdoptionConsent: (_, enabled) => () async {
          if (enabled) await source.future;
        },
      );
      addTearDown(controller.dispose);
      final restoring = controller.owner(_actor);
      await analytics.started.future;
      final operation = act('greeting', controller.prepareAttributableAction);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(actions, isEmpty);
        analytics.release.complete();
        await restoring;
        await Future<void>.delayed(Duration.zero);
        expect(actions, isEmpty);
      } finally {
        if (!analytics.release.isCompleted) analytics.release.complete();
        source.complete();
        await operation;
      }
      expect(actions, hasLength(1));
    },
  );

  test(
    'explicit OFF does not wait for the earlier attribution request',
    () async {
      SharedPreferences.setMockInitialValues({
        'dopmi.test.$_actor.analytics': true,
      });
      final source = Completer<void>();
      final started = Completer<void>();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        AnalyticsSpy(),
        DiagnosticsSpy(),
        prepareAdoptionConsent: (_, enabled) => () async {
          if (enabled) {
            started.complete();
            await source.future;
          }
        },
      );
      addTearDown(controller.dispose);
      await controller.owner(_actor);
      await started.future;
      await controller.setAnalytics(false);
      try {
        await act('greeting', controller.prepareAttributableAction);
        expect(source.isCompleted, isFalse);
        expect(actions, hasLength(1));
      } finally {
        source.complete();
        await controller.consentReady;
      }
    },
  );

  test('a hung optional preparation has a finite wait', () async {
    final pending = Completer<void>();
    try {
      final token = await attributionActionToken(
        client,
        (_) => pending.future,
        preparationTimeout: const Duration(milliseconds: 1),
      );
      expect(token, _session(_actor)['access_token']);
      expect(pending.isCompleted, isFalse);
    } finally {
      pending.complete();
    }
  });
}
