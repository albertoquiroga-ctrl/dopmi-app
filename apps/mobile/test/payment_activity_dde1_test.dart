import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_activity_screen.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class ActivityRepository extends PaymentActivityRepository {
  ActivityRepository() : super(FakeRescue().client);
  final cursors = <Json?>[];
  bool fail = false;
  @override
  Future<Json> page({required bool received, Json? cursor}) async {
    cursors.add(cursor);
    if (fail) throw StateError('offline');
    return {
      'items': [
        {
          'id': cursor == null ? 'one' : 'two',
          'kind': cursor == null ? 'guardian' : 'contribution',
          'title': cursor == null ? 'Suscripción Guardián' : 'Consulta',
          'created_at': '2026-10-08T12:00:00Z',
          'amount_cents': 1011,
          'assigned_cents': 811,
          'status': 'assigned',
          'allocation_count': cursor == null ? 2 : 1,
        },
      ],
      'next_cursor': cursor == null
          ? {
              'created_at': '2026-10-08T12:00:00Z',
              'kind': 'guardian',
              'id': 'one',
            }
          : null,
    };
  }

  @override
  Future<Json> allocations(
    String cycle, {
    required bool received,
    String? afterExpense,
  }) async => {
    'items': [
      {
        'expense_id': 'one',
        'title': 'Consulta',
        'allocated_cents': 811,
        'reversed_cents': 0,
        'status': 'assigned',
      },
    ],
    'next_cursor': null,
  };
}

class PresentedActivityRepository extends ActivityRepository {
  final acknowledgements = <String>[];
  List<Json> rows = List.generate(12, payment);
  Completer<Json>? firstPage;
  Completer<void>? acknowledgement;
  bool rejectAcknowledgement = false;
  int pageCalls = 0;

  static String receipt(int index) =>
      '00000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}';

  static Json payment(int index) => {
    'id': 'receipt-row-$index',
    'kind': 'contribution',
    'title': 'Pago TEST $index',
    'created_at': '2026-10-08T12:00:00Z',
    'amount_cents': 1011,
    'assigned_cents': 811,
    'status': 'assigned',
    'allocation_count': 1,
    'presented_cursor': receipt(index),
  };

  Json get response => {
    'items': rows,
    // A valid-looking UUID in the keyset cursor must never be acknowledged.
    'next_cursor': {
      'created_at': '2026-10-08T12:00:00Z',
      'kind': 'contribution',
      'id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
    },
  };

  @override
  Future<Json> page({required bool received, Json? cursor}) async {
    if (pageCalls++ == 0 && firstPage != null) return firstPage!.future;
    return response;
  }

  @override
  Future<void> acknowledgePresented(String presentedCursor) async {
    acknowledgements.add(presentedCursor);
    if (acknowledgement != null) await acknowledgement!.future;
    if (rejectAcknowledgement) throw StateError('private provider detail');
  }
}

class StripeHistoryPayments extends PaymentRepository {
  StripeHistoryPayments() : super(FakeRescue().client);
  final opened = <String>[];
  Completer<void>? opening;
  Object? failure;

  @override
  Future<void> openStripe(String value) async {
    opened.add(value);
    if (opening != null) await opening!.future;
    if (failure != null) throw failure!;
  }
}

