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
  test('pending Stripe preserves the server case and withdraws its current version', () async {
    final requests = <http.Request>[];
    final draft = RescueRecord({
      'id': 'fixture-private-case',
      'kind': 'case',
      'status': 'draft',
      'version': 4,
      'public_data': {
        'pet_name': 'Mora',
        'photos': ['owner/private-case/photo.jpg'],
      },
      'files': [
        {'role': 'public', 'path': 'owner/private-case/photo.jpg'},
      ],
    });
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(request.body) as Map?) ?? <String, dynamic>{};
        final result = switch (request.url.path) {
          '/rest/v1/rpc/dopmi_transition_rescue' => {
            ...draft.data,
            'status': body['action'] == 'submit' ? 'pending_stripe' : 'draft',
            'version': body['action'] == 'submit' ? 5 : 6,
            'submitted_at': null,
          },
          '/rest/v1/rpc/dopmi_owned_cases' => {
            'total': 1,
            'items': [
              {
                'id': draft.id,
                'status': 'pending_stripe',
                'phase': 'pending_stripe',
              },
            ],
          },
          '/rest/v1/rpc/dopmi_rescuer_dashboard_v2' => {
            'support_counts': {'review': 0, 'pendingStripe': 1},
            'case_counts': {'review': 0, 'pendingStripe': 1},
            'adoption_counts': {'review': 2},
          },
          _ => throw StateError('Unexpected RPC ${request.url.path}'),
        };
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = RescueRepository(client);
    final waiting = await repository.transition(draft, 'submit');
    expect(waiting.pendingStripe, isTrue);
    expect(waiting.editable, isFalse);
    expect(waiting.id, draft.id);
    expect(waiting.version, 5);
    expect(waiting.data['submitted_at'], isNull);
    expect(waiting.files, draft.files);
    expect(waiting.publicData, draft.publicData);
    final owned = await repository.ownedCases(
      1,
      program: 'support',
      statuses: ['pending_stripe'],
    );
    expect((owned['items'] as List).single['phase'], 'pending_stripe');
    final counts = await repository.dashboardV2();
    expect(counts['support_counts'], {'review': 0, 'pendingStripe': 1});
    expect(counts['case_counts'], counts['support_counts']);
    expect(counts['adoption_counts'], {'review': 2});
    final withdrawn = await repository.transition(waiting, 'withdraw');
    expect(withdrawn.id, draft.id);
    expect(withdrawn.editable, isTrue);
    expect(withdrawn.version, 6);
    expect(withdrawn.files, draft.files);
    final transitions = requests
        .where(
          (request) => request.url.path.endsWith('/dopmi_transition_rescue'),
        )
        .map((request) => jsonDecode(request.body))
        .toList();
    expect(transitions, [
      {'record_id': draft.id, 'expected_version': 4, 'action': 'submit'},
      {'record_id': draft.id, 'expected_version': 5, 'action': 'withdraw'},
    ]);
    final listRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/dopmi_owned_cases'),
    );
    expect(jsonDecode(listRequest.body)['statuses'], ['pending_stripe']);
  });
}
