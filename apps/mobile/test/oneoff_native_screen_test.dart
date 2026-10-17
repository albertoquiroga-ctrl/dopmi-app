import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/oneoff_payment_sheet.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'payments_test.dart' show FakePayments, tapButton, pumpUntil;

const secret = 'pi_synthetic_secret_synthetic';

class NativePayments extends FakePayments {
  String paymentState = 'processing', paymentStatus = 'pending';
  int reads = 0, hostedOpens = 0;
  @override
  Future<Map<String, dynamic>> checkout(
    String expense,
    int cents,
    String key,
  ) async {
    calls.add(key);
    return {
      'status': 'pending',
      'payment_state': 'requires_payment_method',
      'payment_client_secret': secret,
    };
  }

  @override
  Future<Map<String, dynamic>?> outcome(String expense, String key) async {
    reads++;
    return {
      'payment_status': paymentStatus,
      'payment_state': paymentState,
      'gross_cents': 10025,
      'allocated_cents': paymentStatus == 'confirmed' ? 9200 : 0,
      'transfer_status': paymentStatus == 'confirmed'
          ? 'pending'
          : 'not_started',
    };
  }

  @override
  Future<void> openStripe(String value) async {
    hostedOpens++;
  }
}

class NativeSheet implements OneoffPaymentSheet {
  final secrets = <String>[];
  bool enabled = true, close = false;
  Completer<void>? gate;
  VoidCallback? after;
  @override
  bool get available => enabled;
  @override
  Future<void> present(String value, {required bool Function() current}) async {
    if (!current()) return;
    secrets.add(value);
    await gate?.future;
    after?.call();
    if (close) throw StateError('synthetic sheet interrupted');
  }
}

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    NativePayments payments,
    OneoffPaymentSheet sheet, {
    bool navigationStack = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'synthetic@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        paymentRepositoryProvider.overrideWithValue(payments),
        oneoffPaymentSheetProvider.overrideWithValue(sheet),
        routerInitialLocationProvider.overrideWithValue(
          navigationStack
              ? '/payments'
              : '/contribute/expense-one?amount_cents=10025',
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    if (navigationStack) {
      await tester.pumpAndSettle();
      unawaited(
        container
            .read(routerProvider)
            .push<void>('/contribute/expense-one?amount_cents=10025'),
      );
    }
    await pumpUntil(tester, find.text('Resumen'));
    return container;
  }

  testWidgets(
    'native authorization completion stays pending until server evidence, without a second payment button',
    (tester) async {
      final payments = NativePayments();
      final sheet = NativeSheet();
      await start(tester, payments, sheet);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pumpAndSettle();
      expect(sheet.secrets, [secret]);
      expect(payments.hostedOpens, 0);
      expect(find.text('Pago en procesamiento'), findsOneWidget);
      expect(find.text('Pago exitoso'), findsNothing);
      expect(find.text('Continuar la misma aportación'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('dopmi-payment:one:expense-one:key'),
        payments.calls.single,
      );
      expect(
        prefs.getKeys().map((key) => prefs.get(key).toString()).join(),
        isNot(contains(secret)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SDK interruption never overrides a confirmed server receipt with an error',
    (tester) async {
      final payments = NativePayments();
      final sheet = NativeSheet()
        ..close = true
        ..after = () {
          payments.paymentStatus = 'confirmed';
        };
      await start(tester, payments, sheet);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pumpAndSettle();
      expect(find.text('Pago exitoso'), findsOneWidget);
      expect(find.textContaining('La captura no se completó'), findsNothing);
      expect(find.textContaining('synthetic sheet'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-payment:one:expense-one:key',
        ),
        isNull,
      );
      expect(payments.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closed sheet can continue only a server-actionable same intent and stable key',
    (tester) async {
      final payments = NativePayments()
        ..paymentState = 'requires_payment_method';
      final sheet = NativeSheet()..close = true;
      await start(tester, payments, sheet);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pumpAndSettle();
      expect(find.text('Continuar la misma aportación'), findsOneWidget);
      final key = payments.calls.single;
      sheet.close = false;
      sheet.after = () {
        payments.paymentStatus = 'confirmed';
      };
      await tapButton(tester, 'Continuar la misma aportación');
      await tester.pumpAndSettle();
      expect(payments.calls, [key, key]);
      expect(sheet.secrets, [secret, secret]);
      expect(payments.hostedOpens, 0);
      expect(find.text('Pago exitoso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported SDK starts neither a donation attempt nor a hosted fallback',
    (tester) async {
      final payments = NativePayments();
      final sheet = NativeSheet()..enabled = false;
      await start(tester, payments, sheet);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pumpAndSettle();
      expect(payments.calls, isEmpty);
      expect(payments.hostedOpens, 0);
      expect(sheet.secrets, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-payment:one:expense-one:key',
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'suspension while the sheet is open does not submit twice or promote SDK status',
    (tester) async {
      final payments = NativePayments();
      final gate = Completer<void>();
      final sheet = NativeSheet()..gate = gate;
      await start(tester, payments, sheet);
      await tapButton(tester, 'Confirmar aportación');
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(payments.calls, hasLength(1));
      expect(sheet.secrets, hasLength(1));
      expect(payments.reads, 0);
      gate.complete();
      await tester.pumpAndSettle();
      expect(payments.reads, 1);
      expect(payments.calls, hasLength(1));
      expect(find.text('Pago en procesamiento'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android Back during SDK initialization keeps the route and permits only owner refresh until sheet returns',
    (tester) async {
      final payments = NativePayments();
      final initialization = Completer<void>();
      var initialized = 0, prepared = 0, shown = 0;
      final sdk = OneoffPaymentSheetSdk(
        publishableKey: 'pk_test_synthetic',
        platform: TargetPlatform.android,
        web: false,
        initialize: (_, _) {
          initialized++;
          return initialization.future;
        },
        prepare: (_) async {
          prepared++;
        },
        show: () async {
          shown++;
        },
      );
      final container = await start(
        tester,
        payments,
        sdk,
        navigationStack: true,
      );
      final router = container.read(routerProvider);
      expect(router.canPop(), true);
      expect(router.state.uri.path, '/contribute/expense-one');
      await tapButton(tester, 'Confirmar aportación');
      await tester.pump();
      expect(initialized, 1);
      expect(prepared, 0);
      expect(shown, 0);
      expect(
        ModalRoute.of(tester.element(find.text('Resumen')))!.popDisposition,
        RoutePopDisposition.doNotPop,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      // Imperative push does not update routeInformationProvider's base URL.
      // Inspect the active route state instead of that underlying history URL.
      expect(router.state.uri.path, '/contribute/expense-one');
      expect(find.text('Resumen'), findsOneWidget);
      final refresh = find.widgetWithText(
        TextButton,
        'Consultar estado del mismo intento',
      );
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await pumpUntil(tester, find.text('Pago en procesamiento'));
      expect(payments.reads, 1);
      expect(payments.calls, hasLength(1));
      expect(shown, 0);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Ir al historial'),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(router.state.uri.path, '/contribute/expense-one');
      initialization.complete();
      await tester.pumpAndSettle();
      expect(prepared, 1);
      expect(shown, 1);
      expect(payments.calls, hasLength(1));
      expect(payments.reads, 2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/payments');
      expect(tester.takeException(), isNull);
    },
  );

  for (final boundary in ['initialization', 'prepare']) {
    for (final change in ['owner', 'route']) {
      testWidgets(
        '$change change during SDK $boundary cannot open the prior owner payment sheet',
        (tester) async {
          final payments = NativePayments();
          final initialized = Completer<void>();
          final prepared = Completer<void>();
          var preparations = 0, shown = 0;
          final sdk = OneoffPaymentSheetSdk(
            publishableKey: 'pk_test_synthetic',
            platform: TargetPlatform.android,
            web: false,
            initialize: (_, _) => initialized.future,
            prepare: (_) {
              preparations++;
              return prepared.future;
            },
            show: () async {
              shown++;
            },
          );
          final container = await start(tester, payments, sdk);
          await tapButton(tester, 'Confirmar aportación');
          if (boundary == 'prepare') {
            initialized.complete();
            await tester.pump();
            expect(preparations, 1);
          }
          if (change == 'owner') {
            (container.read(
              identityRepositoryProvider,
            ) as FakeIdentityRepository).emit(
              const IdentityEvent(
                Identity('two', 'other@example.test', verified: true),
              ),
            );
          } else {
            container.read(routerProvider).go('/payments');
          }
          await tester.pump();
          if (!initialized.isCompleted) initialized.complete();
          prepared.complete();
          await tester.pumpAndSettle();
          expect(preparations, boundary == 'prepare' ? 1 : 0);
          expect(shown, 0);
          expect(payments.calls, hasLength(1));
          expect(payments.reads, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