void main() {
  Future<
    ({
      PresentedActivityRepository repo,
      FakeIdentityRepository identity,
      GlobalKey<NavigatorState> navigator,
    })
  >
  mountPresented(
    WidgetTester tester, {
    PresentedActivityRepository? repository,
    StripeHistoryPayments? payments,
    bool received = true,
    bool readOnly = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'synthetic@example.test', verified: true);
    final repo = repository ?? PresentedActivityRepository();
    final navigator = GlobalKey<NavigatorState>();
    addTearDown(identity.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          paymentActivityRepositoryProvider.overrideWithValue(repo),
          if (payments != null)
            paymentRepositoryProvider.overrideWithValue(payments),
        ],
        child: MaterialApp(
          theme: dopmiTheme(),
          navigatorKey: navigator,
          home: PaymentActivityScreen(received: received, readOnly: readOnly),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return (repo: repo, identity: identity, navigator: navigator);
  }

  Future<ActivityRepository> mount(WidgetTester tester) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'synthetic@example.test', verified: true);
    final repo = ActivityRepository();
    addTearDown(identity.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          paymentActivityRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: PaymentActivityScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'received history opens the mock Stripe URL once and retains the ledger on return',
    (tester) async {
      final payments = StripeHistoryPayments()..opening = Completer<void>();
      final harness = await mountPresented(tester, payments: payments);
      final link = find.text('Consultar mi historial en mi cuenta Stripe');
      final firstRow = find.byType(PaymentActivityCard).first;
      expect(link, findsOneWidget);
      expect(
        tester
            .getBottomLeft(
              find.text(
                'Sigue así, personas como tú son especiales para la manada.',
              ),
            )
            .dy,
        lessThan(tester.getTopLeft(link).dy),
      );
      expect(
        tester.getBottomLeft(link).dy,
        lessThan(tester.getTopLeft(firstRow).dy),
      );
      await tester.tap(link);
      await tester.pump();
      await tester.tap(link);
      await tester.pump();
      expect(payments.opened, ['https://connect.stripe.com/']);

      payments.opening!.complete();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(payments.opened, ['https://connect.stripe.com/']);
      expect(harness.repo.pageCalls, 1);
      expect(find.text('Pago TEST 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('received history keeps the Stripe link above its empty state', (
    tester,
  ) async {
    final payments = StripeHistoryPayments();
    final repo = PresentedActivityRepository()..rows = [];
    await mountPresented(tester, repository: repo, payments: payments);
    final link = find.text('Consultar mi historial en mi cuenta Stripe');
    final empty = find.text(
      'Aún no has recibido pagos por tus casos de apoyo.',
    );
    expect(
      tester.getBottomLeft(link).dy,
      lessThan(tester.getTopLeft(empty).dy),
    );
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(payments.opened, ['https://connect.stripe.com/']);
    expect(tester.takeException(), isNull);
  });

  for (final configuration in [(true, true), (false, false)]) {
    testWidgets(
      'Stripe history is inactive for read-only previews and absent for donors: $configuration',
      (tester) async {
        final payments = StripeHistoryPayments();
        await mountPresented(
          tester,
          payments: payments,
          received: configuration.$1,
          readOnly: configuration.$2,
        );
        final link = find.text('Consultar mi historial en mi cuenta Stripe');
        if (configuration.$1) {
          final button = tester.widget<TextButton>(
            find.ancestor(of: link, matching: find.byType(TextButton)),
          );
          expect(button.onPressed, isNull);
        } else {
          expect(link, findsNothing);
        }
        expect(payments.opened, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Stripe opening failure keeps history and permits explicit retry',
    (tester) async {
      final payments = StripeHistoryPayments()
        ..failure = StateError('private launcher detail');
      await mountPresented(tester, payments: payments);
      final link = find.text('Consultar mi historial en mi cuenta Stripe');
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos abrir Stripe. Vuelve a intentar.'),
        findsOneWidget,
      );
      expect(find.textContaining('private launcher'), findsNothing);
      expect(find.text('Pago TEST 0'), findsOneWidget);
      expect(find.text('Reintentar historial'), findsNothing);
      payments.failure = null;
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(payments.opened, [
        'https://connect.stripe.com/',
        'https://connect.stripe.com/',
      ]);
      expect(
        find.text('No pudimos abrir Stripe. Vuelve a intentar.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late Stripe failure cannot affect a different owner history', (
    tester,
  ) async {
    final payments = StripeHistoryPayments()..opening = Completer<void>();
    final repo = PresentedActivityRepository()..rows = [];
    final harness = await mountPresented(
      tester,
      repository: repo,
      payments: payments,
    );
    await tester.tap(find.text('Consultar mi historial en mi cuenta Stripe'));
    await tester.pump();
    harness.identity.emit(
      const IdentityEvent(
        Identity('other', 'other@example.test', verified: true),
      ),
    );
    await tester.pumpAndSettle();
    payments.opening!.completeError(StateError('private old-owner detail'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos abrir Stripe. Vuelve a intentar.'),
      findsNothing,
    );
    expect(find.textContaining('private old-owner'), findsNothing);
    expect(payments.opened, ['https://connect.stripe.com/']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unified pages retain centavos and real multiple assignments', (
    tester,
  ) async {
    final repo = await mount(tester);
    expect(find.text('Suscripción Guardián · 2 asignaciones'), findsOneWidget);
    expect(
      tester.widget<ActivityMoney>(find.byType(ActivityMoney)).cents,
      1011,
    );
    expect(find.text('.11'), findsOneWidget);
    expect(find.textContaining('4242'), findsNothing);
    await tester.tap(find.text('Ver movimientos anteriores'));
    await tester.pumpAndSettle();
    expect(repo.cursors.last?['kind'], 'guardian');
    expect(find.text('Consulta'), findsOneWidget);
    expect(find.text('.11'), findsNWidgets(2));
    await tester.tap(find.text('Suscripción Guardián · 2 asignaciones'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Consulta ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed refresh retry repeats refresh with retained rows', (
    tester,
  ) async {
    final repo = await mount(tester);
    repo.fail = true;
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(
      find.textContaining('No pudimos consultar tu historial'),
      findsOneWidget,
    );
    expect(find.text('Suscripción Guardián · 2 asignaciones'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Reintentar historial'));
    await tester.pumpAndSettle();
    expect(repo.cursors.last, isNull);
    expect(
      find.textContaining('No pudimos consultar tu historial'),
      findsNothing,
    );
  });

  testWidgets(
    'received payments acknowledge only presented rows, deduplicated across refresh',
    (tester) async {
      final harness = await mountPresented(tester);
      final repo = harness.repo;
      final last = find.byKey(
        const ValueKey('one:contribution:receipt-row-11'),
      );
      expect(
        last,
        findsOneWidget,
      ); // The Column has built even this offscreen row.
      expect(tester.getRect(last).top, greaterThan(640));
      expect(repo.acknowledgements, isNotEmpty);
      expect(
        repo.acknowledgements,
        isNot(contains(PresentedActivityRepository.receipt(11))),
      );
      expect(
        repo.acknowledgements,
        isNot(contains('ffffffff-ffff-4fff-8fff-ffffffffffff')),
      );
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(
        repo.acknowledgements,
        contains(PresentedActivityRepository.receipt(11)),
      );
      final calls = repo.acknowledgements.length;
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(repo.acknowledgements.length, calls);
      expect(repo.acknowledgements.toSet().length, calls);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one pixel of a payment header does not count as presented', (
    tester,
  ) async {
    final harness = await mountPresented(tester);
    final target = find.byKey(const ValueKey('one:contribution:receipt-row-8'));
    final card = tester.widget<PaymentActivityCard>(target);
    final header = find.byKey(card.presentationKey!);
    final list = find.byType(ListView);
    final controller = tester.widget<ListView>(list).controller!;
    final viewport = tester.getRect(list);
    controller.jumpTo(
      controller.offset + tester.getRect(header).top - viewport.bottom + 1,
    );
    await tester.pumpAndSettle();
    expect(
      harness.repo.acknowledgements,
      isNot(contains(PresentedActivityRepository.receipt(8))),
    );
    final height = tester.getRect(header).height;
    controller.jumpTo(controller.offset + height);
    await tester.pumpAndSettle();
    expect(
      harness.repo.acknowledgements,
      contains(PresentedActivityRepository.receipt(8)),
    );
    expect(tester.takeException(), isNull);
  });

  for (final configuration in [(true, true), (false, false)]) {
    testWidgets(
      'read-only or donor ledger never acknowledges received activity: $configuration',
      (tester) async {
        final harness = await mountPresented(
          tester,
          received: configuration.$1,
          readOnly: configuration.$2,
        );
        final firstCard = find.byType(PaymentActivityCard).first;
        expect(firstCard, findsOneWidget);
        await tester.ensureVisible(firstCard);
        await tester.pumpAndSettle();
        expect(harness.repo.acknowledgements, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a covered route waits until the payment ledger is current again',
    (tester) async {
      final repo = PresentedActivityRepository()..firstPage = Completer<Json>();
      final harness = await mountPresented(
        tester,
        repository: repo,
        settle: false,
      );
      unawaited(
        harness.navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Otra pantalla')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      repo.firstPage!.complete(repo.response);
      await tester.pump();
      await tester.pump();
      expect(repo.acknowledgements, isEmpty);
      harness.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(repo.acknowledgements, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('background loading waits for foreground before acknowledging', (
    tester,
  ) async {
    final repo = PresentedActivityRepository()..firstPage = Completer<Json>();
    await mountPresented(tester, repository: repo, settle: false);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repo.firstPage!.complete(repo.response);
    await tester.pump();
    await tester.pump();
    expect(repo.acknowledgements, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.acknowledgements, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a page for the previous owner is ignored before any acknowledgement',
    (tester) async {
      final repo = PresentedActivityRepository()..firstPage = Completer<Json>();
      final oldResponse = repo.response;
      final harness = await mountPresented(
        tester,
        repository: repo,
        settle: false,
      );
      repo.rows = [];
      harness.identity.emit(
        const IdentityEvent(
          Identity('other', 'other@example.test', verified: true),
        ),
      );
      await tester.pumpAndSettle();
      repo.firstPage!.complete(oldResponse);
      await tester.pumpAndSettle();
      expect(repo.acknowledgements, isEmpty);
      expect(find.text('Pago TEST 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an acknowledgement failure from the previous owner cannot affect the new ledger',
    (tester) async {
      final repo = PresentedActivityRepository()
        ..acknowledgement = Completer<void>()
        ..rows = [PresentedActivityRepository.payment(0)];
      final harness = await mountPresented(tester, repository: repo);
      expect(repo.acknowledgements, [PresentedActivityRepository.receipt(0)]);
      repo.rows = [];
      harness.identity.emit(
        const IdentityEvent(
          Identity('other', 'other@example.test', verified: true),
        ),
      );
      await tester.pumpAndSettle();
      repo.acknowledgement!.completeError(
        StateError('private old-owner detail'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('avisos de pagos'), findsNothing);
      expect(find.textContaining('private'), findsNothing);
      expect(repo.acknowledgements.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'acknowledgement errors keep the ledger and retry only after an explicit action',
    (tester) async {
      final repo = PresentedActivityRepository()
        ..rejectAcknowledgement = true
        ..rows = [PresentedActivityRepository.payment(0)];
      await mountPresented(tester, repository: repo);
      expect(repo.acknowledgements.length, 1);
      expect(find.text('Pago TEST 0'), findsOneWidget);
      expect(find.textContaining('private provider'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(repo.acknowledgements.length, 1);
      repo.rejectAcknowledgement = false;
      final retry = find.text('Reintentar avisos de pagos');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repo.acknowledgements, [
        PresentedActivityRepository.receipt(0),
        PresentedActivityRepository.receipt(0),
      ]);
      expect(find.text('Reintentar avisos de pagos'), findsNothing);
      expect(find.text('Pago TEST 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh retaining an in-flight receipt preserves explicit retry after failure',
    (tester) async {
      final pending = Completer<void>();
      final repo = PresentedActivityRepository()
        ..acknowledgement = pending
        ..rows = [PresentedActivityRepository.payment(0)];
      await mountPresented(tester, repository: repo);
      final receipt = PresentedActivityRepository.receipt(0);
      expect(repo.acknowledgements, [receipt]);
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(repo.pageCalls, 2);
      expect(repo.acknowledgements, [receipt]);

      pending.completeError(StateError('private stale-generation detail'));
      await tester.pumpAndSettle();
      expect(find.text('Pago TEST 0'), findsOneWidget);
      expect(find.textContaining('private stale-generation'), findsNothing);
      final retry = find.text('Reintentar avisos de pagos');
      expect(retry, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(repo.acknowledgements, [receipt]);

      repo.acknowledgement = null;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repo.acknowledgements, [receipt, receipt]);
      expect(find.text('Reintentar avisos de pagos'), findsNothing);
      expect(find.text('Pago TEST 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'two visible rows sharing the same exact snapshot acknowledge it once',
    (tester) async {
      final repo = PresentedActivityRepository()
        ..rows = [
          PresentedActivityRepository.payment(0),
          {
            ...PresentedActivityRepository.payment(1),
            'presented_cursor': PresentedActivityRepository.receipt(0),
          },
        ];
      await mountPresented(tester, repository: repo);
      expect(repo.acknowledgements, [PresentedActivityRepository.receipt(0)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy or malformed row receipts never use the pagination cursor',
    (tester) async {
      final repo = PresentedActivityRepository()
        ..rows = [
          {...PresentedActivityRepository.payment(0), 'presented_cursor': null},
          {
            ...PresentedActivityRepository.payment(1),
            'presented_cursor': 'not-a-receipt',
          },
        ];
      await mountPresented(tester, repository: repo);
      expect(repo.acknowledgements, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
