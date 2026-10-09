import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class RefreshOwnerProfile extends FakeRescuerProfile {
  RefreshOwnerProfile() {
    value['owner_id'] = 'one';
  }
  @override
  String? get userId => 'one';
}

class RefreshDashboard extends FakeRescue {
  bool fail = false;
  String status = 'approved';
  int reads = 0;
  @override
  Future<Json> dashboard() async {
    reads++;
    if (fail) throw const FormatException('Sin conexión');
    return {...await super.dashboard(), 'verification_status': status};
  }
}

void main() {
  testWidgets(
    'profile retains identity but discards approval and money on error then retries server status',
    (tester) async {
      final repo = RefreshDashboard();
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'owner@example.test', verified: true);
      addTearDown(() => identity.changes.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            rescuerProfileRepositoryProvider.overrideWithValue(
              RefreshOwnerProfile(),
            ),
            rescueRepositoryProvider.overrideWithValue(repo),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RescuerProfileHero(identity.profile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cuenta verificada'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      repo.status = 'submitted';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Cuenta verificada'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
      repo.fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Cuenta verificada'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text(r'$50'), findsNothing);
      expect(find.text('Verificación no disponible'), findsOneWidget);
      expect(find.text('Volver a intentar'), findsOneWidget);
      repo.fail = false;
      repo.status = 'not_started';
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin verificar'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(repo.reads, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
