import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config/adoption_only_build.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/discovery_screen.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class _AdoptionOnlyCommunity extends FakeCommunity {
  int supportReads = 0;

  @override
  Future<List<SupportOpportunity>> discoverySupport() async {
    supportReads++;
    throw StateError('Funding is unavailable in the adoption build');
  }
}

void main() {
  test(
    'old payment and storefront links resolve to the adoption experience',
    () {
      for (final path in [
        '/profile/payment-method/success',
        '/settings/billing',
        '/guardian/history',
        '/rescuer/received-payments',
        '/contribute-case/example?amount_cents=10',
        '/rescue-cases/example/updates/new',
        '/rescue/new?kind=expense',
        '/rescue/existing?kind=verification&kind=case',
        '/connect',
        '/impact?history=1',
        '/rescuer/apoya-causa',
      ]) {
        expect(
          adoptionOnlyRouteRedirect(Uri.parse(path)),
          '/home',
          reason: path,
        );
      }
    },
  );

  test(
    'adoption, verification, communication and privacy keep their own routes',
    () {
      for (final path in [
        '/adoptions/pet',
        '/rescue/new?kind=verification',
        '/rescue/existing?kind=verification',
        '/my-cases?program=adoption&status=published',
        '/messages/thread',
        '/notifications',
        '/account-privacy',
        '/privacy-notice',
      ]) {
        expect(
          adoptionOnlyRouteRedirect(Uri.parse(path)),
          isNull,
          reason: path,
        );
      }
      expect(
        adoptionOnlyRouteRedirect(Uri.parse('/publish')),
        '/my-adoptions/new',
      );
      expect(
        adoptionOnlyRouteRedirect(
          Uri.parse('/my-adoptions/new?case=fundraiser'),
        ),
        '/my-adoptions/new',
      );
      expect(
        adoptionOnlyRouteRedirect(Uri.parse('/saved?kind=donation')),
        '/saved',
      );
    },
  );

  testWidgets(
    'adoption build keeps discovery working when opening an old funding link',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final restoring = Completer<Identity?>();
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'adopter@example.test', verified: true)
        ..restoreResult = restoring.future;
      final community = _AdoptionOnlyCommunity();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(community),
          routerInitialLocationProvider.overrideWithValue(
            '/contribute-case/old',
          ),
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
      expect(find.byType(ContributeScreen, skipOffstage: false), findsNothing);
      restoring.complete(identity.user);
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(find.text('Luna'), findsWidgets);
      expect(community.supportReads, 0);

      final semantics = tester.ensureSemantics();
      try {
        expect(find.bySemanticsLabel('Apoyar'), findsNothing);
        expect(find.bySemanticsLabel('Tienda'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
    skip: !adoptionOnlyBuild,
  );
}
