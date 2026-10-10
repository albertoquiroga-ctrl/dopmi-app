import 'dart:convert';
import 'dart:typed_data';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show PhotoDraftCommunity;

class RecoverAdoptionCommunity extends PhotoDraftCommunity {
  RecoverAdoptionCommunity(int count) {
    post = Adoption({
      ...post.data,
      'owner_id': 'one',
      'photos': [for (var i = 0; i < count; i++) 'fixture/photo-$i'],
    });
  }
  int uploads = 0;
  @override
  Future<String> uploadPhoto(String id, Uint8List bytes) async {
    expect(id, 'post');
    uploads++;
    return 'one/post/recovered.jpg';
  }
}

void main() {
  for (final count in [5, 6]) {
    testWidgets(
      'recovery permits photo six and does not upload photo seven: existing=$count',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          pendingPhotoKey('one'): 'post',
          pendingPhotoActorKey: 'one',
        });
        final repo = RecoverAdoptionCommunity(count);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: PhotoRecoveryNotice()),
            ),
            GoRoute(
              path: '/my-adoptions/:id',
              builder: (_, _) =>
                  const Scaffold(body: Text('Borrador recuperado')),
            ),
          ],
        );
        addTearDown(router.dispose);
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR3sAAAAASUVORK5CYII=',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityRepositoryProvider.overrideWithValue(repo),
              lostPhotoProvider('one').overrideWith(
                (ref) async => LostPhoto('post', [
                  XFile.fromData(bytes, name: 'recovered.png'),
                ]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recuperar foto y retomar borrador'));
        await tester.pumpAndSettle();
        expect(repo.uploads, count == 5 ? 1 : 0);
        expect(repo.post.photos.length, 6);
        expect(repo.post.photos.first, 'fixture/photo-0');
        expect(
          (await SharedPreferences.getInstance()).getString(
            pendingPhotoKey('one'),
          ),
          isNull,
        );
        expect(find.text('Borrador recuperado'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
