import 'dart:async';

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

class WaitingVerification extends FakeRescue {
  final response = Completer<RescuerSealStatus>();
  int submits = 0;

  @override
  Future<RescuerSealStatus> rescuerSealStatus() async =>
      RescuerSealStatus.fromJson({
        'status': 'not_started',
        'record_id': null,
        'verification_method': null,
        'missing': <String>[],
        'feedback': '',
      });

  @override
  Future<RescuerSealStatus> submitRescuerSeal() {
    submits++;
    return response.future;
  }
}

void main() {
  testWidgets('the seal waits for a confirmed response and only submits once', (
    tester,
  ) async {
    final repo = WaitingVerification();
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescuer/verification',
      rescue: repo,
    );
    final send = find.widgetWithText(FilledButton, 'Enviar solicitud');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
    final sending = find.widgetWithText(FilledButton, 'Enviando solicitud…');
    expect(tester.widget<FilledButton>(sending).onPressed, isNull);
    expect(find.text('Verificación en proceso'), findsNothing);
    await tester.tap(sending, warnIfMissed: false);
    await tester.pump();
    expect(repo.submits, 1);
    repo.response.complete(
      RescuerSealStatus.fromJson({
        'status': 'submitted',
        'record_id': 'verification-id',
        'verification_method': 'profile',
        'missing': <String>[],
        'feedback': '',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verificación en proceso'), findsOneWidget);
    expect(repo.saveCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
