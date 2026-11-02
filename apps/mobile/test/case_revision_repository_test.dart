import 'dart:convert';
import 'dart:typed_data';

import 'package:dopmi_mobile/features/adoption/community_repository.dart'
    show Json;
import 'package:dopmi_mobile/features/rescue/case_revision.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'case_revision_screen_test.dart' show revisionData;
import 'payment_repository_test.dart' show actor, session;

Uint8List multipartPdfBytes(http.Request request) {
  final boundaryMatch = RegExp(r'boundary=(?:"([^"]+)"|([^;\s]+))')
      .firstMatch(request.headers['content-type'] ?? '');
  expect(boundaryMatch, isNotNull, reason: 'Storage uploads multipart data.');
  final boundary = boundaryMatch!.group(1) ?? boundaryMatch.group(2)!;
  // Latin-1 preserves each byte while the MIME headers and delimiters are read.
  final parts = latin1.decode(request.bodyBytes).split('--$boundary');
  final pdfParts = parts.where((part) {
    final separator = part.indexOf('\r\n\r\n');
    return separator >= 0 &&
        RegExp(
          r'content-type:\s*application/pdf\r?$',
          multiLine: true,
          caseSensitive: false,
        ).hasMatch(part.substring(0, separator));
  }).toList();
  expect(pdfParts, hasLength(1));
  final part = pdfParts.single;
  final payload = part.substring(part.indexOf('\r\n\r\n') + 4);
  expect(payload.endsWith('\r\n'), isTrue);
  return Uint8List.fromList(
    latin1.encode(payload.substring(0, payload.length - 2)),
  );
}

void main() {
  test('revision RPCs send complete content and stable IDs without financial metadata', () async {
    final requests = <http.Request>[];
    final data = revisionData();
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/dopmi_case_revision') ? null : data,
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = RescueRepository(client);
    expect(await repo.caseRevision('case-one'), isNull);
    final packet = await repo.startCaseRevision(
      RescueRecord(data['base_record']),
      'start-key',
    );
    final fields = <String, dynamic>{
      'public_data': {'pet_name': 'Mora'},
      'private_data': <String, dynamic>{},
      'files': <Json>[],
    };
    await repo.saveCaseRevision(
      id: packet.id,
      version: packet.version,
      reason: 'Corregí el texto.',
      caseFields: fields,
      expenseFields: [
        {'id': 'expense-locked', ...fields},
        {'id': 'expense-editable', ...fields},
      ],
      requestId: 'save-key',
    );
    await repo.transitionCaseRevision(packet, 'submit', 'submit-key');
    expect(requests.map((request) => request.url.path.split('/').last), [
      'dopmi_case_revision',
      'dopmi_start_case_revision',
      'dopmi_save_case_revision',
      'dopmi_transition_case_revision',
    ]);
    expect(jsonDecode(requests[1].body), {
      'record_id': 'case-one',
      'expected_version': 3,
      'request_id': 'start-key',
    });
    expect(jsonDecode(requests[2].body), {
      'revision_id': packet.id,
      'expected_version': 1,
      'reason': 'Corregí el texto.',
      'case_fields': fields,
      'expense_fields': [
        {'id': 'expense-locked', ...fields},
        {'id': 'expense-editable', ...fields},
      ],
      'request_id': 'save-key',
    });
    expect(jsonDecode(requests[3].body), {
      'revision_id': packet.id,
      'expected_version': 1,
      'action': 'submit',
      'request_id': 'submit-key',
    });
  });

  for (final wrongIntent in [false, true]) {
    test(
      'private revision upload uses only its registered path; mismatched intent=$wrongIntent',
      () async {
        final requests = <http.Request>[];
        const path = '$actor/case-one/revision-one/receipt.pdf';
        final packet = CaseRevisionPacket(revisionData());
        final client = SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            if (request.url.path.startsWith('/auth/')) {
              return http.Response(
                jsonEncode(session()),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            requests.add(request);
            return http.Response(
              jsonEncode(
                request.url.path.contains('/rpc/')
                    ? {
                        'revision_id': wrongIntent
                            ? 'other-revision'
                            : packet.id,
                        'record_id': 'expense-locked',
                        'role': 'receipt',
                        'path': path,
                      }
                    : {'Key': 'dopmi-rescue-evidence/$path'},
              ),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: 'fixture@example.test',
          password: 'synthetic',
        );
        final bytes = Uint8List.fromList(
          utf8.encode('%PDF-synthetic-private-evidence'),
        );
        final future = RescueRepository(client).uploadCaseRevision(
          packet: packet,
          recordId: 'expense-locked',
          role: 'receipt',
          bytes: bytes,
          pdf: true,
          requestId: 'file-key',
        );
        if (wrongIntent) {
          await expectLater(future, throwsFormatException);
          expect(requests, hasLength(1));
        } else {
          expect(await future, path);
          expect(requests, hasLength(2));
          expect(
            requests.last.url.path,
            '/storage/v1/object/dopmi-rescue-evidence/$path',
          );
          expect(requests.last.headers['x-upsert'], 'false');
          expect(multipartPdfBytes(requests.last), bytes);
        }
        expect(jsonDecode(requests.first.body), {
          'revision_id': packet.id,
          'expected_version': 1,
          'record_id': 'expense-locked',
          'file_role': 'receipt',
          'extension': 'pdf',
          'request_id': 'file-key',
        });
      },
    );
  }
}
