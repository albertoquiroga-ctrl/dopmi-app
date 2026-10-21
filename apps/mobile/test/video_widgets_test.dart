import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/core/media/moderated_video.dart';

void main() {
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
              onReady: (_) => ready++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Elegir video'));
      await tester.pumpAndSettle();
      const pending =
          'La carga se recibió. Falta comprobar el estado del video.';
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
              onReady: (_) => ready++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Elegir video'));
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
    'failed cancellation after ready keeps its error rather than asking for hidden status control',
    (tester) async {
      final repo = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          if (body['action'] == 'cancel')
            throw const VideoFailure('request_denied');
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
              onReady: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Elegir video'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Video procesado.'), findsOneWidget);
      await tester.tap(find.text('Cancelar video'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No pudimos completar la carga.'),
        findsOneWidget,
      );
      expect(find.textContaining('La carga se recibió.'), findsNothing);
      expect(find.text('Comprobar video'), findsNothing);
      expect(find.text('Cancelar video'), findsOneWidget);
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
