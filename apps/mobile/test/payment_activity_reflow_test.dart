import 'package:dopmi_mobile/features/payments/payment_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final received in [false, true]) {
    for (final scale in [1.15, 2.0]) {
      testWidgets('payment header reflows at $scale received=$received', (
        tester,
      ) async {
        final font = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
        await font.load();
        tester.view.physicalSize = Size(scale == 2 ? 320 : 377, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const title = 'Consulta veterinaria de Luna';
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: PaymentActivityCard(
                      owner: 'synthetic-owner',
                      received: received,
                      item: const {
                        'id': 'synthetic-payment',
                        'kind': 'contribution',
                        'title': title,
                        'created_at': '2026-10-08T12:00:00Z',
                        'amount_cents': 5075,
                        'status': 'assigned',
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final titleFinder = find.text(title);
        final date = find.text('8/10/2026');
        final status = find.text('Neto asignado');
        final amount = find.byType(ActivityMoney);
        final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
        final word = TextPainter(
          text: const TextSpan(
            text: 'veterinaria',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout();
        expect(paragraph.size.width, greaterThanOrEqualTo(word.width));
        word.dispose();
        final dateBox = tester.getSize(date);
        expect(dateBox.height, lessThanOrEqualTo(12 * scale * 1.5 + 1));
        expect(tester.widget<ActivityMoney>(amount).cents, 5075);
        expect(find.text('.75'), findsOneWidget);
        if (scale == 2) {
          expect(
            tester.getTopLeft(amount).dy,
            greaterThan(tester.getBottomLeft(status).dy),
          );
        } else {
          expect(
            tester.getTopLeft(amount).dx,
            greaterThan(tester.getTopLeft(titleFinder).dx),
          );
          expect(
            tester.getTopLeft(amount).dy,
            lessThan(tester.getBottomLeft(status).dy),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
