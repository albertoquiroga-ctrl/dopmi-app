import 'dart:io';

import 'package:flutter/services.dart';
import 'package:dopmi_mobile/core/ui.dart';

import 'capture_design_test.dart' show saveCapture;

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

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';
import '../test/rescuer_profile_test.dart' show FakeRescuerProfile;

class FeedbackPhone extends PhoneVerificationRepository {
  @override
  String? verifiedPhone;
  Completer<void>? pending;
  bool fail = false;
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
    throw StateError('offline');
  }
}

final captureKey = GlobalKey();
late ScrollableState editorScroll;
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
      child: RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dopmiTheme(rescuer: true),
          home: const RescuerPublicProfileEditScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final candidates = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  editorScroll = tester.state<ScrollableState>(candidates.first);
  expect(editorScroll.mounted, isTrue);
  final number = find.byKey(const ValueKey('profile-sms-phone'));
  await reveal(tester, number);
}

// Capture ScrollableState once after mount. Search by offsets, not drag Finder.
Future<void> reveal(WidgetTester tester, Finder target) async {
  expect(editorScroll.mounted, isTrue);
  final position = editorScroll.position;
  if (target.evaluate().isEmpty) {
    // A previous ensureVisible may have moved the lazy target above us.
    position.jumpTo(position.minScrollExtent);
    await tester.pump(const Duration(milliseconds: 250));
    for (var step = 0; step < 80 && target.evaluate().isEmpty; step++) {
      final next = (position.pixels + 120)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (next <= position.pixels) break;
      position.jumpTo(next);
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  smsDiagnostic(tester, "after bounded search");
  expect(
    target,
    findsOneWidget,
    reason:
        'Target not constructed after bounded search from start; offset=${position.pixels}, max=${position.maxScrollExtent}',
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 250));
}

void smsDiagnostic(WidgetTester tester, String phase) {
  const allowed = [
    'Vincular',
    'Cambiar número',
    'Confirmar código',
    'Reenviar código',
  ];
  final labels = allowed
      .where((label) => find.text(label).evaluate().isNotEmpty)
      .toList();
  final hitLabels = allowed
      .where((label) => find.text(label).hitTestable().evaluate().isNotEmpty)
      .toList();
  debugPrint(
    'SMS harness $phase offset=${editorScroll.position.pixels} max=${editorScroll.position.maxScrollExtent} builtLabels=$labels hitLabels=$hitLabels',
  );
}

Future<void> press(WidgetTester tester, String label) async {
  smsDiagnostic(tester, "before $label");
  final button = find.text(label);
  await reveal(tester, button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  for (final spec in [
    ('normal', const Size(377, 852), 1.0),
    ('samsung', const Size(377, 852), 1.15),
    ('large', const Size(320, 640), 2.0),
  ]) {
    testWidgets('b5-sms-${spec.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = spec.$2;
      tester.platformDispatcher.textScaleFactorTestValue = spec.$3;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
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
      final output = Directory('../../.tools/b5-sms-visual-20261017');
      await tester.runAsync(() => output.create(recursive: true));
      final phone = FeedbackPhone();
      await prepare(tester, phone);
      Future<void> capture(String state, Finder anchor) async {
        final destination = find.text(
          'Código para el número terminado en 5678',
        );
        final start = {'initial', 'restored', 'read-failed'}.contains(state)
            ? find.byKey(const ValueKey('profile-sms-phone'))
            : destination;
        await reveal(tester, start);
        await Scrollable.ensureVisible(tester.element(start), alignment: 0.05);
        await tester.pump(const Duration(milliseconds: 250));
        final appbarBottom = tester.getRect(find.byType(AppBar)).bottom;
        final viewportBottom = spec.$2.height - tester.view.viewInsets.bottom;
        Future<void> save(String frame) async {
          expect(tester.takeException(), isNull);
          await tester.runAsync(
            () => saveCapture(
              captureKey,
              '${output.path}/b5-sms-${spec.$1}-$state-$frame.png',
            ),
          );
        }

        expect(tester.getRect(start).top, greaterThanOrEqualTo(appbarBottom));
        expect(start.hitTestable(), findsOneWidget);
        await save('01-context');
        if (!{'initial', 'restored', 'read-failed'}.contains(state) &&
            (spec.$3 == 2.0 || state == 'keyboard-scroll')) {
          final actions = find.text('Reenviar código');
          await reveal(tester, actions);
          expect(actions.hitTestable(), findsOneWidget);
          await save('02-actions');
        }
        // Keep text scale and real layout. If feedback cannot share the frame,
        // save a second sequential viewport with the actions as overlap.
        if (anchor.evaluate().isEmpty ||
            tester.getRect(anchor).bottom > viewportBottom ||
            tester.getRect(anchor).top < appbarBottom) {
          await reveal(tester, anchor);
          await Scrollable.ensureVisible(
            tester.element(anchor),
            alignment: 0.85,
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(anchor.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(anchor).top,
            greaterThanOrEqualTo(appbarBottom),
          );
          expect(
            tester.getRect(anchor).bottom,
            lessThanOrEqualTo(viewportBottom),
          );
          await save('03-feedback');
        }
      }

      final number = find.byKey(const ValueKey('profile-sms-phone'));
      await capture('initial', number);
      phone.readStatus.value = PhoneVerificationReadStatus.loading;
      phone.verifiedPhone = '+525512345678'; // Synthetic Auth read only.
      phone.readStatus.value = PhoneVerificationReadStatus.ready;
      await tester.pumpAndSettle();
      await capture('restored', find.text('Vinculado: +525512345678'));
      phone.readStatus.value = PhoneVerificationReadStatus.failed;
      await tester.pumpAndSettle();
      await capture('read-failed', find.text('Reintentar consulta'));
      expect(find.text('Vinculado: +525512345678'), findsOneWidget);
      phone.verifiedPhone = null;
      phone.readStatus.value = PhoneVerificationReadStatus.ready;
      await tester.pumpAndSettle();
      await tester.enterText(number, '+525512345678'); // Synthetic, fake only.
      expect(
        phone.verifiedPhone,
        isNull,
        reason: 'Fake must preserve unlinked SMS account',
      );
      smsDiagnostic(tester, 'after enterText');
      await press(tester, 'Vincular');
      await tester.pumpAndSettle();
      await capture(
        'request-success',
        find.text('Solicitud enviada. El SMS puede tardar en llegar.'),
      );
      final code = find.byKey(const ValueKey('profile-sms-code'));
      await reveal(tester, code);
      await tester.enterText(
        code,
        '000000',
      ); // Synthetic OTP, never submitted to network.
      await press(tester, 'Reenviar código');
      await tester.pumpAndSettle();
      await capture(
        'resend-success',
        find.text(
          'Solicitud de reenvío enviada. El SMS puede tardar en llegar.',
        ),
      );
      phone.fail = true;
      await press(tester, 'Reenviar código');
      await tester.pumpAndSettle();
      await capture(
        'error',
        find.text('No pudimos verificar el teléfono. Vuelve a intentar.'),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 300));
      await reveal(tester, code);
      expect(code.hitTestable(), findsOneWidget);
      await tester.tap(code);
      await tester.pump(const Duration(milliseconds: 300));
      await reveal(tester, code);
      expect(code.hitTestable(), findsOneWidget);
      await capture(
        'keyboard-scroll',
        find.text('No pudimos verificar el teléfono. Vuelve a intentar.'),
      );
      tester.view.resetViewInsets();
      await tester.pump(const Duration(milliseconds: 300));
      phone.fail = false;
      phone.pending = Completer<void>();
      await press(tester, 'Reenviar código');
      await capture('busy-resend', find.byType(LinearProgressIndicator));
      phone.pending!.complete();
      await tester.pumpAndSettle();
      phone.pending = Completer<void>();
      await press(tester, 'Confirmar código');
      await capture('busy-verify', find.byType(LinearProgressIndicator));
      phone.pending!.complete();
      await tester.pumpAndSettle();
    });
  }
}
