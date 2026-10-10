import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_actions_test.dart' show ReceiptReportCommunity;
import 'fake_identity_repository.dart';
import 'payments_test.dart' show FakePayments;
import 'rescue_test.dart' show FakeRescue, FakeCaseUpdates;

void main() {
  for (final spec in [
    (
      '/people/owner',
      'rescuer',
      'owner',
      'Reportar perfil',
      'Reportar rescatista',
    ),
    (
      '/adoptions/post',
      'adoption',
      'post',
      'Reportar publicación',
      'Reportar publicación',
    ),
    ('/rescue-cases/case-one', 'case', 'case-one', 'Reportar', 'Reportar caso'),
  ]) {
    testWidgets(
      'actual ${spec.$2} report retains motive on failure and only acknowledges server receipt',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final repo = ReceiptReportCommunity();
        final payments = FakePayments();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(repo),
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
            paymentRepositoryProvider.overrideWithValue(payments),
            guardianEnabledProvider.overrideWithValue(false),
            routerInitialLocationProvider.overrideWithValue(spec.$1),
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
        final trigger = find.text(spec.$4);
        await tester.scrollUntilVisible(
          trigger,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(trigger), alignment: .35);
        await tester.pumpAndSettle();
        expect(trigger.hitTestable(), findsOneWidget);
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text(spec.$5),
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byType(TextField),
          'Motivo para revisión privada',
        );
        final send = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(FilledButton),
        );
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        await tester.tap(send);
        await tester.pump();
        expect(repo.requests.single, {
          'type': spec.$2,
          'id': spec.$3,
          'reason': 'other',
          'details': 'Motivo para revisión privada',
        });
        expect(tester.widget<FilledButton>(send).onPressed, isNull);
        final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
        expect(tester.widget<OutlinedButton>(cancel).onPressed, isNull);
        final close = find.descendant(
          of: find.byTooltip('Cerrar'),
          matching: find.byType(TextButton),
        );
        expect(tester.widget<TextButton>(close).onPressed, isNull);
        expect(find.text('Recibimos tu reporte para revisión.'), findsNothing);
        repo.pending.single.completeError(
          Exception('fixture network unavailable'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Motivo para revisión privada',
        );
        expect(find.text('Recibimos tu reporte para revisión.'), findsNothing);
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        await tester.tap(send);
        await tester.pump();
        expect(repo.requests.length, 2);
        expect(repo.requests.last, repo.requests.first);
        repo.pending.last.complete('119314cd-95b2-4c92-b7dd-5a9d820871d9');
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.text('Recibimos tu reporte para revisión.'),
          findsOneWidget,
        );
        expect(container.read(routerProvider).state.uri.path, spec.$1);
        expect(payments.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
