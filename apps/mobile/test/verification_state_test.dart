import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/verification_form.dart';
import 'package:dopmi_mobile/features/rescue/verification_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication, tapPublication;
import 'rescue_test.dart' show FakeRescue;

class StateVerificationRescue extends FakeRescue {
  String status = 'submitted';
  String recordOwner = 'one';
  int statusReads = 0;
  bool fail = false;

  @override
  Future<RescuerSealStatus> rescuerSealStatus() async {
    statusReads++;
    if (fail) throw const FormatException('Sin conexión de prueba');
    return RescuerSealStatus.fromJson({
      'status': status,
      'record_id': 'verification-id',
      'verification_method': 'documents',
      'missing': <String>[],
      'feedback': 'Revisa el nombre del refugio.',
    });
  }

  @override
  Future<Json> detail(String id) async {
    final data = await super.detail(id);
    return {
      ...data,
      'record': {
        ...Json.from(data['record']),
        'status': status,
        'owner_id': recordOwner,
        'files': [
          {'role': 'identity', 'path': '$recordOwner/verification-id/id.pdf'},
        ],
      },
    };
  }
}

void resumeVerification(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets('a legacy notification link opens status instead of documents', (
    tester,
  ) async {
    final repo = StateVerificationRescue()..status = 'rejected';
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/verification-id?kind=verification',
      rescue: repo,
    );
    expect(find.byType(RescuerSealScreen), findsOneWidget);
    expect(find.text('Revisa el nombre del refugio.'), findsOneWidget);
    expect(find.text('Enviar solicitud'), findsOneWidget);
    expect(find.byType(VerificationFormFrame), findsNothing);
    await tapPublication(tester, find.text('Consultar expediente'));
    expect(find.text('Expediente de verificación'), findsOneWidget);
    final name = find.byKey(const ValueKey('verification-field-legal_name'));
    expect(tester.widget<TextField>(name).enabled, isFalse);
    final archive = find.byKey(const ValueKey('verification-form-body'));
    final scrollable = find
        .descendant(of: archive, matching: find.byType(Scrollable))
        .first;
    final archivedFile = find.text('Ver archivo 1');
    await tester.scrollUntilVisible(archivedFile, 200, scrollable: scrollable);
    expect(archivedFile.hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('verification-upload-identity')),
      findsNothing,
    );
    expect(find.text('Enviar solicitud'), findsNothing);
    expect(find.text('Guardar y continuar después'), findsNothing);
    expect(repo.saveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the explicit archive route checks the owner before displaying', (
    tester,
  ) async {
    final repo = StateVerificationRescue()..recordOwner = 'another-owner';
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/verification-id?record=1&kind=verification',
      rescue: repo,
    );
    expect(find.text('Este contenido no está disponible.'), findsOneWidget);
    expect(find.byType(VerificationFormFrame), findsNothing);
    expect(repo.statusReads, 0);
  });

  testWidgets('resuming status removes stale approval and supports a retry', (
    tester,
  ) async {
    final repo = StateVerificationRescue();
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescuer/verification',
      rescue: repo,
    );
    expect(find.text('Verificación en proceso'), findsOneWidget);
    expect(repo.statusReads, 1);
    repo.status = 'approved';
    resumeVerification(tester);
    await tester.pumpAndSettle();
    expect(repo.statusReads, 2);
    expect(find.text('Cuenta verificada'), findsOneWidget);
    repo.fail = true;
    resumeVerification(tester);
    await tester.pumpAndSettle();
    expect(find.text('Cuenta verificada'), findsNothing);
    expect(find.text('Consultar expediente'), findsNothing);
    repo.fail = false;
    await tapPublication(tester, find.text('Volver a intentar'));
    expect(find.text('Cuenta verificada'), findsOneWidget);
  });
}
