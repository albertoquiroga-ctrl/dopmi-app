import 'dart:async';

import 'package:go_router/go_router.dart';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dopmi_mobile/features/profile/impact_screen.dart';
import 'package:dopmi_mobile/core/content_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue, FakeCaseUpdates;
import 'payments_test.dart' show FakePayments;

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/public_expense_card.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';

import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian, activePlan;
import 'profile_guardian_test.dart' show ProfileGuardian;

class ImpactCommunity extends FakeCommunity {
  List<Json> items = [];
  bool fail = false;
  Completer<List<Json>>? pending;
  int reads = 0;
  @override
  Future<List<Json>> personalImpact() async {
    reads++;
    if (pending != null && reads == 1) return pending!.future;
    if (fail) throw StateError('offline');
    return items;
  }
}

const contributionCase = {
  'case_id': 'approved-case',
  'allocated_cents': 7525,
  'public_data': {'pet_name': 'Caso aprobado', 'photos': <String>[]},
  'updates': [
    {'body': 'Avance publicado', 'published_at': '2026-09-30T12:00:00Z'},
  ],
};
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<FakeIdentityRepository> start(
    WidgetTester tester,
    ImpactCommunity repo, {
    double scale = 1,
    FakeGuardian? guardian,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        guardianEnabledProvider.overrideWithValue(guardian != null),
        if (guardian != null)
          guardianRepositoryProvider.overrideWithValue(guardian),
        routerInitialLocationProvider.overrideWithValue('/impact'),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const DopmiApp(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return identity;
  }

  testWidgets(
    'Inactive entry shows promotion and keeps real history reachable',
    (tester) async {
      final repo = ImpactCommunity()..items = [contributionCase];
      final guardian = FakeGuardian();
      await start(tester, repo, guardian: guardian);
      expect(find.byType(PageView), findsOneWidget);
      expect(repo.reads, 0);
      await tester.ensureVisible(find.text('Ver mi impacto'));
      await tester.tap(find.text('Ver mi impacto'));
      await tester.pumpAndSettle();
      expect(find.text('Caso aprobado'), findsOneWidget);
      expect(repo.reads, greaterThan(0));
      expect(guardian.calls, isEmpty);
      expect(guardian.opened, 0);
    },
  );
  testWidgets(
    'Active entry uses confirmed membership and opens public impact',
    (tester) async {
      final repo = ImpactCommunity()..items = [contributionCase];
      final guardian = FakeGuardian()
        ..value = {'plan': activePlan(), 'activation': null};
      await start(tester, repo, guardian: guardian);
      expect(find.text('Caso aprobado'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(guardian.calls, isEmpty);
    },
  );
  testWidgets('Membership error never implies inactive and can retry', (
    tester,
  ) async {
    final repo = ImpactCommunity();
    final guardian = ProfileGuardian()..failState = true;
    await start(tester, repo, guardian: guardian);
    expect(find.byType(PageView), findsNothing);
    expect(
      find.text(
        'No pudimos consultar tu estado de Guardián. Vuelve a intentarlo.',
      ),
      findsOneWidget,
    );
    guardian.failState = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    expect(guardian.calls, isEmpty);
  });
  testWidgets(
    'Only a successful empty response claims no assigned advances; errors can retry',
    (tester) async {
      final repo = ImpactCommunity()..fail = true;
      await start(tester, repo);
      expect(
        find.text('Aquí verás las mascotas que hayas apoyado'),
        findsNothing,
      );
      expect(
        find.text('No pudimos consultar tus avances. Vuelve a intentarlo.'),
        findsOneWidget,
      );
      repo.fail = false;
      await tester.ensureVisible(find.text('Volver a intentar'));
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aquí verás las mascotas que hayas apoyado'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Late response from the previous actor never exposes their allocation',
    (tester) async {
      final repo = ImpactCommunity()..pending = Completer<List<Json>>();
      final identity = await start(tester, repo);
      identity.profile = const Profile(
        id: 'two',
        name: 'Segunda cuenta',
        phone: '',
        city: '',
        mode: 'donor',
        intent: 'adopt',
        status: 'active',
        termsVersion: currentTermsVersion,
        privacyVersion: currentPrivacyVersion,
        adultConfirmed: true,
      );
      identity.emit(
        const IdentityEvent(
          Identity('two', 'second@example.test', verified: true),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/impact');
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.reads, greaterThan(1));
      repo.pending!.complete([contributionCase]);
      await tester.pumpAndSettle();
      expect(find.text('Caso aprobado'), findsNothing);
      expect(find.text(r'$75.25 MXN'), findsNothing);
      expect(
        find.text('Aquí verás las mascotas que hayas apoyado'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Approved advances preserve cents and stay readable at enlarged text',
    (tester) async {
      final repo = ImpactCommunity()..items = [contributionCase];
      await start(tester, repo, scale: 2);
      expect(find.text('Avance publicado'), findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Avance publicado')))
            .scale(14),
        28,
      );
      await tester.ensureVisible(find.text(r'$75.25 MXN'));
      expect(find.text(r'$75.25 MXN'), findsOneWidget);
      expect(find.text('Asignados de tus aportaciones'), findsOneWidget);
      expect(find.text('Suscripción mensual'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('impact share uses public link and case back retains allocation', (
    tester,
  ) async {
    const caseId = '41028a40-8b42-4c03-8417-8d33f91d6f52';
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'dev.fluttercommunity.plus/share/dismissed';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    addTearDown(() => identity.changes.close());
    final repo = ImpactCommunity()
      ..items = [
        {...contributionCase, 'case_id': caseId},
      ];
    final router = GoRouter(
      initialLocation: '/impact',
      routes: [
        GoRoute(path: '/impact', builder: (_, _) => const ImpactScreen()),
        GoRoute(
          path: '/rescue-cases/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(),
            body: Text('Caso ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(repo),
          guardianEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final share = find.text('Compartir');
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(calls.length, 1);
    expect(
      calls.single.arguments['text'],
      'Conoce el caso Caso aprobado en Dopmi. io.dopmi.app://content/rescue-cases/$caseId',
    );
    expect(
      contentLinkDestination(
        publicContentLink(PublicContent.rescueCase, caseId),
      ),
      '/rescue-cases/$caseId',
    );
    expect(find.byType(SnackBar), findsNothing);
    final name = find.text('Caso aprobado');
    await tester.ensureVisible(name);
    final before = tester.getTopLeft(name);
    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rescue-cases/$caseId');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/impact');
    expect(find.text(r'$75.25 MXN'), findsOneWidget);
    expect(tester.getTopLeft(name), before);
    expect(tester.takeException(), isNull);
  });
  for (final large in [false, true]) {
    testWidgets(
      'impact opens full case and native back restores cents: $large',
      (tester) async {
        tester.view.physicalSize = large
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final repo = ImpactCommunity()
          ..items = [
            {...contributionCase, 'case_id': 'case-one'},
          ];
        final payments = FakePayments();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(repo),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
            paymentRepositoryProvider.overrideWithValue(payments),
            guardianEnabledProvider.overrideWithValue(false),
            routerInitialLocationProvider.overrideWithValue('/impact'),
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
        final name = find.text('Caso aprobado');
        await tester.ensureVisible(name);
        await tester.pumpAndSettle();
        final before = tester.getTopLeft(name);
        await tester.tap(name);
        await tester.pumpAndSettle();
        expect(
          container.read(routerProvider).state.uri.path,
          '/rescue-cases/case-one',
        );
        expect(find.textContaining('Choco'), findsWidgets);
        expect(find.byType(PublicExpenseCard), findsOneWidget);
        expect(payments.calls, isEmpty);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/impact');
        expect(find.text(r'$75.25 MXN'), findsOneWidget);
        expect(tester.getTopLeft(name), before);
        expect(payments.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
