import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets(
    'canceling a restored asset permits a fresh replacement despite stale policy data',
    (tester) async {
      const oldKey = '00000000-0000-0000-0000-000000000001';
      final calls = <Map<String, dynamic>>[];
      final repository = VideoRepository(
        identity: () => 'owner:session',
        invoke: (body) async {
          calls.add(Map.of(body));
          if (body['action'] == 'cancel') return {};
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
