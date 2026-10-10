import 'dart:convert';
import 'dart:io';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'case_publication_test.dart' show DraftCaseRescue;

class RecoverCaseRescue extends DraftCaseRescue {
  RecoverCaseRescue(this.owner, this.status);
  final String owner, status;
  int uploads = 0;
  List<Json>? savedFiles;
  @override
  Future<Json> detail(String id) async {
    final data = await super.detail(id);
    (data['record'] as Json)['owner_id'] = owner;
    (data['record'] as Json)['status'] = status;
    return data;
  }

  @override
  Future<String> upload(
    String record,
    Uint8List bytes, {
    required bool pdf,
  }) async {
    expect(pdf, isFalse);
    uploads++;
    return 'one/case-one/recovered.jpg';
  }

  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    savedFiles = files;
    return super.save(
      kind,
      publicData,
      privateData,
      files,
      record: record,
      parent: parent,
    );
  }
}

void main() {
  testWidgets(
    'native lost selection from another actor is never consumed for the current draft',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        pendingPhotoKey('one'): 'rescue:case-one',
        pendingPhotoActorKey: 'two',
      });
      var reads = 0;
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        reads++;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final lost = await container.read(lostPhotoProvider('one').future);
      debugDefaultTargetPlatformOverride = null;
      expect(lost!.postId, 'case-one');
      expect(lost.rescue, isTrue);
      expect(lost.files, isEmpty);
      expect(reads, 0);
      expect(
        (await SharedPreferences.getInstance()).getString(pendingPhotoActorKey),
        'two',
      );
    },
  );
  for (final scenario in [
    ('one', 'draft'),
    ('two', 'draft'),
    ('one', 'submitted'),
  ]) {
    testWidgets('case recovery checks owner and editable state: $scenario', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        pendingPhotoKey('one'): 'rescue:case-one',
      });
      final directory = Directory.systemTemp.createTempSync(
        'dopmi-case-recovery-',
      );
      final file = File('${directory.path}/photo.png');
      file.writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR3sAAAAASUVORK5CYII=',
        ),
      );
      addTearDown(() {
        file.deleteSync();
        directory.deleteSync();
      });
      final repo = RecoverCaseRescue(scenario.$1, scenario.$2);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: PhotoRecoveryNotice()),
          ),
          GoRoute(
            path: '/rescue/:id',
            builder: (_, _) =>
                const Scaffold(body: Text('Expediente recuperado')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(repo),
            lostPhotoProvider('one').overrideWith(
              (ref) async =>
                  LostPhoto('case-one', [XFile(file.path)], rescue: true),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      // Await the actual async recovery, including real file I/O, rather than
      // assuming that a fixed wall-clock delay finished it under suite load.
      final recover =
          tester.widget<ActionButton>(find.byType(ActionButton)).onPressed!
              as Future<void> Function();
      await tester.runAsync(recover);
      await tester.pumpAndSettle();
      final own = scenario.$1 == 'one';
      expect(repo.uploads, own && scenario.$2 == 'draft' ? 1 : 0);
      expect(repo.saveCalls, own && scenario.$2 == 'draft' ? 1 : 0);
      if (own && scenario.$2 == 'draft') {
        expect(repo.savedFiles!.last, {
          'role': 'public',
          'path': 'one/case-one/recovered.jpg',
        });
      }
      expect(
        find.text('Expediente recuperado'),
        own ? findsOneWidget : findsNothing,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          pendingPhotoKey('one'),
        ),
        own ? isNull : 'rescue:case-one',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
