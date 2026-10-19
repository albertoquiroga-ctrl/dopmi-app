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
