import 'dart:io';
import 'dart:typed_data';

import 'package:dopmi_mobile/features/profile/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000001';
  test('attachment upload is separate from request replay and the exact path participates in recovery', () async {
    const path = 'owner/request/photo.jpg';
    var uploads = 0;
    final calls = <String>[];
    final bytes = Uint8List.fromList([1, 2, 3]);
    final repo = SupportRepository(
      (name, params) async {
        calls.add(name);
        final payload =
            params[name == 'dopmi_submit_support_request'
                    ? 'payload'
                    : 'expected_payload']
                as Map;
        expect(payload['attachment_path'], path);
        if (name == 'dopmi_submit_support_request') {
          throw const SocketException('lost');
        }
        return {'request_id': id, 'status': 'received'};
      },
      upload: (requestId, data) async {
        uploads++;
        expect(requestId, id);
        expect(data, bytes);
        return path;
      },
    );
    final storedPath = await repo.uploadAttachment(id, bytes);
    await repo.submit(
      requestId: id,
      topic: 'account',
      message: 'Ayuda.',
      attachmentPath: storedPath,
    );
    expect(uploads, 1);
    expect(calls, ['dopmi_submit_support_request', 'dopmi_my_support_request']);
  });
  Future<void> send(SupportRepository repo) => repo.submit(
    requestId: id,
    topic: 'guardian',
    caseName: ' Luna ',
    message: ' Ayuda en México. ',
  );
  test('lost response recovers only the same durable owner receipt without a second submission', () async {
    final calls = <String>[];
    final repo = SupportRepository((name, params) async {
      calls.add(name);
      expect(params['target_request'], id);
      if (name == 'dopmi_submit_support_request') {
        expect(params['payload'], {
          'topic': 'guardian',
          'case_name': 'Luna',
          'message': 'Ayuda en México.',
        });
        throw const SocketException('response lost');
      }
      expect(params['expected_payload'], {
        'topic': 'guardian',
        'case_name': 'Luna',
        'message': 'Ayuda en México.',
      });
      return {'request_id': id, 'status': 'received'};
    });
    await send(repo);
    expect(calls, ['dopmi_submit_support_request', 'dopmi_my_support_request']);
  });
  test(
    'missing, foreign and pending receipts retain transport failure',
    () async {
      for (final receipt in [
        null,
        {'request_id': 'other', 'status': 'received'},
        {'request_id': id, 'status': 'pending'},
      ]) {
        final repo = SupportRepository((name, params) async {
          if (name == 'dopmi_submit_support_request') {
            throw const SocketException('lost');
          }
          return receipt;
        });
        await expectLater(send(repo), throwsA(isA<SocketException>()));
      }
    },
  );
  test('SQL rejection and wrong direct receipt never become success through an old receipt', () async {
    for (final reject in [true, false]) {
      var calls = 0;
      final repo = SupportRepository((name, params) async {
        calls++;
        if (reject) {
          throw const PostgrestException(
            message: 'changed content',
            code: '40001',
          );
        }
        return {'request_id': 'other', 'status': 'received'};
      });
      await expectLater(
        send(repo),
        throwsA(reject ? isA<PostgrestException>() : isA<StateError>()),
      );
      expect(calls, 1);
    }
  });
}
