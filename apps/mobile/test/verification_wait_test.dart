import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/verification_form.dart';
import 'package:dopmi_mobile/features/rescue/verification_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

class WaitingVerification extends FakeRescue {
  final saveResponse = Completer<void>();
  final submitResponse = Completer<void>();
  RescueRecord? current;
  int submits = 0;
  @override
  Future<Json> detail(String id) async {
    final data = await super.detail(id);
    return {
      ...data,
      'record':
          current?.data ?? {...Json.from(data['record']), 'status': 'draft'},
    };
  }

  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    saveCalls++;
    saved = Json.from(privateData);
    await saveResponse.future;
    return current = RescueRecord({
      ...record!.data,
      'public_data': publicData,
      'private_data': privateData,
      'files': files,
      'version': 5,
      'status': 'draft',
    });
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    if (action != 'submit') throw StateError('Unexpected transition');
    submits++;
    await submitResponse.future;
    return current = RescueRecord({
      ...record.data,
      'status': 'submitted',
      'version': 6,
    });
  }
}

Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    maxScrolls: 30,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('verification-form-body')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final action in ['save', 'submit', 'failed-save']) {
      testWidgets('verification waits for real response: $action/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = WaitingVerification();
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/verification-id',
          rescue: repo,
        );
        final router = GoRouter.of(
          tester.element(find.byType(VerificationFormFrame)),
        );
        final phone = find.byKey(const ValueKey('verification-field-phone'));
        await reveal(tester, phone);
        await tester.enterText(phone, '8188888888');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final button = find.byKey(
          ValueKey(
            action == 'submit'
                ? 'verification-submit'
                : 'verification-save-later',
          ),
        );
        await reveal(tester, button);
        final submit = find.byKey(const ValueKey('verification-submit'));
        final beforeHeight = tester.getSize(submit).height;
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getSize(submit).height, beforeHeight);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/rescue/verification-id',
        );
        expect(repo.saveCalls, 1);
        expect(repo.submits, 0);
        expect(find.byType(VerificationStateScreen), findsNothing);
        for (final key in ['verification-submit', 'verification-save-later']) {
          final target = find.byKey(ValueKey(key));
          expect(tester.widget<ButtonStyleButton>(target).onPressed, isNull);
        }
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 200));
        expect(repo.saveCalls, 1);
        expect(repo.saved?['phone'], '8188888888');
        if (action == 'failed-save') {
          repo.saveResponse.completeError(
            const FormatException('No se pudo guardar de prueba.'),
          );
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            '/rescue/verification-id',
          );
          expect(find.text('No se pudo guardar de prueba.'), findsOneWidget);
          await reveal(tester, phone, delta: -250);
          expect(
            tester.widget<TextField>(phone).controller!.text,
            '8188888888',
          );
        } else {
          repo.saveResponse.complete();
          await tester.pump();
          if (action == 'submit') {
            await tester.pump(const Duration(milliseconds: 200));
            expect(repo.submits, 1);
            expect(find.byType(VerificationStateScreen), findsNothing);
            expect(
              router.routeInformationProvider.value.uri.path,
              '/rescue/verification-id',
            );
            repo.submitResponse.complete();
            await tester.pumpAndSettle();
            expect(find.byType(VerificationStateScreen), findsOneWidget);
            expect(repo.current!.status, 'submitted');
          } else {
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, '/rescuer');
            expect(repo.current!.privateData['phone'], '8188888888');
          }
        }
        expect(repo.saveCalls, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
