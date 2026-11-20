import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:dopmi_mobile/features/rescue/verification_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication, tapPublication;
import 'rescue_test.dart' show FakeRescue;

class _SealRescue extends FakeRescue {
  String status = 'not_started';
  List<String> missing = [];
  bool statusUnavailable = false;
  bool failSubmit = false;
  bool commitBeforeFailure = false;
  int submitCalls = 0;

  RescuerSealStatus get state => RescuerSealStatus.fromJson({
    'status': status,
    'record_id': status == 'not_started' ? null : 'request-one',
    'verification_method': status == 'not_started' ? null : 'profile',
    'missing': missing,
    'feedback': '',
  });

  @override
  Future<RescuerSealStatus> rescuerSealStatus() async {
    if (statusUnavailable) throw StateError('RPC unavailable');
    return state;
  }

  @override
  Future<RescuerSealStatus> submitRescuerSeal() async {
    submitCalls++;
    if (!failSubmit || commitBeforeFailure) status = 'submitted';
    if (failSubmit) throw StateError('Timed out');
    return state;
  }

  @override
  Future<Json> detail(String id) async {
    if (id != 'request-one') return super.detail(id);
    return {
      'record': {
        'id': id,
        'owner_id': 'one',
        'kind': 'verification',
        'status': 'submitted',
        'private_data': {'verification_method': 'profile'},
      },
      'history': <Json>[],
    };
  }
}

Future<GoRouter> _start(WidgetTester tester, _SealRescue rescue) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await startPublication(tester, FakeCommunity(), '/publish', rescue: rescue);
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

void main() {
  testWidgets('old start link shows only server profile gaps at 200%', (
    tester,
  ) async {
    final repo = _SealRescue()..missing = ['photo', 'phone'];
    final router = await _start(tester, repo);
    final origin = router.routeInformationProvider.value.uri.path;
    router.push<void>('/rescue/new?kind=verification').ignore();
    await tester.pumpAndSettle();
    expect(find.byType(RescuerSealScreen), findsOneWidget);
    expect(find.text('Foto de perfil'), findsOneWidget);
    expect(find.text('Teléfono'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsNothing);
    expect(find.text('Enviar solicitud'), findsNothing);
    expect(find.textContaining('INE'), findsNothing);
    expect(find.byType(RescueEditorScreen), findsNothing);
    expect(find.text('Completar mi información'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, origin);
    expect(repo.submitCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed status read can be retried, then sends only one request',
    (tester) async {
      final repo = _SealRescue()..statusUnavailable = true;
      final router = await _start(tester, repo);
      router.push<void>('/rescuer/verification').ignore();
      await tester.pumpAndSettle();
      expect(find.text('Enviar solicitud'), findsNothing);
      expect(find.byType(RescueEditorScreen), findsNothing);
      repo.statusUnavailable = false;
      await tapPublication(tester, find.text('Volver a intentar'));
      await tapPublication(tester, find.text('Enviar solicitud'));
      expect(repo.submitCalls, 1);
      expect(repo.status, 'submitted');
      router.push<void>('/rescuer/verification').ignore();
      await tester.pumpAndSettle();
      expect(find.text('Verificación en proceso'), findsOneWidget);
      expect(find.text('Enviar solicitud'), findsNothing);
    },
  );

  testWidgets(
    'uncertain response reconciles an accepted request without resend',
    (tester) async {
      final repo = _SealRescue()
        ..failSubmit = true
        ..commitBeforeFailure = true;
      final router = await _start(tester, repo);
      router.push<void>('/rescuer/verification').ignore();
      await tester.pumpAndSettle();
      await tapPublication(tester, find.text('Enviar solicitud'));
      expect(repo.submitCalls, 1);
      expect(repo.status, 'submitted');
      router.push<void>('/rescue/request-one?kind=verification').ignore();
      await tester.pumpAndSettle();
      expect(find.text('Verificación en proceso'), findsOneWidget);
      expect(find.text('Consultar expediente'), findsNothing);
      expect(find.textContaining('Identificación oficial'), findsNothing);
    },
  );
}
