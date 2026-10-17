import 'dart:io';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/payments/payment_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';

import 'capture_design_test.dart' show saveCapture;
import 'capture_b3_test.dart' show CaptureImpactRescue;

// Actual result component with explicitly synthetic server projections.
// No Stripe, network, payment, notification, or account operation is performed.
void main() {
  for (final scale in [1.0, 1.15, 2.0]) {
    for (final state in [
      'pending',
      'assigned',
      'canceled',
      'refund-pending',
      'refunded',
    ]) {
      testWidgets('B4 result $state scale=$scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scale == 2
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
          final loader = FontLoader(family)
            ..addFont(
              rootBundle.load(
                family == 'MaterialIcons'
                    ? 'fonts/MaterialIcons-Regular.otf'
                    : 'assets/fonts/$family.ttf',
              ),
            );
          await tester.runAsync(loader.load);
        }
        final Json value = {
          'contribution_scope': 'case',
          'created_at': '2026-10-17T16:00:00Z',
          if (state == 'assigned') 'processed_at': '2026-10-17T16:01:00Z',
          'payment_status': switch (state) {
            'assigned' || 'refund-pending' => 'confirmed',
            'refunded' => 'refunded',
            'canceled' => 'canceled',
            _ => 'pending',
          },
          'payment_state': state == 'pending' ? 'processing' : 'succeeded',
          'gross_cents': 10000,
          'platform_fee_cents': state == 'pending' ? null : 200,
          'stripe_fee_cents': state == 'pending' ? null : 600,
          'allocated_cents': state == 'assigned' ? 9200 : 0,
          'refund_status': state == 'refund-pending'
              ? 'pending'
              : state == 'refunded'
              ? 'refunded'
              : 'none',
          'refund_cents': state == 'refunded' ? 10000 : 0,
          'transfer_status': state == 'assigned'
              ? 'transferred'
              : 'not_started',
          'case_allocations': [
            if (state == 'assigned') ...[
              {
                'title': 'Consulta veterinaria aprobada',
                'allocated_cents': 5000,
                'reversed_cents': 0,
              },
              {
                'title': 'Medicamentos aprobados',
                'allocated_cents': 4200,
                'reversed_cents': 0,
              },
            ],
          ],
        };
        final key = GlobalKey();
        var actions = 0;
        final photo = await tester.runAsync(
          () => File('tool/fixtures/milo.png').readAsBytes(),
        );
        final rescue = CaptureImpactRescue();
        final runtime = PhotoRuntime(
          store: MemoryPhotoStore(),
          actor: 'synthetic',
          download: (_, _) async => photo!,
        );
        final container = ProviderContainer(
          overrides: [
            rescueRepositoryProvider.overrideWithValue(rescue),
            photoRuntimeProvider.overrideWithValue(runtime),
          ],
        );
        addTearDown(() {
          container.dispose();
          runtime.dispose();
        });
        await tester.runAsync(
          () => runtime.load(
            rescuePhotoSource(rescue, 'synthetic/case-one.png'),
            width: 384,
          ),
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dopmiTheme(),
                home: PaymentResultPage(
                  value: value,
                  refresh: () => actions++,
                  back: () => actions++,
                  caseId: 'synthetic-case',
                  caseName: 'Luna',
                  casePhoto: state == 'assigned'
                      ? 'synthetic/case-one.png'
                      : null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pumpAndSettle();
        if (state == 'assigned') {
          expect(find.byType(RawImage), findsWidgets);
          expect(
            find.byTooltip('Foto no disponible. Reintentar foto'),
            findsNothing,
          );
        }
        final output = Directory('../../.tools/b4-visual-20261017');
        await tester.runAsync(() => output.create(recursive: true));
        final prefix = '${output.path}/$state-$scale';
        await tester.runAsync(() => saveCapture(key, '$prefix-top.png'));
        final scrollable = find.byType(Scrollable).first;
        for (var step = 0; step < 30; step++) {
          if (tester.state<ScrollableState>(scrollable).position.extentAfter <
              .5) {
            break;
          }
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(
          tester.state<ScrollableState>(scrollable).position.extentAfter,
          lessThan(.5),
        );
        await tester.runAsync(() => saveCapture(key, '$prefix-end.png'));
        expect(actions, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
