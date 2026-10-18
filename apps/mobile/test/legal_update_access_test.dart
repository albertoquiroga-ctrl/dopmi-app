import 'dart:async';

import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/features/identity/privacy_notice_screen.dart';
import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:dopmi_mobile/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';

class UpdatingIdentity extends FakeIdentityRepository {
  final gate = Completer<void>();
  @override
  Future<void> acceptTerms() async {
    consentCount++;
    await gate.future;
  }
}

void main() {
  testWidgets(
    'legal update starts unchecked; retained access does not accept; double submit is guarded',
    (tester) async {
      final identity = UpdatingIdentity()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      addTearDown(identity.changes.close);
      var privacy = 0, payments = 0, received = 0, guardian = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [identityRepositoryProvider.overrideWithValue(identity)],
          child: MaterialApp(
            home: ConsentScreen(
              onPrivacy: () => privacy++,
              onPayments: () => payments++,
              onReceivedPayments: () => received++,
              onGuardian: () => guardian++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Actualización del 17 de octubre de 2026'),
        findsOneWidget,
      );
      expect(find.textContaining('no realiza ningún cobro'), findsOneWidget);
      expect(
        tester.widget<AuthConsentRow>(find.byType(AuthConsentRow)).value,
        isFalse,
      );
      for (final label in [
        'Privacidad y eliminación de cuenta',
        'Ver mis comprobantes',
        'Aportaciones recibidas',
        'Cancelar o consultar Guardián',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
      }
      expect([privacy, payments, received, guardian], [1, 1, 1, 1]);
      expect(identity.consentCount, 0);
      final row = tester.widget<AuthConsentRow>(find.byType(AuthConsentRow));
      row.onChanged!(true);
      await tester.pump();
      final action = find.text('Aceptar actualización y continuar');
      await tester.ensureVisible(action);
      final position = tester.getCenter(action);
      await tester.tapAt(position);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      // A second physical tap at the same button position while its label is
      // replaced by a progress indicator must not send another acceptance.
      await tester.tapAt(position);
      await tester.pump();
      expect(identity.consentCount, 1);
      identity.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing owner clears an unchecked or checked decision', (
    tester,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    addTearDown(identity.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityRepositoryProvider.overrideWithValue(identity)],
        child: const MaterialApp(home: ConsentScreen()),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<AuthConsentRow>(find.byType(AuthConsentRow)).onChanged!(true);
    await tester.pump();
    identity.profile = const Profile(
      id: 'two',
      name: 'Otro',
      phone: '',
      city: '',
      mode: 'donor',
      intent: 'adopt',
      status: 'active',
      termsVersion: null,
    );
    identity.emit(
      const IdentityEvent(
        Identity('two', 'second@example.test', verified: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AuthConsentRow>(find.byType(AuthConsentRow)).value,
      isFalse,
    );
    expect(identity.consentCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final document in [const TermsScreen(), const PrivacyNoticeScreen()]) {
    testWidgets(
      'native legal document exposes its exact October version: ${document.runtimeType}',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: document));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            document is TermsScreen ? 'terms-2026-10-17' : 'privacy-2026-10-17',
          ),
          findsWidgets,
        );
        expect(find.textContaining('28 de septiembre'), findsNothing);
        expect(
          find.textContaining('extractos del aviso publicado'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
