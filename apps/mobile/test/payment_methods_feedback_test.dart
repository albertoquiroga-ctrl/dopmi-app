import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_methods_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;
import 'payments_test.dart' show pumpUntil;

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  testWidgets(
    'failed card inventory keeps retry available without claiming no saved cards',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeGuardian()..failCards = true;
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          guardianRepositoryProvider.overrideWithValue(repo),
          guardianEnabledProvider.overrideWithValue(true),
          routerInitialLocationProvider.overrideWithValue(
            '/settings/payment-methods',
          ),
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
      await pumpUntil(tester, find.text('Métodos de pago'));
      await tester.pumpAndSettle();
      const inventoryError =
          'No se pudieron consultar tus tarjetas. Actualiza el estado para reintentar.';
      expect(find.text(inventoryError), findsOneWidget);
      expect(
        find.text('No se pudo confirmar tu método de pago.'),
        findsOneWidget,
      );
      expect(find.text('Aún no tienes tarjetas guardadas.'), findsNothing);

      final before = repo.reads;
      await tester.tap(find.text('Actualizar estado'));
      await tester.pumpAndSettle();
      expect(repo.reads, before + 1);
      expect(find.text(inventoryError), findsOneWidget);
      expect(find.text('Aún no tienes tarjetas guardadas.'), findsNothing);
      expect(repo.calls, isEmpty);
      expect(repo.opened, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final large in [false, true]) {
    testWidgets(
      'feedback is immediate, overlays without overflow and expires at 2600ms: large=$large',
      (tester) async {
        tester.view.physicalSize = large
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var shown = true, finished = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Inter'),
            home: MediaQuery(
              data: MediaQueryData(
                size: large ? const Size(320, 640) : const Size(377, 852),
                textScaler: TextScaler.linear(large ? 2 : 1),
              ),
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: Stack(
                    children: [
                      if (shown)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: PaymentMethodsFeedback(
                            message: 'Método predeterminado actualizado',
                            onDone: () => setState(() {
                              shown = false;
                              finished++;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byType(PaymentMethodsFeedback));
        expect(rect.left, 16);
        expect(rect.right, (large ? 320 : 377) - 16);
        expect(rect.bottom, (large ? 640 : 852) - 24);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(find.text('Método predeterminado actualizado'), findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Método predeterminado actualizado'),
        );
        expect(
          paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 7, extentOffset: 21),
          ),
          hasLength(1),
          reason: 'El anuncio debe conservar predeterminado completo al 200%.',
        );
        await tester.pump(const Duration(milliseconds: 2599));
        expect(finished, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(finished, 1);
        expect(find.byType(PaymentMethodsFeedback), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('unmount cancels pending private result announcement', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentMethodsFeedback(
          message: 'Tarjeta eliminada.',
          visible: false,
          onDone: () => finished++,
        ),
      ),
    );
    expect(find.text('Tarjeta eliminada.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(finished, 0);
  });
}
