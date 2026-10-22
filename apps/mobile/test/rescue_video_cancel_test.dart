import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  for (final status in ['canceled', 'deleted']) {
    testWidgets(
      'lost cancellation ACK clears restored asset only after authoritative $status',
      (tester) async {
        final operations = <Map<String, dynamic>>[];
        final changes = <VideoAsset?>[];
        final pendingEvents = <String?>[];
        var statusReads = 0;
        final repository = VideoRepository(
          identity: () => 'owner:session',
          invoke: (data) async {
            operations.add(Map.of(data));
            if (data['action'] == 'cancel') {
              throw const VideoFailure('request_denied');
            }
            return {
              'id': 'restored',
              'technical_state': ++statusReads == 1 ? 'ready' : status,
            };
          },
        );
        addTearDown(repository.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoUpload(
                repository: repository,
                parentId: 'case',
                parentVersion: 1,
                purpose: 'thanks',
                initialAssets: const [
                  {
                    'id': 'restored',
                    'parent_id': 'case',
                    'parent_version': 1,
                    'purpose': 'thanks',
                    'technical_state': 'ready',
                    'moderation_state': 'pending',
                    'request_key': 'stable-key',
                    'bytes': 3,
                  },
                ],
                onReady: (_) =>
                    fail('Cancel reconciliation must not announce readiness'),
                onChanged: changes.add,
                onCancellationPendingChanged: pendingEvents.add,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Cancelar video'));
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
        expect(pendingEvents, ['restored']);
        expect(find.textContaining('Video procesado.'), findsNothing);
        expect(find.text('Comprobar cancelación'), findsOneWidget);
        expect(find.text('Reintentar cancelación'), findsOneWidget);
        expect(find.text('Elegir video'), findsNothing);
        await tester.tap(find.text('Comprobar cancelación'));
        await tester.pumpAndSettle();
        expect(changes, [null]);
        expect(pendingEvents, ['restored', null]);
        expect(find.text('Elegir video'), findsOneWidget);
        expect(find.text('Comprobar cancelación'), findsNothing);
        expect(operations, [
          {'action': 'cancel', 'id': 'restored'},
          {'action': 'status', 'id': 'restored'},
          {'action': 'status', 'id': 'restored'},
        ]);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'failed cancellation status keeps the asset pending and offers read-only checking',
    (tester) async {
      final operations = <Map<String, dynamic>>[],
          changes = <VideoAsset?>[],
          pendingEvents = <String?>[];
      final repository = VideoRepository(
        identity: () => 'owner:session',
        invoke: (data) async {
          operations.add(Map.of(data));
          throw const VideoFailure('request_denied');
        },
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoUpload(
              repository: repository,
              parentId: 'case',
              parentVersion: 1,
              purpose: 'thanks',
              initialAssets: const [
                {
                  'id': 'restored',
                  'parent_id': 'case',
                  'parent_version': 1,
                  'purpose': 'thanks',
                  'technical_state': 'ready',
                  'moderation_state': 'pending',
                  'request_key': 'stable-key',
                  'bytes': 3,
                },
              ],
              onReady: (_) =>
                  fail('Pending cancellation cannot report readiness'),
              onChanged: changes.add,
              onCancellationPendingChanged: pendingEvents.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cancelar video'));
      await tester.pumpAndSettle();
      expect(find.text('Comprobar cancelación'), findsOneWidget);
      expect(find.text('Reintentar cancelación'), findsNothing);
      expect(find.text('Elegir video'), findsNothing);
      expect(find.text('Reintentar carga'), findsNothing);
      await tester.tap(find.text('Comprobar cancelación'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(pendingEvents, ['restored']);
      expect(operations, [
        {'action': 'cancel', 'id': 'restored'},
        {'action': 'status', 'id': 'restored'},
        {'action': 'status', 'id': 'restored'},
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'canceling a restored asset permits a fresh replacement despite stale policy data',
    (tester) async {
      const oldKey = '00000000-0000-0000-0000-000000000001';
      final calls = <Map<String, dynamic>>[];
      final repository = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          calls.add(Map.of(body));
          if (body['action'] == 'cancel') {
            return {'id': 'restored', 'technical_state': 'canceled'};
          }
          if (body['action'] == 'begin') {
            return {
              'id': 'replacement',
              'technical_state': 'ready',
              'moderation_state': 'pending',
            };
          }
          throw StateError('Unexpected request');
        },
      );
      addTearDown(repository.dispose);
      String? ready;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, rebuild) => VideoUpload(
                key: const ValueKey('same-parent-and-purpose'),
                repository: repository,
                parentId: 'case',
                parentVersion: 1,
                purpose: 'thanks',
                initialAssets: const [
                  {
                    'id': 'restored',
                    'parent_id': 'case',
                    'parent_version': 1,
                    'purpose': 'thanks',
                    'technical_state': 'uploading',
                    'moderation_state': 'pending',
                    'request_key': oldKey,
                    'bytes': 3,
                  },
                ],
                picker: (_) async => XFile.fromData(
                  Uint8List.fromList([1, 2, 3]),
                  name: 'replacement.mp4',
                ),
                onChanged: (_) => rebuild(() {}),
                onReady: (asset) => ready = asset.id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elegir mismo video para reanudar'), findsOneWidget);
      await tester.tap(find.text('Cancelar video'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir mismo video para reanudar'), findsNothing);
      expect(find.text('Elegir video'), findsOneWidget);
      await tester.tap(find.text('Elegir video'));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call['action'] == 'cancel').single['id'],
        'restored',
      );
      expect(
        calls.where((call) => call['action'] == 'begin').single['request_key'],
        isNot(oldKey),
      );
      expect(ready, 'replacement');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
