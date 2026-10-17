import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_registration.dart';
import 'package:dopmi_mobile/features/payments/guardian_registration_method_control.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_method_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;
import 'guardian_registration_repository_test.dart'
    show projection, registrationId;

class MethodControlRepo extends FakeGuardian {
  final methodCalls = <Json>[];
  Json? draft;
  bool applied = false, loseResponse = false;
  int statusReads = 0;
  GuardianRegistration get projected => GuardianRegistration.fromJson({
    ...projection('registered'),
    'revision': applied ? 2 : 1,
    'method_status': 'saved',
    if (draft != null)
      'method_change': {
        'key': draft!['key'],
        'status': applied ? 'applied' : 'pending',
        'revision': applied ? 2 : 1,
      },
  });
  Json receipt() => {
    'id': registrationId,
    'key': draft!['key'],
    'status': applied ? 'applied' : 'pending',
    'registration_revision': applied ? 2 : 1,
    'method_status': applied ? 'saved' : 'requires_payment_method',
    if (!applied) 'setup_client_secret': 'seti_synthetic_secret_synthetic',
  };
  @override
  Future<Json> submitRegistrationMethod(Json value) async {
    methodCalls.add(Json.from(value));
    draft = Json.from(value);
    if (loseResponse) {
      loseResponse = false;
      throw StateError('response lost');
    }
    return receipt();
  }

  @override
  Future<Json> registrationMethodStatus(Json value) async {
    statusReads++;
    return receipt();
  }

  @override
  Future<GuardianRegistration?> registrationState() async => projected;
}

class MethodControlSdk implements GuardianMethodSetup {
  MethodControlSdk(this.run);
  final Future<void> Function() run;
  int shown = 0;
  @override
  bool get available => true;
  @override
  Future<void> present(
    String secret, {
    required bool Function() current,
  }) async {
    expect(secret, 'seti_synthetic_secret_synthetic');
    if (!current()) return;
    shown++;
    await run();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<FakeIdentityRepository> start(
    WidgetTester tester,
    MethodControlRepo repo,
    MethodControlSdk sdk, {
    double scale = 1,
  }) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    var state = repo.projected;
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        guardianRepositoryProvider.overrideWithValue(repo),
        guardianMethodSetupProvider.overrideWithValue(sdk),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, update) => GuardianRegistrationMethodControl(
                  owner: 'one',
                  registration: state,
                  onUpdated: () async {
                    update(() => state = repo.projected);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return identity;
  }

  Future<void> authorize(WidgetTester tester) async {
    await tester.tap(find.text('Cambiar tarjeta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autorizar y continuar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    '200 percent consent can be read to its end without starting an operation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MethodControlRepo();
      final sdk = MethodControlSdk(() async {});
      await start(tester, repo, sdk, scale: 2);
      await tester.tap(find.text('Cambiar tarjeta'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.scrollable, isTrue);
      final consent = find.textContaining('Autorizo guardar y usar');
      await tester.drag(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(consent);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: paragraph.text.toPlainText().length - 20,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      );
      expect(boxes, isNotEmpty);
      final finalLine = paragraph.localToGlobal(Offset(0, boxes.last.bottom));
      final dialogBounds = tester.getRect(find.byType(AlertDialog));
      expect(finalLine.dy, lessThanOrEqualTo(dialogBounds.bottom));
      await tester.ensureVisible(find.text('Volver'));
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(repo.methodCalls, isEmpty);
      expect(sdk.shown, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saving a method is not a charge or success until its matching server projection applies',
    (tester) async {
      final repo = MethodControlRepo();
      final sdk = MethodControlSdk(() async {});
      await start(tester, repo, sdk);
      await authorize(tester);
      expect(sdk.shown, 1);
      expect(
        find.text('Tarjeta de Guardián actualizada. No se realizó un cargo.'),
        findsNothing,
      );
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(
        'dopmi-guardian-method:one:$registrationId',
      );
      expect(stored, isNotNull);
      expect(stored, isNot(contains('secret')));
      final key = (jsonDecode(stored!) as Map)['key'];
      expect(repo.calls, isEmpty);
      repo.applied = true;
      await tester.tap(find.text('Continuar el mismo cambio'));
      await tester.pumpAndSettle();
      expect(repo.methodCalls.map((value) => value['key']).toSet(), {key});
      expect(
        find.text('Tarjeta de Guardián actualizada. No se realizó un cargo.'),
        findsOneWidget,
      );
      expect(
        prefs.getString('dopmi-guardian-method:one:$registrationId'),
        isNull,
      );
      expect(repo.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server pending method is recovered with the same key after local preferences are missing',
    (tester) async {
      final repo = MethodControlRepo()
        ..draft = {
          'id': registrationId,
          'key': '72000000-0000-4000-8000-000000000099',
          'revision': 1,
          'consent': true,
          'consent_version': savedCardConsent,
        };
      final sdk = MethodControlSdk(() async {});
      await start(tester, repo, sdk);
      expect(repo.statusReads, 1);
      expect(repo.methodCalls, isEmpty);
      expect(sdk.shown, 0);
      expect(find.text('Continuar el mismo cambio'), findsOneWidget);
      await tester.tap(find.text('Continuar el mismo cambio'));
      await tester.pumpAndSettle();
      expect(
        repo.methodCalls.single['key'],
        '72000000-0000-4000-8000-000000000099',
      );
      expect(repo.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lost response preserves the original method operation and retry never generates a different key',
    (tester) async {
      final repo = MethodControlRepo()..loseResponse = true;
      final sdk = MethodControlSdk(() async {});
      await start(tester, repo, sdk);
      await authorize(tester);
      expect(sdk.shown, 0);
      final firstKey = repo.methodCalls.single['key'];
      await tester.tap(find.text('Continuar el mismo cambio'));
      await tester.pumpAndSettle();
      expect(repo.methodCalls.map((row) => row['key']), [firstKey, firstKey]);
      expect(sdk.shown, 1);
      expect(repo.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a late sheet result after an owner switch cannot confirm or mutate the next account',
    (tester) async {
      final repo = MethodControlRepo();
      final gate = Completer<void>();
      final sdk = MethodControlSdk(() => gate.future);
      final identity = await start(tester, repo, sdk);
      await tester.tap(find.text('Cambiar tarjeta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autorizar y continuar'));
      for (var i = 0; i < 10 && sdk.shown == 0; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(sdk.shown, 1);
      identity.changes.add(
        const IdentityEvent(
          Identity('other', 'other@example.test', verified: true),
        ),
      );
      gate.complete();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.statusReads, 0);
      expect(
        find.text('Tarjeta de Guardián actualizada. No se realizó un cargo.'),
        findsNothing,
      );
      expect(repo.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
