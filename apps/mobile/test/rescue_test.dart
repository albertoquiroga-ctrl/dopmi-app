import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class FakeRescue extends RescueRepository {
  FakeRescue()
      : super(
          SupabaseClient(
            'http://127.0.0.1:54321',
            'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );
  Json? saved;
  bool conflict = true;
  int saveCalls = 0;
  @override
  Future<Json> detail(String id) async => {
        'record': {
          'id': id,
          'kind': 'verification',
          'status': 'draft',
          'version': 4,
          'public_data': {
            'public_name': 'Refugio Luna',
            'bio': 'Rescatamos animales',
            'city': 'Monterrey',
            'state': 'Nuevo León',
          },
          'private_data': {
            'legal_name': 'Ana López',
            'identity_type': 'ine',
          },
          'files': <Json>[],
          'feedback': 'Completa el teléfono',
        },
        'history': <Json>[],
      };
  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    saveCalls += 1;
    saved = privateData;
    if (conflict) {
      throw const PostgrestException(
        message: 'La solicitud cambió. Recarga antes de continuar',
        code: '40001',
      );
    }
    return RescueRecord({
      ...record!.data,
      'private_data': privateData,
      'public_data': publicData,
      'files': files,
      'version': 5,
      'status': 'draft',
    });
  }
}

void main() {
  test(
    'money parsing preserves cent precision and rejects rounding or scientific notation',
    () {
      expect(parsePesos('250.50'), 25050);
      expect(parsePesos('0.01'), 1);
      expect(parsePesos('50'), 5000);
      for (final v in ['0', '-50', '1e3', '1.005', 'NaN', '1000000.01']) {
        expect(parsePesos(v), null);
      }
    },
  );
  testWidgets(
    'rescuer draft keeps private fields after a save conflict',
    (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true);
      final repo = FakeRescue();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(repo),
          routerInitialLocationProvider.overrideWithValue(
            '/rescue/verification-id',
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Borrador · Versión 4').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('Borrador · Versión 4'), findsOneWidget);
      final phone = find.widgetWithText(TextField, 'Teléfono');
      await tester.enterText(phone, '8188888888');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 50));
      final save = find.text('Guardar borrador');
      for (var i = 0; i < 12; i++) {
        if (save.evaluate().isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        save,
        findsOneWidget,
        reason: 'Debe mostrar el botón de guardar en edición',
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(save);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find
            .text('La solicitud cambió. Recarga antes de continuar')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(repo.saved?['phone'], '8188888888');
      expect(repo.saveCalls, 1);
      expect(
        find.text('La solicitud cambió. Recarga antes de continuar'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
    },
  );
}
