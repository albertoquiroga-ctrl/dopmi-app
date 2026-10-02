import 'dart:async';
import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/fixture_photo_client.dart';
import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class PublishedCommunity extends FakeCommunity {
  bool visible = true, fail = false, wrongOwner = false;
  String? avatarPath;
  final requested = <String>[];
  @override
  Future<Json?> publicProfile(String id) async {
    requested.add(id);
    if (fail) throw const FormatException('Offline');
    if (!visible) return null;
    return {
      'avatar_path': avatarPath,
      'id': wrongOwner ? 'other' : id,
      'name': wrongOwner ? 'Nombre ajeno' : 'Nombre público aprobado',
      'city': 'Monterrey',
      'region': 'Nuevo León',
      'bio': 'Descripción aprobada.',
      'draft_bio': 'Texto privado no aprobado',
      'email': 'private-fixture@example.test',
    };
  }
}

class PublishedAvatar extends FakeRescuerProfile {
  bool fail = true;
  final paths = <String>[];
  @override
  Future<String> avatarUrl(String path) async {
    paths.add(path);
    if (fail) throw const FormatException('No disponible');
    return 'https://example.test/approved-avatar';
  }
}

void main() {
  testWidgets(
    'owner contacts come from the current account and disappear on logout',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'one',
          'owner-contact@example.test',
          verified: true,
        );
      await identity.saveProfile(
        name: 'Ana',
        phone: '+52 55 0000 0000',
        city: 'Monterrey',
      );
      await identity.setExperience('rescuer');
      final community = PublishedCommunity();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(community),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          routerInitialLocationProvider.overrideWithValue('/profile'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('owner-contact@example.test'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('+52 55 0000 0000'), findsOneWidget);
      expect(find.text('private-fixture@example.test'), findsNothing);
      identity.emit(
        const IdentityEvent(
          Identity('one', 'updated-contact@example.test', verified: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('owner-contact@example.test'), findsNothing);
      expect(find.text('updated-contact@example.test'), findsOneWidget);
      await container.read(identityControllerProvider).logout();
      await tester.pumpAndSettle();
      expect(find.text('+52 55 0000 0000', skipOffstage: false), findsNothing);
      expect(
        find.text('updated-contact@example.test', skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('approved avatar retries signing and disappears on withdrawal', (
    tester,
  ) async {
    final photo = await tester.runAsync(
      () => File('assets/onboarding/account-rescue.jpg').readAsBytes(),
    );
    final previousClient = debugNetworkImageHttpClientProvider;
    PaintingBinding.instance.imageCache.clear();
    debugNetworkImageHttpClientProvider = () => FixturePhotoClient(photo!);
    addTearDown(() {
      debugNetworkImageHttpClientProvider = previousClient;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    final community = PublishedCommunity()..avatarPath = 'one/approved.jpg';
    final avatar = PublishedAvatar();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider.overrideWithValue(community),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          rescuerProfileRepositoryProvider.overrideWithValue(avatar),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RescuerProfileHero(FakeIdentityRepository().profile),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nombre público aprobado'), findsOneWidget);
    expect(find.text('Verificado'), findsOneWidget);
    expect(find.text('Reintentar foto de perfil'), findsOneWidget);
    expect(find.byKey(const ValueKey('rescuer-profile-avatar')), findsNothing);
    expect(avatar.paths, ['one/approved.jpg']);
    await tester.runAsync(() async {
      final ready = Completer<void>();
      final stream = const NetworkImage('https://example.test/approved-avatar')
          .resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, synchronous) => ready.complete(),
        onError: (Object error, StackTrace? stack) =>
            ready.completeError(error, stack),
      );
      stream.addListener(listener);
      try {
        await ready.future.timeout(const Duration(seconds: 10));
      } finally {
        stream.removeListener(listener);
      }
    });
    debugNetworkImageHttpClientProvider = previousClient;
    avatar.fail = false;
    await tester.ensureVisible(find.text('Reintentar foto de perfil'));
    await tester.tap(find.text('Reintentar foto de perfil'));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('rescuer-profile-avatar')),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://example.test/approved-avatar',
    );
    expect(image.width, 72);
    expect(image.height, 72);
    expect(image.fit, BoxFit.cover);
    expect(image.errorBuilder, isNotNull);
    await tester.pumpAndSettle();
    final rendered = find.descendant(
      of: find.byKey(const ValueKey('rescuer-profile-avatar')),
      matching: find.byType(RawImage),
    );
    expect(rendered, findsOneWidget);
    final renderImage = tester.renderObject<RenderImage>(rendered);
    expect(renderImage.image, isNotNull);
    expect(renderImage.image!.width, greaterThan(0));
    expect(renderImage.image!.height, greaterThan(0));
    expect(renderImage.size, const Size(72, 72));
    expect(renderImage.fit, BoxFit.cover);
    expect(
      find.ancestor(of: rendered, matching: find.byType(ClipOval)),
      findsOneWidget,
    );

    expect(find.text('Reintentar foto de perfil'), findsNothing);
    expect(avatar.paths, ['one/approved.jpg', 'one/approved.jpg']);
    community.visible = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rescuer-profile-avatar')), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(avatar.paths.length, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'withdrawal removes public identity and biography without reading private draft fields',
    (tester) async {
      final community = PublishedCommunity();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityRepositoryProvider.overrideWithValue(community),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RescuerProfileHero(FakeIdentityRepository().profile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nombre público aprobado'), findsOneWidget);
      expect(find.text('Descripción aprobada.'), findsOneWidget);
      expect(find.text('Texto privado no aprobado'), findsNothing);
      expect(find.text('private-fixture@example.test'), findsNothing);
      expect(community.requested, ['one']);
      community.visible = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Nombre público aprobado'), findsNothing);
      expect(find.text('Descripción aprobada.'), findsNothing);
      expect(find.text('Sobre ti'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final mismatch in [false, true]) {
    testWidgets(
      'public read error or owner mismatch preserves valid dashboard and permits retry: $mismatch',
      (tester) async {
        final community = PublishedCommunity()
          ..wrongOwner = mismatch
          ..fail = !mismatch;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityRepositoryProvider.overrideWithValue(community),
              rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RescuerProfileHero(FakeIdentityRepository().profile),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Verificado'), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('Nombre ajeno'), findsNothing);
        expect(find.text('Descripción aprobada.'), findsNothing);
        community.fail = false;
        community.wrongOwner = false;
        await tester.ensureVisible(find.text('Reintentar perfil público'));
        await tester.tap(find.text('Reintentar perfil público'));
        await tester.pumpAndSettle();
        expect(find.text('Nombre público aprobado'), findsOneWidget);
        expect(find.text('Descripción aprobada.'), findsOneWidget);
        expect(community.requested, ['one', 'one']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
