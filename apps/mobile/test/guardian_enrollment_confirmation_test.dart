import 'package:dopmi_mobile/features/payments/guardian_enrollment_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Consent remains explicit and reachable at scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool consent = false;
      bool locked = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: GuardianEnrollmentConfirmation(
                      firstPaymentDate: '01/10/2026',
                      nextBillingDate: '01/11/2026',
                      consent: consent,
                      onConsentChanged: locked
                          ? null
                          : (value) => setState(() => consent = value ?? false),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(consent, false);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(consent, true);
      expect(tester.takeException(), isNull);
      update(() => locked = true);
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(consent, true);
    });
  }
}
