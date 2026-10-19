import 'package:dopmi_mobile/features/payments/connect_client.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/payments/oneoff_payment_sheet.dart';

import 'payments_test.dart' show FakePayments, FakeOneoffSheet;

import 'package:go_router/go_router.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_registration.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_repository.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_panel.dart';

import 'monthly_impact_test.dart' show FakeMonthlyImpact;

import 'package:dopmi_mobile/features/payments/guardian_bank_action.dart';
import 'package:dopmi_mobile/features/payments/guardian_method_setup.dart';
import 'package:dopmi_mobile/features/payments/contribution_layout.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;
import 'rescue_test.dart' show FakeRescue;
import '../tool/capture_design_test.dart' show saveCapture;

const registrationId = '72000000-0000-4000-8000-000000000001';
GuardianRegistration registration(
  String key, {
  String status = 'method_pending',
  String payment = 'not_evaluated',
}) => GuardianRegistration.fromJson({
  'id': registrationId,
  'key': key,
  'status': status,
  'gross_cents': 5000,
  'revision': 1,
  'registered_at': '2026-10-14T12:00:00Z',
  'next_evaluation_at': status == 'canceled' ? null : '2026-11-14T12:00:00Z',
  'consent_version': guardianRegistrationConsent,
  'payment': {
    'state': payment,
    'attempt_id': payment == 'not_evaluated'
        ? null
        : '72000000-0000-4000-8000-000000000003',
    'allocated_cents': 0,
    'refund_cents': 0,
  },
});

class RegistrationGuardian extends FakeGuardian {
  GuardianRegistration? registrationValue;
  bool failRegistration = false;
  final registrations = <Map<String, dynamic>>[];
  bool lose = false;
  Completer<void>? responseGate;
  int? changedAmount;
  String? setupSecret;
  String? checkoutUrl;
  String canceledPayment = 'processing';
  int registrationReads = 0;
  @override
  Future<GuardianRegistration?> registrationState() async {
    registrationReads++;
    if (failRegistration) throw StateError('synthetic offline');
    return registrationValue;
  }

  @override
  Future<bool> capacity(int cents) async =>
      throw StateError('Registration must not require initial capacity');
  @override
  Future<Map<String, dynamic>> submitRegistration(
    Map<String, dynamic> draft,
  ) async {
    registrations.add(Map.from(draft));
    await responseGate?.future;
    registrationValue = registration(draft['key']);
    if (lose) throw StateError('synthetic response loss');
    return {
      'id': registrationId,
      'key': draft['key'],
      'status': 'method_pending',
      'gross_cents': draft['gross_cents'],
      'checkout_url': checkoutUrl,
      'setup_client_secret': setupSecret,
    };
  }

  @override
  Future<void> cancelRegistration(String id) async {
    expect(id, registrationId);
    registrationValue = registration(
      registrationValue!.key,
      status: 'canceled',
      payment: canceledPayment,
    );
  }

  @override
  Future<void> changeRegistrationAmount(
    GuardianRegistration value,
    int cents,
  ) async {
    changedAmount = cents;
    registrationValue = GuardianRegistration(
      id: value.id,
      key: value.key,
      status: value.status,
      grossCents: cents,
      revision: value.revision + 1,
      registeredAt: value.registeredAt,
      nextEvaluationAt: value.nextEvaluationAt,
      paymentState: value.paymentState,
      attemptId: value.attemptId,
      allocatedCents: value.allocatedCents,
      refundCents: value.refundCents,
      evaluationStatus: value.evaluationStatus,
      evaluationCycle: value.evaluationCycle,
    );
  }
}

class CanceledImpactGuardian extends RegistrationGuardian {
  int financialMutations = 0;
  Never rejectFinancialMutation() {
    financialMutations++;
    throw StateError('Impact history must not mutate a canceled registration');
  }

  @override
  Future<Map<String, dynamic>> submitRegistration(
    Map<String, dynamic> draft,
  ) async => rejectFinancialMutation();
  @override
  Future<void> cancelRegistration(String id) async => rejectFinancialMutation();
  @override
  Future<void> changeRegistrationAmount(
    GuardianRegistration value,
    int cents,
  ) async => rejectFinancialMutation();
  @override
  Future<Json> submitRegistrationMethod(Json draft) async =>
      rejectFinancialMutation();
}

class RegistrationMethodSetup implements GuardianMethodSetup {
  final secrets = <String>[];
  Completer<void>? gate;
  bool close = false;
  bool ready = true;
  void Function()? onPresent;
  @override
  bool get available => ready;
  @override
  Future<void> present(
    String secret, {
    required bool Function() current,
  }) async {
    if (!current()) return;
    secrets.add(secret);
    await gate?.future;
    if (!current()) return;
    onPresent?.call();
    if (close) throw StateError('synthetic sheet closed');
  }
}

class RegistrationHostedPayments extends FakePayments {
  final opened = <String>[];
  @override
  Future<void> openStripe(String url) async {
    opened.add(url);
  }
}

