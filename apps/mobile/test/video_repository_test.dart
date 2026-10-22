import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';

Map<String, dynamic> uploading() => {
  'id': 'asset',
  'technical_state': 'uploading',
  'moderation_state': 'pending',
  'upload_url': 'https://upload.videodelivery.net/capability',
};
VideoUploadTask task() => VideoUploadTask(
  parentId: 'parent',
  parentVersion: 2,
  purpose: 'thanks',
  identity: 'owner:session',
  requestKey: 'stable-key',
);
void main() {
  for (final terminal in ['canceled', 'deleted']) {
    test(
      'lost cancel acknowledgement reconciles $terminal for the same identity and asset',
      () async {
        final calls = <Map<String, dynamic>>[];
        final repo = VideoRepository(
          identity: () => 'owner:session',
          invoke: (data) async {
            calls.add(Map.of(data));
            if (data['action'] == 'cancel') {
              throw const VideoFailure('request_denied');
            }
            return {
              'id': 'asset',
              'technical_state': terminal,
              'moderation_state': 'pending',
            };
          },
        );
        final work = task()..assetId = 'asset';
        await repo.cancel(work);
        expect(calls, [
          {'action': 'cancel', 'id': 'asset'},
          {'action': 'status', 'id': 'asset'},
        ]);
        expect(work.assetId, 'asset');
        expect(work.requestKey, 'stable-key');
        repo.dispose();
      },
    );
  }
  for (final outcome in [
    'ready',
    'processing',
    'status-failed',
    'wrong-asset',
  ]) {
    test(
      'cancel remains pending when reconciliation returns $outcome',
      () async {
        final calls = <Map<String, dynamic>>[];
        final repo = VideoRepository(
          identity: () => 'owner:session',
          invoke: (data) async {
            calls.add(Map.of(data));
            if (data['action'] == 'cancel' || outcome == 'status-failed') {
              throw const VideoFailure('request_denied');
            }
            return {
              'id': outcome == 'wrong-asset' ? 'other-asset' : 'asset',
              'technical_state': outcome == 'wrong-asset'
                  ? 'canceled'
                  : outcome,
            };
          },
        );
        final work = task()..assetId = 'asset';
        await expectLater(
          repo.cancel(work),
          throwsA(
            isA<VideoFailure>().having((e) => e.code, 'code', 'cancel_pending'),
          ),
        );
        expect(calls, [
          {'action': 'cancel', 'id': 'asset'},
          {'action': 'status', 'id': 'asset'},
        ]);
        expect(
          work.canceled,
          isTrue,
        ); // A local stop flag is not remote cancellation.
        expect(work.assetId, 'asset');
        expect(work.requestKey, 'stable-key');
        repo.dispose();
      },
    );
  }
  test(
    'cancel reconciliation never reads the old asset after identity changes',
    () async {
      var scope = 'owner:session';
      final calls = <Map<String, dynamic>>[];
      final repo = VideoRepository(
        identity: () => scope,
        invoke: (data) async {
          calls.add(Map.of(data));
          scope = 'other:session';
          throw const VideoFailure('request_denied');
        },
      );
      await expectLater(
        repo.cancel(task()..assetId = 'asset'),
        throwsA(
          isA<VideoFailure>().having((e) => e.code, 'code', 'identity_changed'),
        ),
      );
      expect(calls, [
        {'action': 'cancel', 'id': 'asset'},
      ]);
      repo.dispose();
    },
  );
  test(
    'TUS streams bounded chunks and resumes from provider HEAD offset',
    () async {
      final methods = <String>[], sizes = <int>[], keys = <String>[];
      var offset = 10;
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          if (body['action'] == 'begin') {
            keys.add(body['request_key'] as String);
            return uploading();
          }
          return {
            'id': 'asset',
            'technical_state': 'processing',
            'moderation_state': 'pending',
          };
        },
        transport: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'HEAD') {
            return http.Response(
              '',
              200,
              headers: {'upload-offset': '$offset'},
            );
          }
          sizes.add(request.bodyBytes.length);
          expect(request.headers['upload-offset'], '$offset');
          offset += request.bodyBytes.length;
          return http.Response('', 204, headers: {'upload-offset': '$offset'});
        }),
      );
      final work = task();
      final result = await repo.upload(
        work,
        XFile.fromData(Uint8List(videoChunkBytes + 20)),
      );
      expect(result.state, 'processing');
      expect(methods, ['HEAD', 'PATCH', 'PATCH']);
      expect(sizes, [videoChunkBytes, 10]);
      expect(keys, ['stable-key']);
      expect(work.uploaded, videoChunkBytes + 20);
      repo.dispose();
    },
  );
  test('lost PATCH reply retries same key and uses HEAD without uploading duplicates', () async {
    var offset = 0, patches = 0;
    final keys = <String>[];
    final repo = VideoRepository(
      identity: () => 'owner:session',
      invoke: (body) async {
        if (body['action'] == 'begin') {
          keys.add(body['request_key'] as String);
          return uploading();
        }
        return {
          'id': 'asset',
          'technical_state': 'processing',
          'moderation_state': 'pending',
        };
      },
      transport: MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'upload-offset': '$offset'});
        }
        patches++;
        offset += request.bodyBytes.length;
        throw const VideoFailure('lost_reply');
      }),
    );
    final work = task(), file = XFile.fromData(Uint8List(100));
    await expectLater(repo.upload(work, file), throwsA(isA<VideoFailure>()));
    expect((await repo.upload(work, file)).state, 'processing');
    expect(keys, ['stable-key', 'stable-key']);
    expect(patches, 1);
    repo.dispose();
  });
  test(
    'remount after lost partial PATCH reply resumes only remaining bytes',
    () async {
      final bytes = Uint8List(videoChunkBytes + 17);
      bytes.fillRange(0, videoChunkBytes, 41);
      bytes.fillRange(videoChunkBytes, bytes.length, 93);
      final received = BytesBuilder(copy: false);
      final patchOffsets = <int>[];
      final headOffsets = <int>[];
      final begins = <Map<String, dynamic>>[];
      var loseReply = true;
      Future<Map<String, dynamic>> invoke(Map<String, dynamic> body) async {
        if (body['action'] == 'begin') {
          begins.add(Map.of(body));
          return uploading();
        }
        expect(body, {'action': 'status', 'id': 'asset'});
        return {
          'id': 'asset',
          'technical_state': 'processing',
          'moderation_state': 'pending',
        };
      }

      final transport = MockClient((request) async {
        if (request.method == 'HEAD') {
          headOffsets.add(received.length);
          return http.Response(
            '',
            200,
            headers: {
              'upload-offset': '${received.length}',
              'upload-length': '${bytes.length}',
            },
          );
        }
        expect(request.method, 'PATCH');
        final offset = int.parse(request.headers['upload-offset']!);
        patchOffsets.add(offset);
        expect(offset, received.length);
        received.add(request.bodyBytes);
        if (loseReply) {
          loseReply = false;
          throw const VideoFailure('lost_reply');
        }
        return http.Response(
          '',
          204,
          headers: {'upload-offset': '${received.length}'},
        );
      });
      final original = task();
      final first = VideoRepository(
        identity: () => 'owner:session',
        invoke: invoke,
        transport: transport,
      );
      final file = XFile.fromData(bytes);
      await expectLater(
        first.upload(original, file),
        throwsA(isA<VideoFailure>()),
      );
      expect(received.length, videoChunkBytes);
      expect(original.uploaded, 0); // Reply was lost; local progress is stale.
      first.dispose();

      final second = VideoRepository(
        identity: () => 'owner:session',
        invoke: invoke,
        transport: transport,
      );
      final resumed = VideoUploadTask(
        parentId: original.parentId,
        parentVersion: original.parentVersion,
        purpose: original.purpose,
        identity: original.identity,
        requestKey: original.requestKey,
        expectedBytes: bytes.length,
        fileFingerprint: original.fileFingerprint,
      )..assetId = original.assetId;
      final result = await second.upload(resumed, file);
      expect(result.state, 'processing');
      expect(headOffsets, [0, videoChunkBytes]);
      expect(patchOffsets, [0, videoChunkBytes]);
      expect(received.takeBytes(), orderedEquals(bytes));
      expect(begins.length, 2);
      expect(begins[1], begins[0]);
      expect(resumed.assetId, original.assetId);
      expect(resumed.uploaded, bytes.length);
      second.dispose();
    },
  );
  test('server denial never starts direct provider transport', () async {
    var calls = 0;
    final repo = VideoRepository(
      identity: () => 'owner:session',
      invoke: (_) async => throw const VideoFailure('denied'),
      transport: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    await expectLater(
      repo.upload(task(), XFile.fromData(Uint8List(5))),
      throwsA(isA<VideoFailure>()),
    );
    expect(calls, 0);
    repo.dispose();
  });
  test('owner/session switch during HEAD stops before a PATCH', () async {
    String? scope = 'owner:session';
    var patches = 0;
    final repo = VideoRepository(
      identity: () => scope,
      invoke: (_) async => uploading(),
      transport: MockClient((request) async {
        if (request.method == 'HEAD') {
          scope = 'other:session';
          return http.Response('', 200, headers: {'upload-offset': '0'});
        }
        patches++;
        return http.Response('', 204);
      }),
    );
    await expectLater(
      repo.upload(task(), XFile.fromData(Uint8List(5))),
      throwsA(isA<VideoFailure>()),
    );
    expect(patches, 0);
    repo.dispose();
  });
  test('provisioning unknown never tries creating another request or uploads a file', () async {
    var calls = 0;
    final repo = VideoRepository(
      identity: () => 'owner:session',
      invoke: (_) async => {
        'id': 'asset',
        'upload_state': 'provisioning_unknown',
      },
      transport: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    final work = task();
    await expectLater(
      repo.upload(work, XFile.fromData(Uint8List(5))),
      throwsA(isA<VideoFailure>()),
    );
    expect(work.assetId, 'asset');
    expect(work.requestKey, 'stable-key');
    expect(calls, 0);
    repo.dispose();
  });
  test('cancel while creation is in flight cancels returned asset rather than starting TUS', () async {
    final pending = Completer<Map<String, dynamic>>();
    final operations = <String>[];
    final repo = VideoRepository(
      identity: () => 'owner:session',
      invoke: (body) async {
        operations.add(body['action'] as String);
        if (body['action'] == 'begin') return pending.future;
        return {
          'id': 'asset',
          'technical_state': 'canceled',
          'moderation_state': 'pending',
        };
      },
      transport: MockClient((_) async => throw StateError('must not upload')),
    );
    final work = task();
    final upload = repo.upload(work, XFile.fromData(Uint8List(5)));
    await Future<void>.delayed(Duration.zero);
    await repo.cancel(work);
    pending.complete(uploading());
    await expectLater(upload, throwsA(isA<VideoFailure>()));
    expect(operations, ['begin', 'cancel']);
    repo.dispose();
  });
  test(
    'signed playback authorization cannot return data for a previous session',
    () async {
      var scope = 'owner:session';
      final repo = VideoRepository(
        identity: () => scope,
        invoke: (_) async {
          scope = 'other:session';
          return {
            'hls': 'https://videodelivery.net/secret/manifest/video.m3u8',
            'poster': 'https://videodelivery.net/secret/poster.jpg',
            'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 120,
          };
        },
      );
      await expectLater(repo.playback('asset'), throwsA(isA<VideoFailure>()));
      repo.dispose();
    },
  );
  test('policy metadata allows the same asset/key to resume after repository remount', () async {
    final original = task();
    final payloads = <Map<String, dynamic>>[];
    var offset = 0;
    Future<Map<String, dynamic>> invoke(Map<String, dynamic> body) async {
      payloads.add(body);
      return body['action'] == 'begin'
          ? uploading()
          : {
              'id': 'asset',
              'technical_state': 'processing',
              'moderation_state': 'pending',
            };
    }

    final transport = MockClient((request) async {
      if (request.method == 'HEAD') {
        return http.Response('', 200, headers: {'upload-offset': '$offset'});
      }
      offset += request.bodyBytes.length;
      return http.Response('', 204, headers: {'upload-offset': '$offset'});
    });
    final first = VideoRepository(
      identity: () => 'owner:session',
      invoke: invoke,
      transport: transport,
    );
    final file = XFile.fromData(Uint8List(5));
    await first.upload(original, file);
    first.dispose();
    final second = VideoRepository(
      identity: () => 'owner:session',
      invoke: invoke,
      transport: transport,
      policyInvoke: (_) async => {
        'enabled': true,
        'thanks_required': true,
        'assets': [
          {
            'id': 'asset',
            'parent_id': 'parent',
            'parent_version': 2,
            'purpose': 'thanks',
            'technical_state': 'uploading',
            'moderation_state': 'pending',
            'request_key': original.requestKey,
            'bytes': 5,
            'file_fingerprint': original.fileFingerprint,
          },
        ],
      },
    );
    final policy = await second.policy('parent');
    final row = policy.assets.single;
    final resumed = VideoUploadTask(
      parentId: 'parent',
      parentVersion: row['parent_version'] as int,
      purpose: 'thanks',
      identity: 'owner:session',
      requestKey: row['request_key'] as String,
      expectedBytes: row['bytes'] as int,
      fileFingerprint: row['file_fingerprint'] as String,
    )..assetId = 'asset';
    await second.upload(resumed, file);
    expect(
      payloads
          .where((p) => p['action'] == 'begin')
          .map((p) => p['request_key'])
          .toList(),
      ['stable-key', 'stable-key'],
    );
    expect(offset, 5);
    second.dispose();
  });
  test(
    'resuming validates the exact file digest rather than size alone',
    () async {
      var requests = 0;
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (_) async {
          requests++;
          return uploading();
        },
      );
      final resumed = VideoUploadTask(
        parentId: 'parent',
        parentVersion: 2,
        purpose: 'thanks',
        identity: 'owner:session',
        expectedBytes: 5,
        fileFingerprint: List.filled(64, 'a').join(),
      );
      await expectLater(
        repo.upload(resumed, XFile.fromData(Uint8List(5))),
        throwsA(isA<VideoFailure>()),
      );
      expect(requests, 0);
      repo.dispose();
    },
  );
}
