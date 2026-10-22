import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/core/media/moderated_video.dart';

import 'support/local_video_controller.dart';

class MutableLocalFile extends XFile {
  MutableLocalFile() : super('synthetic-local-selection');
  List<int> bytes = [1, 2, 3, 4, 5];
  int reportedLength = 5;
  @override
  Future<int> length() async => reportedLength;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) =>
      Stream.value(Uint8List.fromList(bytes.sublist(start ?? 0, end)));
}

void main() {
  testWidgets(
    'rehydrated upload reviews same file and preserves original resource contract',
    (tester) async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final fingerprint = sha256.convert(bytes).toString();
      final operations = <Map<String, dynamic>>[];
      final ready = <VideoAsset>[];
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          operations.add(Map.of(body));
          if (body['action'] == 'begin') {
            return {
              'id': 'original-asset',
              'technical_state': 'uploading',
              'upload_url': 'https://upload.videodelivery.net/test',
            };
          }
          return {'id': 'original-asset', 'technical_state': 'ready'};
        },
        transport: MockClient(
          (request) async => http.Response(
            '',
            request.method == 'HEAD' ? 200 : 204,
            headers: {'upload-offset': request.method == 'HEAD' ? '0' : '5'},
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 2,
              purpose: 'thanks',
              initialAssets: [
                {
                  'id': 'original-asset',
                  'parent_id': 'case',
                  'parent_version': 1,
                  'purpose': 'thanks',
                  'technical_state': 'uploading',
                  'moderation_state': 'pending',
                  'request_key': 'original-key',
                  'bytes': 5,
                  'file_fingerprint': fingerprint,
                },
              ],
              picker: (_) async => XFile.fromData(bytes),
              previewControllerFactory: (_) => LocalVideoTestController(),
              onReady: ready.add,
            ),
          ),
        ),
      );
      expect(find.text('Subir video'), findsNothing);
      await tester.tap(find.text('Elegir mismo video para reanudar'));
      await tester.pumpAndSettle();
      expect(operations, isEmpty);
      await tester.tap(find.text('Subir video'));
      await tester.pumpAndSettle();
      expect(operations.where((body) => body['action'] == 'begin'), [
        {
          'action': 'begin',
          'parent_id': 'case',
          'parent_version': 1,
          'purpose': 'thanks',
          'request_key': 'original-key',
          'bytes': 5,
          'file_fingerprint': fingerprint,
        },
      ]);
      expect(operations.last, {'action': 'status', 'id': 'original-asset'});
      expect(ready.single.id, 'original-asset');
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );

  for (final oversized in [false, true]) {
    testWidgets(
      oversized
          ? 'oversized selection never initializes preview or calls server'
          : 'changed local file after review is rejected before server creation',
      (tester) async {
        final selected = MutableLocalFile();
        var calls = 0;
        var previews = 0;
        final repo = VideoRepository(
          identity: () => 'owner:session',
          invoke: (_) async {
            calls++;
            throw const VideoFailure('unexpected_request');
          },
        );
        try {
          if (oversized) selected.reportedLength = videoMaxBytes + 1;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: VideoUpload(
                  repository: repo,
                  parentId: 'case',
                  parentVersion: 2,
                  purpose: 'thanks',
                  picker: (_) async => selected,
                  previewControllerFactory: (_) {
                    previews++;
                    return LocalVideoTestController();
                  },
                  onReady: (_) {},
                ),
              ),
            ),
          );
          await tester.tap(find.text('Elegir video'));
          await tester.pumpAndSettle();
          if (oversized) {
            expect(previews, 0);
            expect(find.text('Subir video'), findsNothing);
          } else {
            expect(previews, 1);
            selected.bytes = [5, 4, 3, 2, 1];
            await tester.tap(find.text('Subir video'));
            await tester.pumpAndSettle();
          }
          expect(calls, 0);
        } finally {
          await tester.pumpWidget(const SizedBox());
          repo.dispose();
        }
      },
    );
  }

  for (final source in ImageSource.values) {
    testWidgets('$source requires explicit upload after local review', (
      tester,
    ) async {
      final operations = <String>[];
      final pending = Completer<Map<String, dynamic>>();
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) {
          operations.add(body['action'] as String);
          return pending.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 2,
              purpose: 'thanks',
              picker: (selected) async {
                expect(selected, source);
                return XFile.fromData(Uint8List(5));
              },
              previewControllerFactory: (_) => LocalVideoTestController(),
              onReady: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(
        find.text(
          source == ImageSource.camera ? 'Grabar video' : 'Elegir video',
        ),
      );
      await tester.pumpAndSettle();
      expect(operations, isEmpty);
      await tester.tap(find.text('Subir video'));
      await tester.pump();
      expect(operations, ['begin']);
      expect(find.text('Subir video'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      pending.completeError(const VideoFailure('request_denied'));
      await tester.pump();
      repo.dispose();
    });
  }

  testWidgets('identity change discards local review without server calls', (
    tester,
  ) async {
    var identity = 'owner:session';
    var calls = 0;
    final changes = StreamController<void>.broadcast();
    final controller = LocalVideoTestController();
    final repo = VideoRepository(
      identity: () => identity,
      identityChanges: changes.stream,
      invoke: (_) async {
        calls++;
        throw const VideoFailure('unexpected_request');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoUpload(
            repository: repo,
            parentId: 'case',
            parentVersion: 2,
            purpose: 'thanks',
            picker: (_) async => XFile.fromData(Uint8List(5)),
            previewControllerFactory: (_) => controller,
            onReady: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Elegir video'));
    await tester.pumpAndSettle();
    identity = 'other:session';
    changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Subir video'), findsNothing);
    expect(find.text('Elegir video'), findsOneWidget);
    expect(controller.disposed, isTrue);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    await changes.close();
    repo.dispose();
  });

  testWidgets(
    'choosing a local video and discarding it never contacts the server',
    (tester) async {
      final operations = <Map<String, dynamic>>[];
      var changes = 0;
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          operations.add(Map.of(body));
          throw const VideoFailure('unexpected_request');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 2,
              purpose: 'thanks',
              picker: (_) async => XFile.fromData(Uint8List(5)),
              previewControllerFactory: (_) => LocalVideoTestController(),
              onReady: (_) {},
              onChanged: (_) => changes++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Elegir video'));
      await tester.pumpAndSettle();
      expect(operations, isEmpty);
      expect(changes, 0);
      expect(find.text('Descartar selección'), findsOneWidget);
      await tester.tap(find.text('Descartar selección'));
      await tester.pumpAndSettle();
      expect(operations, isEmpty);
      expect(changes, 0);
      expect(find.text('Elegir video'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets(
    'accepted bytes with unavailable status offer checking without another upload',
    (tester) async {
      final operations = <Map<String, dynamic>>[];
      final methods = <String>[];
      var statusAttempts = 0;
      var ready = 0;
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          operations.add(Map.of(body));
          if (body['action'] == 'begin') {
            return {
              'id': 'same-asset',
              'technical_state': 'uploading',
              'upload_url': 'https://upload.videodelivery.net/test',
            };
          }
          if (++statusAttempts <= 2) throw const VideoFailure('request_denied');
          return {'id': 'same-asset', 'technical_state': 'ready'};
        },
        transport: MockClient((request) async {
          methods.add(request.method);
          return http.Response(
            '',
            request.method == 'HEAD' ? 200 : 204,
            headers: {'upload-offset': request.method == 'HEAD' ? '0' : '5'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 2,
              purpose: 'thanks',
              picker: (_) async => XFile.fromData(Uint8List(5)),
              previewControllerFactory: (_) => LocalVideoTestController(),
              onReady: (_) => ready++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Elegir video'));
      await tester.pumpAndSettle();
      const pending =
          'La carga se recibió. Falta comprobar el estado del video.';
      await tester.tap(find.text('Subir video'));
      await tester.pumpAndSettle();
      expect(find.text(pending), findsOneWidget);
      expect(find.text('Reintentar carga'), findsNothing);
      expect(find.textContaining('Video procesado.'), findsNothing);
      expect(ready, 0);
      await tester.tap(find.text('Comprobar video'));
      await tester.pumpAndSettle();
      expect(find.text(pending), findsOneWidget);
      await tester.tap(find.text('Comprobar video'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Video procesado.'), findsOneWidget);
      expect(ready, 1);
      expect(methods, ['HEAD', 'PATCH']);
      expect(operations.where((op) => op['action'] == 'begin').length, 1);
      expect(operations.first['request_key'], isNotEmpty);
      expect(
        operations.skip(1).every((op) => op['id'] == 'same-asset'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets(
    'interrupted bytes retain retry using the same resource and request key',
    (tester) async {
      final keys = <String>[];
      var interrupted = true;
      var ready = 0;
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          if (body['action'] == 'begin') {
            keys.add(body['request_key'] as String);
            return {
              'id': 'same-asset',
              'technical_state': 'uploading',
              'upload_url': 'https://upload.videodelivery.net/test',
            };
          }
          return {'id': 'same-asset', 'technical_state': 'processing'};
        },
        transport: MockClient((request) async {
          if (request.method == 'HEAD') {
            return http.Response('', 200, headers: {'upload-offset': '0'});
          }
          if (interrupted) throw const VideoFailure('upload_interrupted');
          return http.Response('', 204, headers: {'upload-offset': '5'});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 2,
              purpose: 'thanks',
              picker: (_) async => XFile.fromData(Uint8List(5)),
              previewControllerFactory: (_) => LocalVideoTestController(),
              onReady: (_) => ready++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Elegir video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir video'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No pudimos completar la carga.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar carga'), findsOneWidget);
      expect(find.textContaining('La carga se recibió.'), findsNothing);
      interrupted = false;
      await tester.tap(find.text('Reintentar carga'));
      await tester.pumpAndSettle();
      expect(find.text('Estamos procesando tu video.'), findsOneWidget);
      expect(keys, hasLength(2));
      expect(keys.last, keys.first);
      expect(ready, 0);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets(
    'unconfirmed cancellation after ready offers cancellation reconciliation without upload or replacement',
    (tester) async {
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          if (body['action'] == 'cancel') {
            throw const VideoFailure('request_denied');
          }
          if (body['action'] == 'begin') {
            return {
              'id': 'same-asset',
              'technical_state': 'uploading',
              'upload_url': 'https://upload.videodelivery.net/test',
            };
          }
          return {'id': 'same-asset', 'technical_state': 'ready'};
        },
        transport: MockClient(
          (request) async => http.Response(
            '',
            request.method == 'HEAD' ? 200 : 204,
            headers: {'upload-offset': request.method == 'HEAD' ? '0' : '5'},
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 2,
              purpose: 'thanks',
              picker: (_) async => XFile.fromData(Uint8List(5)),
              previewControllerFactory: (_) => LocalVideoTestController(),
              onReady: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Elegir video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir video'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Video procesado.'), findsOneWidget);
      await tester.tap(find.text('Cancelar video'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No pudimos confirmar la cancelación. Comprueba su estado antes de elegir otro video.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('No pudimos completar la carga.'),
        findsNothing,
      );
      expect(find.textContaining('La carga se recibió.'), findsNothing);
      expect(find.textContaining('Video procesado.'), findsNothing);
      expect(find.text('Comprobar cancelación'), findsOneWidget);
      expect(find.text('Reintentar cancelación'), findsOneWidget);
      expect(find.text('Reintentar carga'), findsNothing);
      expect(find.text('Elegir video'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets(
    'failed authorization offers retry without constructing a decoder or calling readiness',
    (tester) async {
      var ready = 0;
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (_) async => throw const VideoFailure('denied'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeratedVideo(
              repository: repo,
              assetId: 'private',
              onPlaybackReady: () => ready++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('No pudimos reproducir'), findsOneWidget);
      expect(ready, 0);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets(
    'upload controls require session and never send server requests merely by mounting',
    (tester) async {
      var calls = 0;
      final repo = VideoRepository(
        identity: () => null,
        invoke: (_) async {
          calls++;
          throw const VideoFailure('denied');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repo,
              parentId: 'case',
              parentVersion: 1,
              purpose: 'thanks',
              onReady: (_) {},
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Grabar video'),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
}
