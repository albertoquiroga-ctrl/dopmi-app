import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/verification_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

class StateVerificationRescue extends FakeRescue {
  String status = 'submitted';
  int reads = 0;
  bool fail = false;
  @override
  Future<Json> detail(String id) async {
    reads++;
    if (fail) throw const FormatException('Sin conexión de prueba');
    final data = await super.detail(id);
    return {
      ...data,
      'record': {...Json.from(data['record']), 'status': status},
    };
  }
}

void resumeVerification(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets(
    'review home action stays reachable at 200 percent and opens the real rescuer home',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = StateVerificationRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/verification-id',
        rescue: repo,
      );
      final router = GoRouter.of(
        tester.element(find.byType(VerificationStateScreen)),
      );
      final home = find.text('Volver al inicio');
      await tester.scrollUntilVisible(
        home,
        200,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('verification-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(home);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/rescuer');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verification resume reads the server and a failure removes stale approval',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = StateVerificationRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/verification-id',
        rescue: repo,
      );
      expect(find.text('Estamos revisando tu información'), findsOneWidget);
      expect(repo.reads, 1);
      repo.status = 'approved';
      resumeVerification(tester);
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      expect(find.text('Cuenta verificada'), findsOneWidget);
      expect(find.text('Retirar a borrador'), findsNothing);
      await tester.tap(find.text('Consultar expediente'));
      await tester.pumpAndSettle();
      final phone = find.byKey(const ValueKey('verification-field-phone'));
      await tester.scrollUntilVisible(
        phone,
        200,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('verification-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<TextField>(phone).enabled, isFalse);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(VerificationStateScreen), findsOneWidget);
      repo.fail = true;
      await tester.tap(find.text('Recargar estado'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta verificada'), findsNothing);
      expect(find.text('Publicar un caso'), findsNothing);
      expect(find.text('Volver a intentar'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta verificada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'resume never overwrites an authored editable verification draft',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = StateVerificationRescue()..status = 'draft';
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/verification-id',
        rescue: repo,
      );
      final phone = find.byKey(const ValueKey('verification-field-phone'));
      await tester.scrollUntilVisible(
        phone,
        200,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('verification-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(phone, '8188888888');
      resumeVerification(tester);
      await tester.pumpAndSettle();
      expect(repo.reads, 1);
      expect(tester.widget<TextField>(phone).controller!.text, '8188888888');
      final experience = find.byKey(
        const ValueKey('verification-field-experience'),
      );
      await tester.scrollUntilVisible(
        experience,
        200,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('verification-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      const authored =
          'He acompañado rescates y recuperación de mascotas. '
          'Conservo los comprobantes y coordino sus consultas veterinarias.';
      await tester.enterText(experience, authored);
      await tester.pumpAndSettle();
      final decoration = find.descendant(
        of: experience,
        matching: find.byType(InputDecorator),
      );
      expect(tester.getSize(decoration).height, greaterThanOrEqualTo(112));
      resumeVerification(tester);
      await tester.pumpAndSettle();
      expect(repo.reads, 1);
      expect(tester.widget<TextField>(experience).controller!.text, authored);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Hay cambios sin guardar'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(experience).controller!.text, authored);
      await tester.scrollUntilVisible(
        phone,
        -200,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('verification-form-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(phone).controller!.text, '8188888888');
      expect(tester.takeException(), isNull);
    },
  );
}
