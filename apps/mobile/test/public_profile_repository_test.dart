import 'dart:convert';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final revoked in [false, true]) {
    test('public profile joins authorized metrics; revoked=$revoked', () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final rpc = request.url.pathSegments.last;
          calls.add(rpc);
          expect(jsonDecode(request.body)['person_id'], 'synthetic-person');
          return http.Response(
            jsonEncode(
              rpc == 'dopmi_rescuer_public'
                  ? {'id': 'synthetic-person', 'verified': true}
                  : revoked
                  ? null
                  : {'funded_cents': 9901},
            ),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await SupabaseCommunityRepository(client)
          .publicProfile('synthetic-person');
      expect(calls, ['dopmi_rescuer_public', 'dopmi_rescuer_public_metrics']);
      if (revoked) {
        expect(result, isNull);
      } else {
        expect(result?['metrics']['funded_cents'], 9901);
      }
    });
  }
}
