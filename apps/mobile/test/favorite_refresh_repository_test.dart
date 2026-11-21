import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the real repository and HTTP transport while emitting no Realtime
/// events and never opening a socket.
class SilentFavoriteClient extends SupabaseClient {
  SilentFavoriteClient(Future<http.Response> Function(http.Request) handle)
    : super(
        'http://127.0.0.1:54321',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(handle),
      );

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) => _SilentChannel(name, realtime, params: opts);

  @override
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';
}

class _SilentChannel extends RealtimeChannel {
  _SilentChannel(super.topic, super.socket, {super.params});

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) => this;
}

/// No Auth or JSON worker is needed when a widget test holds the RPC itself.
class SilentFavoriteSocketClient implements SupabaseClient {
  @override
  final realtime = RealtimeClient('ws://127.0.0.1:54321');

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) => _SilentChannel(name, realtime, params: opts);

  @override
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';

  @override
  Future<void> dispose() => realtime.disconnect();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FavoriteRefreshRepository extends SupabaseCommunityRepository {
  FavoriteRefreshRepository(super.client);
  String? actor = 'one';
  @override
  String? get userId => actor;
}

void main() {
  late SilentFavoriteClient client;
  late FavoriteRefreshRepository repository;
  late Completer<http.Request> requested;
  late Completer<http.Response> response;

  setUp(() {
    requested = Completer<http.Request>();
    response = Completer<http.Response>();
    client = SilentFavoriteClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/dopmi_set_favorite');
      requested.complete(request);
      final result = await response.future;
      return http.Response(
        result.body,
        result.statusCode,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    repository = FavoriteRefreshRepository(client);
  });
  tearDown(() => client.dispose());

  test(
    'successful favorite refreshes local favorite watchers only after commit',
    () async {
      var favorites = 0, unrelated = 0;
      final cancelFavorite = repository.watch([
        'dopmi_favorites',
      ], () => favorites++);
      final cancelOther = repository.watch([
        'dopmi_threads',
      ], () => unrelated++);
      final write = repository.favorite('post', true);
      await requested.future;
      expect(favorites, 0);
      response.complete(http.Response('', 204));
      await write;
      expect(favorites, 1);
      expect(unrelated, 0);
      cancelFavorite();
      cancelOther();
    },
  );

  test('failed favorite does not refresh local watchers', () async {
    var favorites = 0;
    final cancel = repository.watch(['dopmi_favorites'], () => favorites++);
    final write = repository.favorite('post', true);
    final failure = expectLater(write, throwsA(isA<PostgrestException>()));
    await requested.future;
    response.complete(
      http.Response('{"message":"synthetic failure","code":"42501"}', 403),
    );
    await failure;
    expect(favorites, 0);
    cancel();
  });

  test(
    'cancelled watch receives no notification when the RPC completes',
    () async {
      var favorites = 0;
      final cancel = repository.watch(['dopmi_favorites'], () => favorites++);
      final write = repository.favorite('post', false);
      await requested.future;
      cancel();
      response.complete(http.Response('', 204));
      await write;
      expect(favorites, 0);
    },
  );

  for (final actor in <String?>['two', null]) {
    test(
      'completed favorite does not notify after the actor changes to $actor',
      () async {
        var favorites = 0;
        final cancel = repository.watch(['dopmi_favorites'], () => favorites++);
        final write = repository.favorite('post', true);
        await requested.future;
        repository.actor = actor;
        response.complete(http.Response('', 204));
        await write;
        expect(favorites, 0);
        cancel();
      },
    );
  }

  test('a guest write cannot notify another account watchers', () async {
    var favorites = 0;
    final cancel = repository.watch(['dopmi_favorites'], () => favorites++);
    repository.actor = null;
    final write = repository.favorite('post', true);
    await requested.future;
    repository.actor = 'one';
    response.complete(http.Response('', 204));
    await write;
    expect(favorites, 0);
    cancel();
  });

  test(
    'a failing refresh cannot turn a committed favorite into a failed write',
    () async {
      final reported = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previousHandler);
      var laterRefreshes = 0;
      final cancelBroken = repository.watch([
        'dopmi_favorites',
      ], () => throw StateError('synthetic refresh failure'));
      final cancelHealthy = repository.watch([
        'dopmi_favorites',
      ], () => laterRefreshes++);
      final write = repository.favorite('post', true);
      await requested.future;
      response.complete(http.Response('', 204));
      await write;
      expect(reported, hasLength(1));
      expect(laterRefreshes, 1);
      cancelBroken();
      cancelHealthy();
    },
  );
}
