import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_logout_row.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue;
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class LogoutOwnerProfile extends FakeRescuerProfile {
  LogoutOwnerProfile() {
    value['owner_id'] = 'one';
  }
  @override
  String? get userId => 'one';
}

class LogoutIdentity extends FakeIdentityRepository {
  bool fail = false;
  @override
  Future<void> logout() async {
    if (fail) throw StateError('network_unavailable');
    await super.logout();
  }
}

void main() {
  testWidgets('logout shows keyboard focus and Enter starts only one request', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RescuerLogoutRow(
            onLogout: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    final outline = find.byKey(const ValueKey('reference-keyboard-outline'));
    expect(outline, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(outline, findsOneWidget);
    expect(calls, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(outline, findsNothing);
  });
  testWidgets('logout ignores repeated activation during a pending request', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RescuerLogoutRow(
            onLogout: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();
    await tester.tap(find.text('Cerrar sesión'));
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  for (final fail in [false, true]) {
    testWidgets('rescuer profile logs out only on service success: $fail', (
      tester,
    ) async {
      final identity = LogoutIdentity()
        ..user = const Identity('one', 'fixture@example.test', verified: true)
        ..fail = fail;
      await identity.setExperience('rescuer');
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          rescuerProfileRepositoryProvider.overrideWithValue(
            LogoutOwnerProfile(),
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
      await tester.scrollUntilVisible(
        find.text('Cerrar sesión'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Cerrar sesión')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      expect(find.byType(DonorLogoutRow), findsOneWidget);
      expect(find.text('Cerrar sesión').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(
        container.read(identityControllerProvider).identity?.id,
        fail ? 'one' : null,
      );
      expect(identity.current?.id, fail ? 'one' : null);
      if (fail) {
        expect(container.read(routerProvider).state.uri.path, '/profile');
        expect(identity.profile.mode, 'rescuer');
        expect(find.byType(DonorLogoutRow), findsOneWidget);
        expect(
          find.text(
            'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.',
          ),
          findsOneWidget,
        );
      } else {
        expect(container.read(routerProvider).state.uri.path, '/welcome');
        expect(find.byType(DonorLogoutRow), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
