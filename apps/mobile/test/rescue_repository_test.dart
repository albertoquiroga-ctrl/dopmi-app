import 'dart:convert';

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final denied in [false, true]) {
    test(
      'owned cases use paginated RPC and preserve financial data or denial: $denied',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(
                denied
                    ? {'code': '42501', 'message': 'Sesión activa requerida'}
                    : {
                        'total': 21,
                        'items': [
                          {
                            'id': 'fixture-case',
                            'kind': 'case',
                            'status': 'approved',
                            'public_data': {
                              'pet_name': 'Luna',
                              'photos': ['owner/photo'],
                            },
                            'private_data': {'fixture': 'privado'},
                            'target_cents': 12000,
                            'funded_cents': 8714,
                            'transferred_cents': 3314,
                          },
                        ],
                      },
              ),
              denied ? 403 : 200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = RescueRepository(client);
        if (denied) {
          await expectLater(
            repository.mine('case', 2),
            throwsA(isA<PostgrestException>()),
          );
        } else {
          final result = await repository.mine('case', 2);
          expect(result.total, 21);
          expect(result.items.single.targetCents, 12000);
          expect(result.items.single.fundedCents, 8714);
          expect(result.items.single.transferredCents, 3314);
          expect(result.items.single.publicData['photos'], ['owner/photo']);
          expect(result.items.single.privateData['fixture'], 'privado');
        }
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/rest/v1/rpc/dopmi_my_cases');
        expect(jsonDecode(requests.single.body), {'page_number': 2});
      },
    );
  }
}
