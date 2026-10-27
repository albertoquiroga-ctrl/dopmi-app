import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:dopmi_mobile/features/adoption/publication_screens.dart';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/publish_choice_screen.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class PublishRoutingRescue extends FakeRescue {
  PublishRoutingRescue(this.status);
  final String status;
  int dashboardCalls = 0, mineCalls = 0, transitionCalls = 0;
  Object? failure;
  Completer<Json>? pending;
  @override
  Future<Json> dashboard() async {
    dashboardCalls++;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return {'verification_status': status};
  }

  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async {
    if (kind != 'verification') return super.mine(kind, page, parent: parent);
    mineCalls++;
    expect(kind, 'verification');
    return status == 'submitted'
        ? DataPage([
            RescueRecord({
              'id': 'verification-current',
              'kind': 'verification',
              'status': 'submitted',
            }),
          ], 1)
        : const DataPage([], 0);
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    transitionCalls++;
    throw StateError('Opening a draft must not transition a rescue record.');
  }
}

Future<ProviderContainer> publishApp(
  WidgetTester tester,
  PublishRoutingRescue rescue, {
  bool large = false,
}) async {
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  identity.profile = const Profile(
    id: 'one',
    name: 'Ana',
    phone: '',
    city: '',
    mode: 'rescuer',
    intent: 'rescue',
    status: 'active',
    termsVersion: currentTermsVersion,
    privacyVersion: currentPrivacyVersion,
    adultConfirmed: true,
  );
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(FakeCommunity()),
      rescueRepositoryProvider.overrideWithValue(rescue),
      routerInitialLocationProvider.overrideWithValue('/publish'),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DopmiApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final status in ['approved', 'not_started', 'draft', 'submitted']) {
    testWidgets('receive opens a private case draft: $status', (
      tester,
    ) async {
      final rescue = PublishRoutingRescue(status);
      await publishApp(tester, rescue);
      await tester.ensureVisible(find.byType(PublishTypeCard).last);
      await tester.tap(find.byType(PublishTypeCard).last);
      await tester.pumpAndSettle();
      expect(rescue.dashboardCalls, 0);
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final route = GoRouterState.of(
        tester.element(find.byType(RescueEditorScreen)),
      ).uri.toString();
      expect(route, '/rescue/new?kind=case');
      expect(rescue.dashboardCalls, 1);
      expect(rescue.mineCalls, 0);
      expect(find.text('Guardar borrador'), findsOneWidget);
      expect(find.text('Enviar a revisión'), findsNothing);
      expect(rescue.saveCalls, 0);
      expect(rescue.transitionCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'dashboard error stays on choice; adoption does not query rescue state',
    (tester) async {
      final rescue = PublishRoutingRescue('not_started')
        ..failure = const FormatException(
          'No pudimos consultar tu verificación.',
        );
      final container = await publishApp(tester, rescue);
      await tester.ensureVisible(find.byType(PublishTypeCard).last);
      await tester.tap(find.byType(PublishTypeCard).last);
      await tester.pumpAndSettle();
      expect(rescue.dashboardCalls, 0);
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos consultar tu verificación.'),
        findsOneWidget,
      );
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/publish',
      );
      expect(rescue.mineCalls, 0);
      await tester.ensureVisible(find.byType(PublishTypeCard).first);
      await tester.tap(find.byType(PublishTypeCard).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(tester.element(find.byType(PublicationScreen)))
            .uri
            .path,
        '/my-adoptions/new',
      );
      expect(rescue.dashboardCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('inactive account refusal prevents private draft entry', (
    tester,
  ) async {
    final rescue = PublishRoutingRescue('not_started')
      ..failure = const PostgrestException(
        message: 'Cuenta activa y confirmada requerida',
        code: '42501',
      );
    final container = await publishApp(tester, rescue);
    await tester.ensureVisible(find.byType(PublishTypeCard).last);
    await tester.tap(find.byType(PublishTypeCard).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No tienes acceso a este contenido. Revisa tu sesión y la aceptación de términos en Mi cuenta.',
      ),
      findsOneWidget,
    );
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/publish',
    );
    expect(find.byType(RescueEditorScreen), findsNothing);
    expect(rescue.dashboardCalls, 1);
    expect(rescue.saveCalls, 0);
    expect(rescue.transitionCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('repeated continue waits for one account check', (tester) async {
    final rescue = PublishRoutingRescue('not_started')
      ..pending = Completer<Json>();
    await publishApp(tester, rescue);
    await tester.ensureVisible(find.byType(PublishTypeCard).last);
    await tester.tap(find.byType(PublishTypeCard).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(rescue.dashboardCalls, 1);
    expect(find.byType(RescueEditorScreen), findsNothing);
    rescue.pending!.complete({'verification_status': 'not_started'});
    await tester.pumpAndSettle();
    expect(
      GoRouterState.of(tester.element(find.byType(RescueEditorScreen)))
          .uri
          .toString(),
      '/rescue/new?kind=case',
    );
    expect(rescue.saveCalls, 0);
    expect(rescue.transitionCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'publication choice reflows at 320px and 200% and cancel reaches real home',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1704);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await publishApp(
        tester,
        PublishRoutingRescue('approved'),
      );
      await tester.ensureVisible(find.byType(PublishTypeCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PublishTypeCard).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/rescuer',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late account check never redirects a different active tab', (
    tester,
  ) async {
    final rescue = PublishRoutingRescue('not_started')
      ..pending = Completer<Json>();
    final container = await publishApp(tester, rescue);
    await tester.ensureVisible(find.byType(PublishTypeCard).last);
    await tester.tap(find.byType(PublishTypeCard).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    container.read(routerProvider).go('/my-cases');
    await tester.pumpAndSettle();
    rescue.pending!.complete({'verification_status': 'not_started'});
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/my-cases',
    );
    expect(find.byType(RescueEditorScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late account check cannot reopen a draft after sign out', (
    tester,
  ) async {
    final rescue = PublishRoutingRescue('not_started')
      ..pending = Completer<Json>();
    final container = await publishApp(tester, rescue);
    await tester.ensureVisible(find.byType(PublishTypeCard).last);
    await tester.tap(find.byType(PublishTypeCard).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    final identity =
        container.read(identityRepositoryProvider) as FakeIdentityRepository;
    identity.emit(const IdentityEvent(null, signedOut: true));
    await tester.pumpAndSettle();
    rescue.pending!.complete({'verification_status': 'not_started'});
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/welcome',
    );
    expect(find.byType(RescueEditorScreen), findsNothing);
    expect(rescue.saveCalls, 0);
    expect(rescue.transitionCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
