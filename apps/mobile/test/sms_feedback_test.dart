import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescuer_profile_test.dart' show FakeRescuerProfile;

class FeedbackPhone extends PhoneVerificationRepository {
  int epoch = 0;
  @override
  int get sessionEpoch => epoch;
  @override
  String? verifiedPhone;
  Completer<void>? pending;
  bool fail = false, confirms = false, intermediate = false;
  int resends = 0;
  @override
  Future<void> requestPhoneCode(String phone) async {}
  @override
  Future<void> resendPhoneCode(String phone) async {
    resends++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> verifyPhoneCode(String phone, String code) async {
    if (pending != null) await pending!.future;
    if (confirms) {
      verifiedPhone = phone;
      return;
    }
    if (intermediate) return;
    throw StateError('offline');
  }
}

Future<void> prepare(WidgetTester tester, FeedbackPhone phone) async {
  final identity = FakeIdentityRepository()
    ..user = const Identity('owner-one', 'fake@example.test', verified: true);
  addTearDown(() => identity.changes.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        rescuerProfileRepositoryProvider.overrideWithValue(
          FakeRescuerProfile(),
        ),
        phoneVerificationRepositoryProvider.overrideWithValue(phone),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
      ],
      child: const MaterialApp(home: RescuerPublicProfileEditScreen()),
    ),
  );
  await tester.pumpAndSettle();
  final number = find.byKey(const ValueKey('profile-sms-phone'));
  await tester.ensureVisible(number);
  await tester.enterText(number, '+525512345678');
  await press(tester, 'Vincular');
}

Future<void> press(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

class ReadingPhone extends FeedbackPhone {
  final authoritative = Completer<String?>();
  int reads = 0, sends = 0;
  bool failRead = false;
  @override
  Future<void> refreshVerifiedPhone() async {
    reads++;
    readStatus.value = PhoneVerificationReadStatus.loading;
    if (failRead) {
      readStatus.value = PhoneVerificationReadStatus.failed;
      return;
    }
    verifiedPhone = await authoritative.future;
    readStatus.value = PhoneVerificationReadStatus.ready;
  }

  @override
  Future<void> requestPhoneCode(String phone) async {
    sends++;
  }
}

void main() {
  testWidgets(
    'confirmed same phone closes OTP controls and intermediate confirmation preserves them',
    (tester) async {
      final phone = FeedbackPhone();
      addTearDown(phone.dispose);
      await prepare(tester, phone);
      await tester.pumpAndSettle();
      final code = find.byKey(const ValueKey('profile-sms-code'));
      await tester.ensureVisible(code);
      await tester.enterText(code, '123456');
      // A failed confirmation preserves recovery of the same request.
      await press(tester, 'Confirmar código');
      await tester.pumpAndSettle();
      expect(code, findsOneWidget);
      expect(find.text('Reenviar código'), findsOneWidget);
      phone.intermediate = true;
      await press(tester, 'Confirmar código');
      await tester.pumpAndSettle();
      expect(code, findsOneWidget);
      expect(find.text('Reenviar código'), findsOneWidget);
      phone.confirms = true;
      await press(tester, 'Confirmar código');
      await tester.pumpAndSettle();
      expect(find.text('Vinculado: +525512345678'), findsOneWidget);
      expect(find.text('Cambiar número'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-sms-code')), findsNothing);
      expect(find.text('Confirmar código'), findsNothing);
      expect(find.text('Reenviar código'), findsNothing);
      expect(
        find.textContaining('Código para el número terminado'),
        findsNothing,
      );
      expect(phone.resends, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session invalidation clears local phone workflow and discards late resend feedback',
    (tester) async {
      final phone = FeedbackPhone();
      addTearDown(phone.dispose);
      await prepare(tester, phone);
      await tester.pumpAndSettle();
      phone.pending = Completer<void>();
      await press(tester, 'Reenviar código');
      phone.epoch++;
      phone.readStatus.value = PhoneVerificationReadStatus.idle;
      await tester.pumpAndSettle();
      phone.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-sms-code')), findsNothing);
      expect(find.textContaining('Solicitud de reenvío enviada'), findsNothing);
      expect(find.textContaining('terminado en 5678'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open editor observes authoritative completion, read failure retries without sending SMS',
    (tester) async {
      final phone = ReadingPhone();
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'owner-one',
          'fake@example.test',
          verified: true,
        );
      addTearDown(identity.changes.close);
      addTearDown(phone.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            rescuerProfileRepositoryProvider.overrideWithValue(
              FakeRescuerProfile(),
            ),
            phoneVerificationRepositoryProvider.overrideWithValue(phone),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const MaterialApp(home: RescuerPublicProfileEditScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('profile-sms-phone'));
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Consultando el teléfono de tu cuenta…'),
        findsOneWidget,
      );
      phone.authoritative.complete('+525512345678');
      await tester.pumpAndSettle();
      expect(find.text('Vinculado: +525512345678'), findsOneWidget);
      phone.failRead = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('no necesitas solicitar otro SMS'),
        findsOneWidget,
      );
      expect(find.text('Vinculado: +525512345678'), findsOneWidget);
      phone.failRead = false;
      await press(tester, 'Reintentar consulta');
      await tester.pumpAndSettle();
      expect(phone.reads, greaterThanOrEqualTo(3));
      expect(phone.sends, 0);
      expect(find.text('Reintentar consulta'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resend reports success with nonempty code, masks destination and clears stale success on error',
    (tester) async {
      final phone = FeedbackPhone();
      await prepare(tester, phone);
      await tester.pumpAndSettle();
      expect(
        find.text('Solicitud enviada. El SMS puede tardar en llegar.'),
        findsOneWidget,
      );
      expect(
        find.text('Código para el número terminado en 5678'),
        findsOneWidget,
      );
      expect(find.text('Enviamos el código a +525512345678'), findsNothing);
      final code = find.byKey(const ValueKey('profile-sms-code'));
      await tester.ensureVisible(code);
      await tester.enterText(code, '000000');
      await press(tester, 'Reenviar código');
      await tester.pumpAndSettle();
      expect(phone.resends, 1);
      expect(
        find.text(
          'Solicitud de reenvío enviada. El SMS puede tardar en llegar.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(code).controller!.text, '000000');
      phone.fail = true;
      await press(tester, 'Reenviar código');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Solicitud de reenvío enviada. El SMS puede tardar en llegar.',
        ),
        findsNothing,
      );
      expect(
        find.text('No pudimos verificar el teléfono. Vuelve a intentar.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'busy prevents duplicate resend and verify uses shared indicator without relabeling resend',
    (tester) async {
      final phone = FeedbackPhone();
      await prepare(tester, phone);
      await tester.pumpAndSettle();
      phone.pending = Completer<void>();
      await press(tester, 'Reenviar código');
      final resend = find.widgetWithText(TextButton, 'Reenviar código');
      expect(tester.widget<TextButton>(resend).onPressed, isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(resend);
      await tester.pump();
      expect(phone.resends, 1);
      phone.pending!.complete();
      await tester.pumpAndSettle();
      phone.pending = Completer<void>();
      await press(tester, 'Confirmar código');
      expect(find.text('Reenviar código'), findsOneWidget);
      expect(find.text('Procesando…'), findsNothing);
      expect(tester.widget<TextButton>(resend).onPressed, isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      phone.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    },
  );
}
