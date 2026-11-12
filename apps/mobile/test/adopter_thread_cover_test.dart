import 'package:dopmi_mobile/core/media/media_store.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/core/media/remote_photo.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_ui.dart';
import 'package:dopmi_mobile/features/communication/message_screens.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'community_test.dart' show DetailThreadCommunity;
import 'fake_identity_repository.dart';

class _CoverCommunity extends DetailThreadCommunity {
  _CoverCommunity({this.cover, this.adopter = 'one'});

  final String? cover;
  final String adopter;
  final signedPaths = <String>[];

  @override
  Future<Json> thread(String id) async => {
    ...await super.thread(id),
    'pet_name': 'Luna de las Montañas',
    'participant_name': 'Patricia Hernández',
    'adopter_id': adopter,
    'owner_id': adopter == 'one' ? 'owner' : 'one',
    'photo': cover,
  };

  @override
  Future<String> photoUrl(String path) async {
    signedPaths.add(path);
    return 'https://example.test/cover.png';
  }
}

void main() {
  const coverPath = 'approved/pet/cover.png';
  final cover = find.byKey(const ValueKey('chat-pet-cover'));

  Future<void> openChat(
    WidgetTester tester,
    _CoverCommunity community, {
    bool rescuer = false,
    bool prepareCover = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'qa@example.test', verified: true);
    if (rescuer) await identity.setExperience('rescuer');
    addTearDown(identity.changes.close);

    final bytes = img.encodePng(img.Image(width: 8, height: 8));
    final runtime = (await tester.runAsync(() async {
      final runtime = PhotoRuntime(
        store: MemoryPhotoStore(),
        download: (_, _) async => bytes,
      );
      if (prepareCover) {
        // Decode outside the fake clock before the widget reads the frame.
        await runtime.load(
          adoptionPhotoSource(community, coverPath),
          width: 128,
        );
      }
      return runtime;
    }))!;
    addTearDown(runtime.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(community),
          photoRuntimeProvider.overrideWithValue(runtime),
        ],
        child: MaterialApp(
          theme: dopmiTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: const ThreadScreen('thread-one'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('adopter chat shows the thread cover beside the pet name', (
    tester,
  ) async {
    final community = _CoverCommunity(cover: coverPath);
    await openChat(tester, community, prepareCover: true, textScale: 2);
    final image = find.descendant(
      of: cover,
      matching: find.byType(RemotePhoto),
    );
    final photo = tester.widget<RemotePhoto>(image);
    expect(photo.source.path, coverPath);
    expect(photo.source.purpose, MediaPurpose.adoptionPhoto);
    expect(community.openedPosts, isEmpty);
    expect(
      tester.getTopRight(cover).dx,
      lessThan(tester.getTopLeft(find.text('Luna de las Montañas')).dx),
    );

    final raw = find.descendant(of: cover, matching: find.byType(RawImage));
    final rendered = tester.renderObject<RenderImage>(raw);
    expect(rendered.image, isNotNull);
    expect(rendered.size, const Size.square(40));
    expect(community.signedPaths, [coverPath]);
    expect(find.byTooltip('Ver detalle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adopter chat shows a paw when the thread has no cover', (
    tester,
  ) async {
    final community = _CoverCommunity();
    await openChat(tester, community);
    expect(
      find.descendant(of: cover, matching: find.byIcon(Icons.pets)),
      findsOneWidget,
    );
    expect(community.signedPaths, isEmpty);
    expect(community.openedPosts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a listing owner in adopter mode does not load a private cover', (
    tester,
  ) async {
    final community = _CoverCommunity(cover: coverPath, adopter: 'someone');
    await openChat(tester, community);
    expect(cover, findsNothing);
    expect(community.signedPaths, isEmpty);
    expect(community.openedPosts, isEmpty);
  });

  testWidgets('rescuer mode keeps its chat header without the adopter avatar', (
    tester,
  ) async {
    final community = _CoverCommunity(cover: coverPath);
    await openChat(tester, community, rescuer: true);
    expect(cover, findsNothing);
    expect(community.signedPaths, isEmpty);
  });
}
