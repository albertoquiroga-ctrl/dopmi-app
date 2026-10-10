import 'package:flutter/services.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';

import 'rescuer_profile_test.dart' show FakeRescuerProfile;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_verification_card.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart'
    show RescueEditorScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class VerificationNavigationRescue extends FakeRescue {
  VerificationNavigationRescue(this.status);
  final String status;
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'verification_status': status,
  };
}

class VerificationOwnerProfile extends FakeRescuerProfile {
  VerificationOwnerProfile() {
    value['owner_id'] = 'one';
  }
  @override
  String? get userId => 'one';
}

void main() {
  testWidgets(
    'verification keyboard focus highlights the card without activating it',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RescuerVerificationCard(
                status: 'approved',
                onPressed: () => opens++,
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('reference-keyboard-outline')),
        findsOneWidget,
      );
      expect(opens, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opens, 1);
      await tester.tap(find.byType(RescuerVerificationCard));
      await tester.pump();
      expect(opens, 2);
      expect(
        find.byKey(const ValueKey('reference-keyboard-outline')),
        findsNothing,
      );
    },
  );
  for (final status in [
    'not_started',
    'submitted',
    'changes_requested',
    'approved',
  ]) {
    testWidgets('verification card reflows and opens exactly once: $status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RescuerVerificationCard(
                  status: status,
                  onPressed: () => opens++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Cuenta verificada'),
        status == 'approved' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Puedes recibir donaciones y publicar casos'),
        findsNothing,
      );
      await tester.tap(find.byType(RescuerVerificationCard));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final status in ['approved', 'submitted']) {
    testWidgets('profile verification opens the real destination: $status', (
      tester,
    ) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await identity.setExperience('rescuer');
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(
            VerificationNavigationRescue(status),
          ),
          rescuerProfileRepositoryProvider.overrideWithValue(
            VerificationOwnerProfile(),
          ),
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
      final label = status == 'approved'
          ? 'Cuenta verificada'
          : 'Verificación en proceso';
      expect(find.text('El perfil no corresponde a tu cuenta.'), findsNothing);
      final card = find.text(label);
      await tester.scrollUntilVisible(
        card,
        160,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(card), alignment: .5);
      await tester.pumpAndSettle();
      expect(card.hitTestable(), findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      if (status == 'approved') {
        expect(container.read(routerProvider).state.uri.path, '/settings');
        expect(find.text('Configuración'), findsOneWidget);
        expect(find.byType(RescueEditorScreen), findsNothing);
      } else {
        expect(container.read(routerProvider).state.uri.path, '/rescue/new');
        expect(
          container.read(routerProvider).state.uri.queryParameters['kind'],
          'verification',
        );
        expect(find.byType(RescueEditorScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
