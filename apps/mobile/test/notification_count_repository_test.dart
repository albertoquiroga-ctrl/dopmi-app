import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CountQueryRepository extends SupabaseCommunityRepository {
  CountQueryRepository(super.client);
  // Synthetic actor permits testing the HTTP query, without an Auth session.
  @override
  String? get userId => 'synthetic-actor';
}

void main() {
  test('unread count uses exact server count beyond the first page', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '',
          200,
          request: request,
          headers: {'content-range': '*/43'},
        );
      }),
    );
    addTearDown(client.dispose);
    expect(await CountQueryRepository(client).unreadNotificationCount(), 43);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'HEAD');
    expect(requests.single.url.path, '/rest/v1/dopmi_notifications');
    expect(requests.single.url.queryParameters['read_at'], 'is.null');
    expect(requests.single.headers['Prefer'], contains('count=exact'));
  });
  test('guest unread count does not request private notifications', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('', 401);
      }),
    );
    addTearDown(client.dispose);
    expect(
      await SupabaseCommunityRepository(client).unreadNotificationCount(),
      0,
    );
    expect(requests, isEmpty);
  });
}