class ConnectPayments extends FakePayments {
  bool ready = false, statusFailure = false;
  int sessions = 0, statusReads = 0;
  @override
  Future<Map<String, dynamic>> action(
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    if (action == 'connect_session') {
      sessions++;
      return {
        'client_secret': 'synthetic_session_secret',
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
      };
    }
    if (action == 'connect_status') {
      statusReads++;
      if (statusFailure) throw StateError('synthetic offline');
      return {
        'verified': true,
        'ready': ready,
        'transfers_enabled': ready,
        'payouts_enabled': ready,
        'payouts': [],
      };
    }
    throw StateError('Unexpected hosted/payment operation');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final captureKey = GlobalKey();
  Future<void> start(
    WidgetTester tester,
    RegistrationGuardian repo,
    Size size,
    double scale, {
    GuardianBankAction? action,
    GuardianMethodSetup? methodSetup,
    String initialLocation = '/guardian?enroll=1',
    PaymentRepository? payments,
    ConnectClient? connectClient,
    FakeIdentityRepository? actorRepository,
    MonthlyImpactRepository? monthlyImpact,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    for (final family in ['Inter', 'Fraunces']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await tester.runAsync(loader.load);
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity =
        actorRepository ??
        (FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          ));
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        guardianRepositoryProvider.overrideWithValue(repo),
        if (monthlyImpact != null)
          monthlyImpactRepositoryProvider.overrideWithValue(monthlyImpact),
        guardianMethodSetupProvider.overrideWithValue(
          methodSetup ?? RegistrationMethodSetup(),
        ),
        if (connectClient != null)
          connectClientProvider.overrideWithValue(connectClient),
        if (payments != null)
          paymentRepositoryProvider.overrideWithValue(payments),
        if (payments != null)
          oneoffPaymentSheetProvider.overrideWithValue(FakeOneoffSheet()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        guardianEnabledProvider.overrideWithValue(true),
        if (action != null)
          guardianBankActionProvider.overrideWithValue(action),
        if (action != null)
          guardianBankSdkProvider.overrideWithValue(
            GuardianBankSdk(
              publishableKey: 'pk_test_synthetic',
              enabled: true,
              web: false,
              platform: TargetPlatform.android,
            ),
          ),
        routerInitialLocationProvider.overrideWithValue(initialLocation),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final providers = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .toSet();
    final imageContext = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      for (final provider in providers) {
        await precacheImage(provider, imageContext);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final path = Platform.environment['DOPA39_CAPTURE_DIR'];
    if (path == null) return;
    await tester.runAsync(() async {
      await Directory(path).create(recursive: true);
      await saveCapture(captureKey, '$path/$name.png');
    });
  }

  Future<void> authorizeRegistration(WidgetTester tester) async {
    final scroll = find
        .descendant(
          of: find.byKey(const Key('guardian-registration-content')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final key in ['registration-consent', 'method-consent']) {
      final tile = find.byKey(Key(key));
      await tester.scrollUntilVisible(tile, 250, scrollable: scroll);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Registrar y preparar método'));
  }

  for (final state in ['registered', 'canceled']) {
    for (final scale in [1.0, 1.15, 2.0]) {
      testWidgets(
        'registration membership card preserves truthful $state state at scale $scale',
        (tester) async {
          final repo = RegistrationGuardian()
            ..registrationValue = registration(
              '72000000-0000-4000-8000-000000000002',
              status: state,
            );
          await start(tester, repo, Size(scale == 2 ? 320 : 377, 852), scale);
          expect(
            find.byKey(const ValueKey('guardian-registration-membership-card')),
            findsOneWidget,
          );
          expect(find.text('Suscripción y pagos'), findsOneWidget);
          expect(find.text('Suscripción Guardián'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('guardian-registration-monthly-amount')),
            findsOneWidget,
          );
          expect(find.text('Monto mensual'), findsOneWidget);
          expect(find.text('Suscripción activa'), findsNothing);
          if (state == 'registered') {
            final scroll = find
                .descendant(
                  of: find.byKey(const Key('guardian-registration-content')),
                  matching: find.byType(Scrollable),
                )
                .first;
            for (final action in [
              find.widgetWithText(FilledButton, 'Cambiar cantidad'),
              find.widgetWithText(OutlinedButton, 'Cancelar ciclos futuros'),
            ]) {
              await tester.scrollUntilVisible(action, 180, scrollable: scroll);
              await tester.pumpAndSettle();
              expect(action.hitTestable(), findsOneWidget);
            }
          }
          if (state == 'canceled') {
            expect(find.text('Registro cancelado'), findsOneWidget);
          }
          final history = find.text('Historial de pagos');
          await tester.scrollUntilVisible(
            history,
            180,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('guardian-registration-content')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(history, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final closed in [false, true]) {
    testWidgets(
      'native setup completion closed=$closed keeps pending key until server receipt',
      (tester) async {
        const secret = 'seti_synthetic_secret_synthetic';
        final repo = RegistrationGuardian()..setupSecret = secret;
        final sdk = RegistrationMethodSetup()..close = closed;
        await start(tester, repo, const Size(377, 852), 1, methodSetup: sdk);
        final initialReads = repo.registrationReads;
        await authorizeRegistration(tester);
        await tester.pumpAndSettle();
        expect(sdk.secrets, [secret]);
        expect(repo.registrationReads, greaterThan(initialReads));
        expect(find.text('Aportación asignada'), findsNothing);
        final persisted = (await SharedPreferences.getInstance()).getString(
          'dopmi-guardian-registration:one:intent',
        )!;
        expect(persisted, isNot(contains(secret)));
        final key = repo.registrations.single['key'];
        expect(jsonDecode(persisted)['key'], key);
        expect(find.textContaining('synthetic sheet closed'), findsNothing);
        if (closed) {
          expect(
            find
                .textContaining('La preparación del método quedó pendiente')
                .hitTestable(),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('Cancelar registro pendiente'),
            250,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('guardian-registration-content')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Cancelar registro pendiente'), findsOneWidget);
        }
        await tester.tap(find.text('Continuar registro'));
        await tester.pumpAndSettle();
        expect(repo.registrations, hasLength(2));
        expect(repo.registrations.last['key'], key);
        expect(sdk.secrets, [secret, secret]);
        expect(repo.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final variant in [
    (const Size(377, 852), 1.0),
    (const Size(377, 852), 1.15),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'canceled registration opens monthly impact and returns without financial mutations scale${variant.$2}',
      (tester) async {
        final repo = CanceledImpactGuardian()
          ..registrationValue = registration(
            '72000000-0000-4000-8000-000000000002',
            status: 'canceled',
            payment: 'skipped',
          );
        final original = repo.registrationValue!;
        final monthly = FakeMonthlyImpact();
        final setup = RegistrationMethodSetup();
        await start(
          tester,
          repo,
          variant.$1,
          variant.$2,
          methodSetup: setup,
          monthlyImpact: monthly,
        );
        expect(find.text('Registro cancelado'), findsOneWidget);
        final impact = find.widgetWithText(OutlinedButton, 'Ver mi impacto');
        await tester.scrollUntilVisible(
          impact,
          150,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('guardian-registration-content')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(impact.hitTestable(), findsOneWidget);
        final router = GoRouter.of(tester.element(impact));
        final entry = router.state.uri.toString();
        await tester.tap(impact);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/impact');
        expect(router.state.uri.queryParameters['history'], '1');
        expect(monthly.personalRequests, isNotEmpty);
        expect(monthly.communityRequests, isNotEmpty);
        expect(
          find.descendant(
            of: find.byType(MonthlyImpactPanel),
            matching: find.text('Asignados de tus aportaciones'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(MonthlyImpactPanel),
            matching: find.text('Casos apoyados por la comunidad'),
          ),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.state.uri.toString(), entry);
        final canceledStatus = find.text('Registro cancelado');
        await tester.scrollUntilVisible(
          canceledStatus,
          -180,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('guardian-registration-content')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(canceledStatus);
        await tester.pumpAndSettle();
        expect(canceledStatus.hitTestable(), findsOneWidget);
        expect(identical(repo.registrationValue, original), isTrue);
        expect(repo.registrationValue!.id, registrationId);
        expect(repo.registrationValue!.status, 'canceled');
        expect(repo.financialMutations, 0);
        expect(repo.registrations, isEmpty);
        expect(repo.calls, isEmpty);
        expect(setup.secrets, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'native sheet suspension permits state refresh without another submit or sheet',
    (tester) async {
      const secret = 'seti_synthetic_secret_synthetic';
      final repo = RegistrationGuardian()..setupSecret = secret;
      final gate = Completer<void>();
      final sdk = RegistrationMethodSetup()..gate = gate;
      await start(tester, repo, const Size(377, 1800), 1, methodSetup: sdk);
      await authorizeRegistration(tester);
      await tester.pump();
      expect(sdk.secrets, [secret]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final button = tester.widget<ContributionButton>(
        find.byType(ContributionButton).first,
      );
      expect(button.onPressed, isNull);
      final query = find.widgetWithText(TextButton, 'Consultar estado');
      final scroll = find
          .descendant(
            of: find.byKey(const Key('guardian-registration-content')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(query, 200, scrollable: scroll);
      await tester.pump(const Duration(milliseconds: 100));
      expect(query.hitTestable(), findsOneWidget);
      expect(tester.widget<TextButton>(query).onPressed, isNotNull);
      final reads = repo.registrationReads;
      await tester.tap(query);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.registrationReads, greaterThan(reads));
      expect(sdk.secrets, hasLength(1));
      expect(repo.registrations, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.registrations, hasLength(1));
      expect(find.text('Aportación asignada'), findsNothing);
    },
  );

  testWidgets(
    'unavailable native setup cannot create a new request or durable draft',
    (tester) async {
      final repo = RegistrationGuardian();
      final sdk = RegistrationMethodSetup()..ready = false;
      await start(tester, repo, const Size(377, 1800), 1, methodSetup: sdk);
      await authorizeRegistration(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No iniciamos un registro nuevo.'),
        findsOneWidget,
      );
      expect(repo.registrations, isEmpty);
      expect(sdk.secrets, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-guardian-registration:one:intent',
        ),
        isNull,
      );
      expect(
        tester
            .widget<ContributionButton>(find.byType(ContributionButton).first)
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'existing hosted request remains resumable without native SDK availability',
    (tester) async {
      const key = '72000000-0000-4000-8000-000000000002';
      const url = 'https://checkout.stripe.com/synthetic';
      final repo = RegistrationGuardian()
        ..registrationValue = registration(key)
        ..checkoutUrl = url;
      final sdk = RegistrationMethodSetup()..ready = false;
      final payments = RegistrationHostedPayments();
      await start(
        tester,
        repo,
        const Size(377, 1800),
        1,
        methodSetup: sdk,
        payments: payments,
      );
      await authorizeRegistration(tester);
      await tester.pumpAndSettle();
      expect(payments.opened, [url]);
      expect(repo.registrations.single['key'], key);
      expect(sdk.secrets, isEmpty);
      expect(
        find.textContaining('no está disponible en este dispositivo'),
        findsNothing,
      );
      expect(find.text('Cancelar registro pendiente'), findsOneWidget);
    },
  );

  testWidgets(
    'unavailable existing native request keeps its key with query and cancellation access',
    (tester) async {
      const key = '72000000-0000-4000-8000-000000000002';
      final repo = RegistrationGuardian()
        ..registrationValue = registration(key)
        ..setupSecret = 'seti_synthetic_secret_synthetic';
      final sdk = RegistrationMethodSetup()..ready = false;
      await start(tester, repo, const Size(377, 1800), 1, methodSetup: sdk);
      await authorizeRegistration(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Conservamos la misma solicitud; puedes consultar'),
        findsOneWidget,
      );
      expect(repo.registrations.single['key'], key);
      expect(sdk.secrets, isEmpty);
      final scroll = find
          .descendant(
            of: find.byKey(const Key('guardian-registration-content')),
            matching: find.byType(Scrollable),
          )
          .first;
      final query = find.widgetWithText(TextButton, 'Consultar estado');
      await tester.scrollUntilVisible(query, 250, scrollable: scroll);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(query).onPressed, isNotNull);
      final reads = repo.registrationReads;
      await tester.tap(query);
      await tester.pumpAndSettle();
      expect(repo.registrationReads, greaterThan(reads));
      expect(repo.registrations, hasLength(1));
      expect(repo.registrations.single['key'], key);
      expect(sdk.secrets, isEmpty);
      final persisted = (await SharedPreferences.getInstance()).getString(
        'dopmi-guardian-registration:one:intent',
      )!;
      expect(jsonDecode(persisted)['key'], key);
      expect(persisted, isNot(contains('seti_synthetic_secret_synthetic')));
      await tester.scrollUntilVisible(
        find.text('Cancelar registro pendiente'),
        -250,
        scrollable: scroll,
      );
      expect(find.text('Cancelar registro pendiente'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Cancelar registro pendiente'),
            )
            .onPressed,
        isNotNull,
      );
      expect(repo.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sheet interruption does not override later server-confirmed registration',
    (tester) async {
      final repo = RegistrationGuardian()
        ..setupSecret = 'seti_synthetic_secret_synthetic';
      final sdk = RegistrationMethodSetup()
        ..close = true
        ..onPresent = () {
          repo.registrationValue = registration(
            repo.registrationValue!.key,
            status: 'registered',
          );
        };
      await start(tester, repo, const Size(377, 1800), 1, methodSetup: sdk);
      await authorizeRegistration(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('La preparación del método quedó pendiente'),
        findsNothing,
      );
      expect(find.text('Cancelar ciclos futuros'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-guardian-registration:one:intent',
        ),
        isNull,
      );
      expect(find.text('Aportación asignada'), findsNothing);
    },
  );

  testWidgets(
    'expired pending method can cancel registration before a new consented key',
    (tester) async {
      const oldKey = '72000000-0000-4000-8000-000000000002';
      final repo = RegistrationGuardian()
        ..registrationValue = registration(oldKey)
        ..canceledPayment = 'not_evaluated';
      await start(tester, repo, const Size(377, 1800), 1);
      await tester.tap(find.text('Cancelar registro pendiente'));
      await tester.pumpAndSettle();
      expect(find.text('Registro cancelado'), findsOneWidget);
      expect(repo.registrations, isEmpty);
      await tester.tap(find.text('Volver a registrarme'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('registration-consent')),
            )
            .value,
        false,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('method-consent')))
            .value,
        false,
      );
      await authorizeRegistration(tester);
      await tester.pumpAndSettle();
      expect(repo.registrations, hasLength(1));
      expect(repo.registrations.single['key'], isNot(oldKey));
      expect(repo.calls, isEmpty);
    },
  );

  for (final status in ['registered', 'method_pending']) {
    for (final system in [false, true]) {
      testWidgets(
        'Q38-28 root persisted $status exits system=$system without losing key',
        (tester) async {
          const key = '72000000-0000-4000-8000-000000000002';
          final draft = jsonEncode({
            'key': key,
            'gross_cents': 5000,
            'consent': true,
            'consent_version': guardianRegistrationConsent,
            'method_consent': true,
            'method_consent_version': savedCardConsent,
          });
          const storage = 'dopmi-guardian-registration:one:intent';
          SharedPreferences.setMockInitialValues({storage: draft});
          final repo = RegistrationGuardian()
            ..registrationValue = registration(key, status: status);
          final original = repo.registrationValue;
          await start(
            tester,
            repo,
            const Size(377, 852),
            1,
            initialLocation: '/guardian',
          );
          final router = GoRouter.of(
            tester.element(find.byType(Scaffold).first),
          );
          expect(router.canPop(), false);
          final beforeBack = (await SharedPreferences.getInstance()).getString(
            storage,
          );
          // Server-confirmed registration already reconciles the completed
          // draft during load; a pending method must retain its exact request.
          expect(beforeBack, status == 'method_pending' ? draft : null);
          if (system) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Regresar'));
          }
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            '/rescue-cases',
          );
          expect(
            (await SharedPreferences.getInstance()).getString(storage),
            beforeBack,
          );
          expect(repo.registrationValue, same(original));
          expect(repo.registrations, isEmpty);
          expect(repo.calls, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('direct registration route can return without prior history', (
    tester,
  ) async {
    await start(tester, RegistrationGuardian(), const Size(377, 852), 1);
    await tester.tap(find.byTooltip('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar y preparar método'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Q38-23 Q38-24 conditional summary and missing 200 views', (
    tester,
  ) async {
    final repo = RegistrationGuardian();
    await start(tester, repo, const Size(320, 640), 2);
    final scroll = find.byType(Scrollable).first;
    // Overlapping sequential views cover every block without reducing text scale.
    for (var i = 0; i < 18; i++) {
      await capture(tester, '200-register-$i');
      await tester.drag(scroll, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(find.text('Total al activar'), findsNothing);
    final first = find.byKey(const Key('registration-consent'));
    await tester.scrollUntilVisible(first, -150, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(first), alignment: 0);
    await tester.pumpAndSettle();
    await tester.tap(first);
    final second = find.byKey(const Key('method-consent'));
    await tester.scrollUntilVisible(second, 150, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(second), alignment: 0);
    await tester.pumpAndSettle();
    await tester.tap(second);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar y preparar método'));
    await tester.pumpAndSettle();
    expect(repo.registrations, hasLength(1));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(scroll).position;
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();
    await capture(tester, '200-method-pending-top');
    await tester.drag(scroll, const Offset(0, -280));
    await tester.pumpAndSettle();
    await capture(tester, '200-method-pending-notice');
    expect(find.text('Total al activar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Q38-26 punctual lower 200 through actual scroll end', (
    tester,
  ) async {
    final payments = FakePayments();
    await start(
      tester,
      RegistrationGuardian(),
      const Size(320, 640),
      2,
      initialLocation: '/contribute-case/case-one?amount_cents=5000',
      payments: payments,
    );
    final scroll = find.byType(Scrollable).first;
    final confirm = find.text('Confirmar aportación');
    await tester.scrollUntilVisible(confirm, 180, scrollable: scroll);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(payments.calls, hasLength(1));
    final key = payments.calls.single;
    final economics = find.text(
      'Dopmi descuenta el 2% del importe cobrado y los costos reales de Stripe. Si todo el neto no puede asignarse a gastos aprobados de este caso, se devuelve el pago completo.',
    );
    await tester.scrollUntilVisible(economics, 200, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(economics), alignment: 0);
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(scroll).position;
    for (var i = 0; i < 25; i++) {
      await capture(tester, 'punctual-200-economic-tail-$i');
      if (position.pixels >= position.maxScrollExtent - 1) break;
      position.jumpTo(
        (position.pixels + position.viewportDimension * .6).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    expect(find.text('Consultar resultado').hitTestable(), findsOneWidget);
    expect(find.text('Ver mi historial').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Consultar resultado'));
    await tester.pumpAndSettle();
    expect(find.text('Pago en procesamiento'), findsOneWidget);
    final pendingScroll = find.byType(Scrollable).first;
    final pendingPosition = tester
        .state<ScrollableState>(pendingScroll)
        .position;
    for (var i = 0; i < 25; i++) {
      await capture(tester, 'punctual-200-server-pending-lower-$i');
      if (pendingPosition.pixels >= pendingPosition.maxScrollExtent - 1) break;
      pendingPosition.jumpTo(
        (pendingPosition.pixels + pendingPosition.viewportDimension * .6).clamp(
          pendingPosition.minScrollExtent,
          pendingPosition.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(pendingPosition.pixels, closeTo(pendingPosition.maxScrollExtent, 1));
    expect(find.text('Ir al historial').hitTestable(), findsOneWidget);
    expect(payments.calls, [key]);
    expect(find.text('Pago confirmado'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Q38-25 missing lower 200 actions', (tester) async {
    final repo = RegistrationGuardian()
      ..registrationValue = registration(
        '72000000-0000-4000-8000-000000000002',
        status: 'registered',
        payment: 'requires_action',
      );
    await start(
      tester,
      repo,
      const Size(320, 640),
      2,
      initialLocation: '/impact',
    );
    final scroll = find.byType(Scrollable).first;
    // Only lower Impact views missing from prior packet, with overlap.
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await capture(tester, 'impact-200-lower-$i');
      await tester.drag(scroll, const Offset(0, -260));
      await tester.pumpAndSettle();
    }
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push('/guardian');
    await tester.pumpAndSettle();
    final recovery = find.byType(Scrollable).first;
    await tester.drag(recovery, const Offset(0, -280));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await capture(tester, 'recovery-200-lower-$i');
      await tester.drag(recovery, const Offset(0, -240));
      await tester.pumpAndSettle();
    }
    final registrationScroll = find
        .descendant(
          of: find.byKey(const Key('guardian-registration-content')),
          matching: find.byType(Scrollable),
        )
        .first;
    final bankAction = find.text('Autorizar con mi banco');
    await tester.scrollUntilVisible(
      bankAction,
      -180,
      scrollable: registrationScroll,
    );
    await tester.pumpAndSettle();
    expect(bankAction.hitTestable(), findsOneWidget);
    await capture(tester, 'recovery-200-bank-action-visible');
    final cancelAction = find.widgetWithText(
      OutlinedButton,
      'Cancelar ciclos futuros',
    );
    await tester.scrollUntilVisible(
      cancelAction,
      180,
      scrollable: registrationScroll,
    );
    await tester.pumpAndSettle();
    expect(cancelAction.hitTestable(), findsOneWidget);
    await capture(tester, 'recovery-200-cancel-action-visible');
    final query = find.widgetWithText(TextButton, 'Consultar estado');
    await tester.scrollUntilVisible(query, 180, scrollable: registrationScroll);
    await tester.pumpAndSettle();
    expect(query.hitTestable(), findsOneWidget);
    expect(tester.widget<TextButton>(query).onPressed, isNotNull);
    await capture(tester, 'recovery-200-query-action-visible');
    final reads = repo.registrationReads;
    await tester.tap(query);
    await tester.pumpAndSettle();
    expect(repo.registrationReads, greaterThan(reads));
    expect(repo.registrations, isEmpty);
    expect(repo.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Connect real button actor switch blocks late secret and cleans up',
    (tester) async {
      final payments = ConnectPayments();
      final nativeExit = Completer<void>();
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      Future<String> Function()? lateFetch;
      var logouts = 0;
      final client = ConnectClient(
        key: 'pk_test_synthetic',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () => payments.action('connect_session'),
        initialize: (_, fetch) async {
          lateFetch = fetch;
          await fetch();
        },
        present: () => nativeExit.future,
        logout: () async {
          logouts++;
        },
      );
      await start(
        tester,
        RegistrationGuardian(),
        const Size(377, 852),
        1,
        initialLocation: '/connect',
        payments: payments,
        connectClient: client,
        actorRepository: identity,
      );
      final button = find.text('Completar datos en Stripe');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(payments.sessions, 1);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(lateFetch!(), throwsFormatException);
      expect(payments.sessions, 1);
      nativeExit.complete();
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(payments.calls, isEmpty);
      expect(
        find.text('Cuenta habilitada para recibir aportaciones de prueba'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 1.15, 2.0]) {
    testWidgets('Connect real button full matrix scale$scale', (tester) async {
      final payments = ConnectPayments();
      final nativeExit = Completer<void>();
      var presentations = 0, logouts = 0;
      final client = ConnectClient(
        key: 'pk_test_synthetic',
        enabled: true,
        web: false,
        platform: TargetPlatform.android,
        session: () => payments.action('connect_session'),
        initialize: (_, fetch) async {
          await fetch();
        },
        present: () async {
          presentations++;
          await nativeExit.future;
        },
        logout: () async {
          logouts++;
        },
      );
      await start(
        tester,
        RegistrationGuardian(),
        scale == 2 ? const Size(320, 640) : const Size(377, 852),
        scale,
        initialLocation: '/connect',
        payments: payments,
        connectClient: client,
      );
      Future<void> range(String state) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.minScrollExtent);
        await tester.pump();
        position.jumpTo(position.minScrollExtent);
        await tester.pump();
        for (var i = 0; i < 30; i++) {
          await capture(tester, 'connect-$scale-$state-$i');
          if (position.pixels >= position.maxScrollExtent - 1) break;
          position.jumpTo(
            (position.pixels + position.viewportDimension * .6).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
          await tester.pump();
        }
        expect(position.pixels, closeTo(position.maxScrollExtent, 1));
        expect(find.byType(FilledButton).last.hitTestable(), findsOneWidget);
      }

      await range('not-ready');
      await tester.tap(find.text('Completar datos en Stripe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(presentations, 1);
      expect(payments.sessions, 1);
      await range('native-pending');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(presentations, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(presentations, 1);
      nativeExit.complete();
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(payments.statusReads, greaterThanOrEqualTo(2));
      expect(
        find.text('Cuenta habilitada para recibir aportaciones de prueba'),
        findsNothing,
      );
      await range('returned-not-ready');
      payments.statusFailure = true;
      final refresh = find.text('Actualizar estado');
      await tester.scrollUntilVisible(
        refresh,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(refresh), alignment: .5);
      await tester.pump();
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      await range('status-error');
      expect(
        find.text('Cuenta habilitada para recibir aportaciones de prueba'),
        findsNothing,
      );
      payments.statusFailure = false;
      payments.ready = true;
      final retry = find.text('Volver a intentar');
      await tester.scrollUntilVisible(
        retry,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(retry), alignment: .5);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(
        find.text('Cuenta habilitada para recibir aportaciones de prueba'),
        findsOneWidget,
      );
      await range('server-ready');
      expect(payments.sessions, 1);
      expect(payments.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 1.15, 2.0]) {
    for (final unknown in [false, true]) {
      testWidgets('Q38-25 refund unknown$unknown scale$scale', (tester) async {
        final repo = RegistrationGuardian()
          ..registrationValue = registration(
            '72000000-0000-4000-8000-000000000002',
            status: 'registered',
            payment: 'refund_pending',
          )
          ..failRegistration = unknown;
        await start(
          tester,
          repo,
          scale == 2 ? const Size(320, 640) : const Size(377, 852),
          scale,
          initialLocation: '/profile',
        );
        final entry = find.text(
          unknown ? 'Tu membresía Guardián' : 'Tu registro Guardián',
        );
        await tester.scrollUntilVisible(
          entry,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(entry), alignment: 0);
        await tester.pumpAndSettle();
        await capture(tester, 'profile-$scale-unknown$unknown');
        expect(find.text('Sé un Guardián'), findsNothing);
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        router.go('/impact');
        await tester.pumpAndSettle();
        await capture(tester, 'impact-$scale-unknown$unknown-top');
        if (scale == 2) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -240),
          );
          await tester.pumpAndSettle();
          await capture(tester, 'impact-$scale-unknown$unknown-tail');
        }
        if (unknown) {
          repo.failRegistration = false;
          final retry = find.text('Volver a intentar');
          await tester.scrollUntilVisible(
            retry,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(find.text(repo.registrationValue!.summary), findsOneWidget);
          await capture(tester, 'impact-$scale-recovered-refund');
        } else {
          expect(find.text(repo.registrationValue!.summary), findsOneWidget);
        }
        expect(repo.registrations, isEmpty);
        expect(repo.calls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final scale in [1.0, 1.15, 2.0]) {
    testWidgets('punctual evidence lost response scale$scale', (tester) async {
      final payments = FakePayments();
      await start(
        tester,
        RegistrationGuardian(),
        scale == 2 ? const Size(320, 640) : const Size(377, 852),
        scale,
        initialLocation: '/contribute-case/case-one?amount_cents=5000',
        payments: payments,
      );
      final confirm = find.text('Confirmar aportación');
      await tester.scrollUntilVisible(
        confirm,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'punctual-$scale-review');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(payments.calls, hasLength(1));
      final key = payments.calls.single;
      final scroll = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scroll).position;
      FocusManager.instance.primaryFocus?.unfocus();
      position.jumpTo(position.minScrollExtent);
      await tester.pumpAndSettle();
      position.jumpTo(position.minScrollExtent);
      await tester.pumpAndSettle();
      for (var i = 0; i < (scale == 2 ? 7 : 4); i++) {
        await capture(tester, 'punctual-$scale-uncertain-$i');
        await tester.drag(scroll, const Offset(0, -260));
        await tester.pumpAndSettle();
      }
      expect(
        find.textContaining('En proceso. Consulta el mismo intento'),
        findsOneWidget,
      );
      expect(find.text('Pago confirmado'), findsNothing);
      payments.fail = false;
      payments.omitUrl = true;
      final retry = find.text('Continuar mi aportación');
      await tester.scrollUntilVisible(retry, -150, scrollable: scroll);
      await Scrollable.ensureVisible(tester.element(retry), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(payments.calls, [key, key]);
      expect(find.text('Pago en procesamiento'), findsOneWidget);
      await capture(tester, 'punctual-$scale-server-pending');
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 1.15, 2.0]) {
    for (final state in [
      'requires_action',
      'processing',
      'skipped',
      'canceled',
    ]) {
      testWidgets('profile impact evidence scale$scale state$state', (
        tester,
      ) async {
        final repo = RegistrationGuardian()
          ..registrationValue = registration(
            '72000000-0000-4000-8000-000000000002',
            status: 'registered',
            payment: state,
          );
        await start(
          tester,
          repo,
          scale == 2 ? const Size(320, 640) : const Size(377, 852),
          scale,
          initialLocation: '/profile',
        );
        final entry = find.text('Tu registro Guardián');
        await tester.scrollUntilVisible(
          entry,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(entry), alignment: 0);
        await tester.pumpAndSettle();
        await capture(tester, 'profile-$scale-$state-top');
        if (scale == 2) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -220),
          );
          await tester.pumpAndSettle();
          await capture(tester, 'profile-$scale-$state-tail');
        }
        expect(find.text(repo.registrationValue!.summary), findsOneWidget);
        if (state == 'canceled') {
          expect(
            find.textContaining('Este intento terminó sin cobro.'),
            findsOneWidget,
          );
          expect(find.textContaining('Registro cancelado.'), findsNothing);
          expect(find.textContaining('Registro preparado.'), findsNothing);
        }
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        router.go('/impact');
        await tester.pumpAndSettle();
        expect(find.text(repo.registrationValue!.summary), findsOneWidget);
        await capture(tester, 'impact-$scale-$state-top');
        await tester.scrollUntilVisible(
          find.text('Consultar registro Guardián'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await capture(tester, 'impact-$scale-$state-action');
        await tester.tap(find.text('Consultar registro Guardián'));
        await tester.pumpAndSettle();
        expect(find.text('Aportación asignada'), findsNothing);
        await capture(tester, 'recovery-$scale-$state');
        repo.registrationValue = registration(
          '72000000-0000-4000-8000-000000000002',
          status: 'registered',
          payment: 'skipped',
        );
        await tester.tap(find.byTooltip('Regresar'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Sin deuda ni recobro'), findsOneWidget);
        expect(repo.registrations, isEmpty);
        expect(repo.calls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final variant in [
    (name: 'normal', size: const Size(377, 852), scale: 1.0),
    (name: '115', size: const Size(377, 852), scale: 1.15),
    (name: '200', size: const Size(320, 640), scale: 2.0),
  ]) {
    testWidgets(
      'registration real route ${variant.name}: independent consents, no capacity gate or charge, sequential access',
      (tester) async {
        final repo = RegistrationGuardian();
        await start(tester, repo, variant.size, variant.scale);
        expect(find.text('Registrar y preparar método'), findsOneWidget);
        await capture(tester, '${variant.name}-top');
        final first = find.byKey(const Key('registration-consent')),
            second = find.byKey(const Key('method-consent'));
        await tester.scrollUntilVisible(first, 250);
        await tester.pumpAndSettle();
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(repo.registrations, isEmpty);
        await tester.tap(find.text('Registrar y preparar método'));
        await tester.pumpAndSettle();
        expect(repo.registrations, isEmpty);
        await tester.scrollUntilVisible(second, 250);
        await tester.pumpAndSettle();
        await capture(tester, '${variant.name}-consents');
        await tester.tap(second);
        await tester.pumpAndSettle();
        await capture(tester, '${variant.name}-ready');
        await tester.scrollUntilVisible(find.text('Consultar estado'), 250);
        await tester.pumpAndSettle();
        await capture(tester, '${variant.name}-consent-tail');
        await tester.tap(find.text('Registrar y preparar método'));
        await tester.pumpAndSettle();
        expect(repo.registrations.length, 1);
        expect(repo.registrations.single['consent'], true);
        expect(repo.registrations.single['method_consent'], true);
        expect(repo.calls, isEmpty);
        expect(find.text('Aportación asignada'), findsNothing);
        expect(tester.takeException(), isNull);
        await capture(tester, '${variant.name}-method-pending');
      },
    );
  }
  testWidgets(
    'lost register response preserves exact private key and resumes without old checkout',
    (tester) async {
      final repo = RegistrationGuardian()..lose = true;
      await start(tester, repo, const Size(377, 1800), 1);
      for (final key in ['registration-consent', 'method-consent']) {
        final tile = find.byKey(Key(key));
        await tester.scrollUntilVisible(tile, 250);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Registrar y preparar método'));
      await tester.pumpAndSettle();
      final first = repo.registrations.single;
      final saved = jsonDecode(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-guardian-registration:one:intent',
        )!,
      );
      expect(saved['key'], first['key']);
      expect(saved.containsKey('client_secret'), false);
      await tester.ensureVisible(find.text('Consultar estado'));
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      repo.lose = false;
      await tester.tap(find.text('Continuar registro'));
      await tester.pumpAndSettle();
      expect(repo.registrations.length, 2);
      expect(repo.registrations.last, first);
      expect(repo.calls, isEmpty);
      expect(find.text('Aportación asignada'), findsNothing);
    },
  );
  testWidgets(
    'cancellation before confirmed contribution preserves uncertain previous attempt',
    (tester) async {
      final repo = RegistrationGuardian()
        ..registrationValue = registration(
          '72000000-0000-4000-8000-000000000002',
          status: 'registered',
          payment: 'processing',
        );
      await start(tester, repo, const Size(377, 1800), 1);
      await tester.tap(find.text('Cancelar ciclos futuros'));
      await tester.pumpAndSettle();
      expect(find.text('Registro cancelado'), findsOneWidget);
      expect(
        find.textContaining('intento anterior sigue en conciliación'),
        findsOneWidget,
      );
      expect(find.textContaining('Próxima evaluación:'), findsNothing);
      expect(repo.calls, isEmpty);
    },
  );
  testWidgets(
    'pending registration announces processing and disables another send until server receipt',
    (tester) async {
      final gate = Completer<void>();
      final repo = RegistrationGuardian()..responseGate = gate;
      await start(tester, repo, const Size(377, 852), 1);
      for (final key in ['registration-consent', 'method-consent']) {
        final tile = find.byKey(Key(key));
        await tester.scrollUntilVisible(tile, 250);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Registrar y preparar método'));
      await tester.pump();
      expect(repo.registrations.length, 1);
      expect(
        tester
            .widget<ContributionButton>(find.byType(ContributionButton).first)
            .onPressed,
        null,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1600));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('En proceso…'), findsOneWidget);
      await capture(tester, 'normal-processing');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Elige tu apoyo'), findsOneWidget);
      expect(repo.registrations.length, 1);
      expect(repo.calls, isEmpty);
      final persisted = jsonDecode(
        (await SharedPreferences.getInstance()).getString(
          'dopmi-guardian-registration:one:intent',
        )!,
      );
      expect(persisted['key'], repo.registrations.single['key']);
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.registrations.length, 1);
      expect(repo.calls, isEmpty);
      expect(find.text('Aportación asignada'), findsNothing);
    },
  );
  testWidgets(
    'amount changes before first charge require new consent, without a second registration',
    (tester) async {
      final repo = RegistrationGuardian()
        ..registrationValue = registration(
          '72000000-0000-4000-8000-000000000002',
          status: 'registered',
        );
      await start(tester, repo, const Size(377, 1800), 1);
      await tester.tap(find.text('Cambiar cantidad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'$200'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar monto'));
      await tester.pumpAndSettle();
      expect(repo.changedAmount, null);
      final consent = find.byKey(const Key('registration-consent'));
      await tester.scrollUntilVisible(consent, 250);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar monto'));
      await tester.pumpAndSettle();
      expect(repo.changedAmount, 20000);
      expect(repo.registrations, isEmpty);
      expect(repo.calls, isEmpty);
      expect(find.text(r'$200 MXN / mes', findRichText: true), findsOneWidget);
    },
  );
  testWidgets(
    'bank SDK pending across suspension permits server refresh without another SDK request',
    (tester) async {
      final gate = Completer<void>();
      var requests = 0;
      final repo = RegistrationGuardian()
        ..registrationValue = registration(
          '72000000-0000-4000-8000-000000000002',
          status: 'registered',
          payment: 'requires_action',
        );
      final action = GuardianBankAction(
        request: (id, attempt) async {
          requests++;
          return {
            'id': id,
            'attempt_id': attempt,
            'state': 'requires_action',
            'client_secret': 'pi_synthetic_secret_synthetic',
          };
        },
        authenticate: (_) => gate.future,
        reload: repo.registrationState,
      );
      await start(tester, repo, const Size(377, 1800), 1, action: action);
      await tester.tap(find.text('Autorizar con mi banco'));
      await tester.pump();
      expect(requests, 1);
      repo.registrationValue = registration(
        repo.registrationValue!.key,
        status: 'registered',
        payment: 'processing',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultar estado'));
      await tester.pumpAndSettle();
      expect(find.text('En proceso'), findsOneWidget);
      expect(find.text('Aportación asignada'), findsNothing);
      expect(requests, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(repo.calls, isEmpty);
    },
  );
}
