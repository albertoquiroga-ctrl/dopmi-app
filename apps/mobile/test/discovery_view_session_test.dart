import 'dart:async';

import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/discovery_screen.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart'
    show FakeCommunity, CommunityAnalyticsSpy, CommunityDiagnosticsSpy;
import 'rescue_test.dart' show FakeRescue;
import 'fake_identity_repository.dart';

class ViewSessionCommunity extends FakeCommunity {
  String actor = 'one';
  final views = <String>[];
  @override
  String? get userId => actor;
  @override
  Future<void> recordAdoptionView(String id, {required bool consent}) async {
    views.add('$actor:$id:$consent');
  }
}

void main() {
  for (final change in ['none', 'actor', 'front']) {
    testWidgets('delayed view consent rechecks $change before writing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'dopmi.view-test.one.analytics': true,
      });
      final consent = Completer<void>();
      final measurement = MeasurementController(
        await SharedPreferences.getInstance(),
        'view-test',
        CommunityAnalyticsSpy(),
        CommunityDiagnosticsSpy(),
        adoptionConsent: (_) => consent.future,
      );
      await measurement.owner('one');
      final repository = ViewSessionCommunity();
      repository.discoveryItems = [
        repository.post,
        Adoption({...repository.post.data, 'id': 'next'}),
      ];
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository()
              ..user = const Identity(
                'one',
                'qa@example.invalid',
                verified: true,
              ),
          ),
          communityRepositoryProvider.overrideWithValue(repository),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          measurementControllerProvider.overrideWith((_) => measurement),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DiscoveryScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(DiscoveryScreen));
      final Future<void> pending = state.reportFrontView(repository.post);
      await tester.pump();
      if (change == 'actor') repository.actor = 'other';
      if (change == 'front') state.index = 1;
      consent.complete();
      await pending;
      expect(repository.views, change == 'none' ? ['one:post:true'] : isEmpty);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
