import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_account_photo_repository.dart';
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;
import 'rescue_test.dart' show FakeRescue;

void main() {
  final aliases = {
    '/saved-rescuers': '/profile',
    '/saved?kind=rescuer': '/saved',
    '/profile/basic-info': '/basic-info',
    '/settings/basic-info': '/basic-info',
    '/profile/payment-methods': '/settings/payment-methods',
    '/profile/payment-method/success': '/settings/payment-methods',
    '/settings/payment-method/success': '/settings/payment-methods',
    '/profile/billing': '/guardian',
    '/settings/billing': '/guardian',
    '/rescuer/account': '/settings/account',
    '/rescuer/settings': '/settings/account',
  };
  final scenarios = [
    for (final alias in aliases.entries)
      (path: alias.key, target: alias.value, verified: true, expired: false),
    for (final path in ['/profile/billing', '/settings/billing']) ...[
      (path: path, target: '/guardian', verified: false, expired: false),
      (path: path, target: '/guardian', verified: true, expired: true),
    ],
    (
      path: '/profile/basic-info',
      target: '/welcome',
      verified: false,
      expired: false,
    ),
    (
      path: '/profile/basic-info',
      target: '/consent',
      verified: true,
      expired: true,
    ),
  ];
  for (final scenario in scenarios) {
    testWidgets('account link $scenario reads without payment mutation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final identity = FakeIdentityRepository()
        ..user = Identity(
          'one',
          'fixture@example.test',
          verified: scenario.verified,
        );
      if (scenario.expired) {
        identity.profile = const Profile(
          id: 'one',
          name: 'Ana',
          phone: '',
          city: '',
          mode: 'donor',
          intent: 'adopt',
          status: 'active',
          termsVersion: 'expired',
        );
      }
      final guardian = FakeGuardian();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          accountPhotoRepositoryProvider.overrideWithValue(
            emptyAccountPhotoRepository(identity),
          ),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          guardianRepositoryProvider.overrideWithValue(guardian),
          routerInitialLocationProvider.overrideWithValue(scenario.path),
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
      expect(
        container.read(routerProvider).state.uri.toString(),
        scenario.target,
      );
      expect(guardian.calls, isEmpty);
      expect(guardian.opened, 0);
      if (scenario.verified &&
          !scenario.expired &&
          scenario.target != '/profile' &&
          scenario.target != '/saved') {
        final router = container.read(routerProvider);
        router.go('/profile');
        await tester.pumpAndSettle();
        // Opening an old link from a profile preserves its actual return page.
        router.push(scenario.path);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, scenario.target);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/profile');
        expect(guardian.calls, isEmpty);
        expect(guardian.opened, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
