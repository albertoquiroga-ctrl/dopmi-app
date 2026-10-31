import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/connect_client.dart';
import 'package:dopmi_mobile/features/payments/payment_environment.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_identity_repository.dart';
import 'community_test.dart' show FakeCommunity;

enum _SessionFlow { ready, rejected, leave }

class _ConnectPayments extends PaymentRepository {
  _ConnectPayments({this.sessionRejected = false, this.sessionGate})
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final actions = <String>[];
  final opened = <String>[];
  final bool sessionRejected;
  final Completer<Map<String, dynamic>>? sessionGate;

  @override
  Future<Map<String, dynamic>> action(
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    actions.add(action);
    if (action == 'connect_session') {
      if (sessionRejected) throw StateError('private_processor_detail');
      if (sessionGate != null) return sessionGate!.future;
    }
    return switch (action) {
      'connect_status' => {
        'verified': true,
        'ready': true,
        'transfers_enabled': true,
        'payouts_enabled': true,
        'payouts': [],
      },
      'connect_session' => {
        'client_secret': 'synthetic_session_secret',
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
      },
      'connect_onboard' => {'url': 'https://connect.stripe.com/synthetic'},
      _ => throw StateError('unexpected operation'),
    };
  }

  @override
  Future<void> openStripe(String url) async {
    opened.add(url);
  }
}

void main() {
  final scenarios = [
    (
      name: 'LIVE native',
      mode: 'production',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 1,
      hosted: 0,
    ),
    (
      name: 'LIVE unsupported',
      mode: 'production',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.windows,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'LIVE web',
      mode: 'production',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.android,
      web: true,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'LIVE crossed key',
      mode: 'production',
      key: 'pk_test_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'LIVE missing key',
      mode: 'production',
      key: '',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'LIVE disabled',
      mode: 'production',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: false,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'unknown mode',
      mode: 'unknown',
      key: 'pk_test_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'TEST unsupported',
      mode: 'test',
      key: 'pk_test_synthetic',
      platform: TargetPlatform.windows,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 1,
    ),
    (
      name: 'TEST web',
      mode: 'test',
      key: 'pk_test_synthetic',
      platform: TargetPlatform.android,
      web: true,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 1,
    ),
    (
      name: 'TEST crossed key',
      mode: 'test',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'TEST disabled',
      mode: 'test',
      key: 'pk_test_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: false,
      fails: false,
      sessionFlow: _SessionFlow.ready,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'LIVE SDK error',
      mode: 'production',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: true,
      sessionFlow: _SessionFlow.ready,
      native: 1,
      hosted: 0,
    ),
    (
      name: 'TEST SDK error',
      mode: 'test',
      key: 'pk_test_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: true,
      sessionFlow: _SessionFlow.ready,
      native: 1,
      hosted: 0,
    ),
    (
      name: 'LIVE initial session rejected',
      mode: 'production',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.rejected,
      native: 0,
      hosted: 0,
    ),
    (
      name: 'LIVE user leaves during initial request',
      mode: 'production',
      key: 'pk_live_synthetic',
      platform: TargetPlatform.android,
      web: false,
      enabled: true,
      fails: false,
      sessionFlow: _SessionFlow.leave,
      native: 0,
      hosted: 0,
    ),
  ];
  for (final scenario in scenarios) {
    testWidgets('${scenario.name} uses only its permitted Connect channel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(480, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // The placeholder client starts a JSON isolate; keep its lifecycle in
      // real async rather than creating it in the widget test's FakeAsync zone.
      final leaving = scenario.sessionFlow == _SessionFlow.leave;
      final gate = leaving ? Completer<Map<String, dynamic>>() : null;
      final payments = (await tester.runAsync(
        () async => _ConnectPayments(
          sessionRejected: scenario.sessionFlow == _SessionFlow.rejected,
          sessionGate: gate,
        ),
      ))!;
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final mode = PaymentEnvironment(
        environment: scenario.mode,
        testPublishableKey: scenario.key,
        productionPublishableKey: scenario.key,
      );
      var nativePresentations = 0;
      final client = ConnectClient(
        key: scenario.key,
        paymentEnvironment: mode,
        enabled: scenario.enabled,
        platform: scenario.platform,
        web: scenario.web,
        session: () => payments.action('connect_session'),
        initialize: (_, fetch) async {
          await fetch();
        },
        present: () async {
          nativePresentations++;
          if (scenario.fails) throw StateError('synthetic native interruption');
        },
        logout: () async {},
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ConnectScreen()),
          GoRoute(
            path: '/elsewhere',
            builder: (_, _) => const Scaffold(body: Text('Otra pantalla')),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          paymentEnvironmentProvider.overrideWithValue(mode),
          connectClientProvider.overrideWithValue(client),
          paymentRepositoryProvider.overrideWithValue(payments),
          identityRepositoryProvider.overrideWithValue(identity),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        router.dispose();
        // Supabase disposal can wait for real async events outside FakeAsync.
        await tester.runAsync(() => payments.client.dispose());
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          scenario.mode == 'production'
              ? 'STRIPE CONNECT · PAGOS REALES'
              : 'STRIPE CONNECT · PRUEBA',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Completar datos en Stripe'));
      await tester.tap(find.text('Completar datos en Stripe'));
      if (leaving) {
        await tester.pump();
        router.go('/elsewhere');
        await tester.pumpAndSettle();
        gate!.complete({
          'client_secret': 'synthetic_session_secret',
          'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
        });
      }
      await tester.pumpAndSettle();
      expect(nativePresentations, scenario.native);
      expect(
        payments.actions.where((value) => value == 'connect_session'),
        hasLength(
          scenario.sessionFlow != _SessionFlow.ready || scenario.native > 0
              ? 1
              : 0,
        ),
      );
      expect(
        payments.actions.where((value) => value == 'connect_onboard'),
        hasLength(scenario.hosted),
      );
      expect(payments.opened, hasLength(scenario.hosted));
      if (scenario.native == 0 && scenario.hosted == 0 && !leaving) {
        expect(find.textContaining('no está disponible'), findsOneWidget);
      }
      if (scenario.sessionFlow == _SessionFlow.rejected) {
        expect(find.textContaining('contacta a soporte'), findsOneWidget);
        expect(find.textContaining('private_processor_detail'), findsNothing);
        expect(find.textContaining('autenticación'), findsNothing);
      }
      if (leaving) expect(find.text('Otra pantalla'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
