import 'package:dopmi_mobile/features/payments/guardian_registration.dart';

import 'guardian_registration_test.dart' show fixture;

import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'guardian_test.dart' show FakeGuardian, activePlan;

class ProfileGuardian extends FakeGuardian {
  GuardianRegistration? registration;
  bool failRegistration = false;
  @override
  Future<GuardianRegistration?> registrationState() async {
    if (failRegistration) throw StateError('offline registration');
    return registration;
  }

  Completer<Json>? pending;
  bool failState = false;
  @override
  Future<Json> state() async {
    reads++;
    if (pending != null) return pending!.future;
    if (failState) throw Exception('offline');
    return value;
  }
}

void main() {
  for (final payment in [
    'requires_action',
    'processing',
    'skipped',
    'refund_pending',
    'processor_confirmed',
  ]) {
    testWidgets(
      'registration $payment opens same record and refreshes after return',
      (tester) async {
        final repo = ProfileGuardian()
          ..registration = GuardianRegistration.fromJson(fixture(payment));
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: DonorGuardianFeature()),
            ),
            GoRoute(
              path: '/guardian',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    repo.registration = GuardianRegistration.fromJson(
                      fixture('skipped'),
                    );
                    context.pop();
                  },
                  child: const Text('Volver al perfil'),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [guardianRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(repo.registration!.summary), findsOneWidget);
        expect(find.text('¡Ya eres Guardián!'), findsNothing);
        await tester.tap(find.text('Tu registro Guardián'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Volver al perfil'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Sin deuda ni recobro'), findsOneWidget);
        expect(repo.reads, 2);
        expect(repo.calls, isEmpty);
      },
    );
  }
  testWidgets('registration lookup failure is unknown, never inactive', (
    tester,
  ) async {
    final repo = ProfileGuardian()..failRegistration = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guardianRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: DonorGuardianFeature())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sé un Guardián'), findsNothing);
    expect(find.textContaining('No pudimos consultar'), findsOneWidget);
  });
  testWidgets(
    'unknown Guardian state cannot claim an inactive membership; retry recovers',
    (tester) async {
      final repo = ProfileGuardian()..pending = Completer<Json>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guardianRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: DonorGuardianFeature()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Sé un Guardián'), findsNothing);
      expect(find.text('¡Ya eres Guardián!'), findsNothing);
      expect(find.text('Consultando tu membresía…'), findsOneWidget);
      repo.pending!.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Sé un Guardián'), findsNothing);
      expect(find.text('Tu membresía Guardián'), findsOneWidget);
      repo.pending = null;
      repo.value = {'plan': activePlan(), 'activation': null};
      await tester.tap(find.text('Tu membresía Guardián'));
      await tester.pumpAndSettle();
      expect(find.text('¡Ya eres Guardián!'), findsOneWidget);
      expect(repo.reads, 2);
    },
  );

  testWidgets(
    'active Guardian opens impact and refreshes membership on return',
    (tester) async {
      final repo = ProfileGuardian()
        ..value = {'plan': activePlan(), 'activation': null};
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: DonorGuardianFeature()),
          ),
          GoRoute(
            path: '/impact',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () {
                  repo.value = {'plan': null, 'activation': null};
                  context.pop();
                },
                child: const Text('Regresar'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guardianRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('¡Ya eres Guardián!'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regresar'));
      await tester.pumpAndSettle();
      expect(find.text('Sé un Guardián'), findsOneWidget);
      expect(find.text('¡Ya eres Guardián!'), findsNothing);
      expect(repo.reads, 2);
    },
  );

  testWidgets('rescuer confirmation is scrollable at 320px and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const DonorModeDialog(),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ahora no'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(result, false);
    expect(tester.takeException(), isNull);
  });
}
