import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class AvatarCommunity extends FakeCommunity {
  @override
  Future<Json?> publicProfile(String id) async => {
    'id': id,
    'name': 'Refugio Luna',
    'bio': 'Rescate responsable.',
    'city': 'Monterrey',
    'region': 'MX',
    'avatar_path': 'owner/approved-avatar.jpg',
    'activity': <Json>[],
    'adoptions': <Json>[],
    'cases': <Json>[],
  };
}

class UnavailableAvatar extends FakeRescuerProfile {
  final paths = <String>[];
  @override
  Future<String> avatarUrl(String path) async {
    paths.add(path);
    throw const FormatException('Unavailable');
  }
}

void main() {
  testWidgets('public avatar can retry and renews approved URL on resume', (
    tester,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final avatar = UnavailableAvatar();
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(AvatarCommunity()),
        rescuerProfileRepositoryProvider.overrideWithValue(avatar),
        routerInitialLocationProvider.overrideWithValue('/people/owner'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(avatar.paths.length, 2);
    expect(find.text('R'), findsOneWidget);
    await tester.tap(find.byTooltip('Reintentar foto de perfil'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(avatar.paths.length, 4);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(avatar.paths.length, 6);
    expect(avatar.paths.toSet(), {'owner/approved-avatar.jpg'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(avatar.paths.length, 6);
    expect(tester.takeException(), isNull);
  });
}
