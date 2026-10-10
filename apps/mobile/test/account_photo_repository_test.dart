import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const actor = '70000000-0000-4000-8000-000000000001';
const other = '70000000-0000-4000-8000-000000000002';
const path = '$actor/$actor/73000000-0000-4000-8000-000000000001.jpg';

void main() {
  test('lost save response reads the same private path without uploading or posting again', () async {
    final calls = <String>[];
    final repo = AccountPhotoRepository(
      owner: () => actor,
      rpc: (name, params) async {
        calls.add(name);
        if (name == 'dopmi_save_account_photo') {
          expect(params, {'photo_path': path});
          throw const SocketException('response lost');
        }
        return {'photo_path': path};
      },
      upload: (_, _) async => throw StateError('unexpected upload'),
      sign: (_) async => 'signed',
    );
    await repo.savePath(path);
    expect(calls, ['dopmi_save_account_photo', 'dopmi_my_account_photo']);
  });
  test(
    'missing receipt and SQL rejection never claim the photo was saved',
    () async {
      var reads = 0;
      var forbidden = false;
      final repo = AccountPhotoRepository(
        owner: () => actor,
        rpc: (name, _) async {
          if (name == 'dopmi_save_account_photo') {
            if (forbidden) {
              throw const PostgrestException(message: 'denied', code: '42501');
            }
            throw const SocketException('response lost');
          }
          reads++;
          return null;
        },
        upload: (_, _) async => path,
        sign: (_) async => 'signed',
      );
      await expectLater(repo.savePath(path), throwsA(isA<SocketException>()));
      expect(reads, 1);
      forbidden = true;
      await expectLater(
        repo.savePath(path),
        throwsA(isA<PostgrestException>()),
      );
      expect(reads, 1);
    },
  );
  test(
    'foreign paths and a session switch discard pending private results',
    () async {
      var owner = actor;
      final pending = Completer<dynamic>();
      final repo = AccountPhotoRepository(
        owner: () => owner,
        rpc: (_, _) => pending.future,
        upload: (id, bytes) async {
          expect(id, actor);
          return path;
        },
        sign: (_) async => 'signed',
      );
      await expectLater(
        repo.signedUrl(path.replaceAll(actor, other)),
        throwsStateError,
      );
      expect(await repo.uploadPhoto(Uint8List.fromList([1, 2])), path);
      final loading = repo.loadPath();
      owner = other;
      pending.complete({'photo_path': path});
      await expectLater(loading, throwsStateError);
    },
  );
}
