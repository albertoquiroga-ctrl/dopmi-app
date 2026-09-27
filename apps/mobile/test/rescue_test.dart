import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
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
  final caseRecord = RescueRecord({
    'id': 'case-one',
    'owner_id': 'rescuer-one',
    'kind': 'case',
    'status': 'approved',
    'version': 3,
    'saved': false,
    'target_cents': 10000,
    'funded_cents': 2500,
    'transferred_cents': 0,
    'rescuer_name': 'Refugio Luna',
    'public_data': {
      'pet_name': 'Choco',
      'story': 'Choco necesita recuperarse antes de buscar hogar.',
      'city': 'Monterrey',
      'state': 'Nuevo León',
      'photos': <String>[],
    },
  });
  final expenseRecord = RescueRecord({
    'id': 'expense-one',
    'owner_id': 'rescuer-one',
    'parent_id': 'case-one',
    'kind': 'expense',
    'status': 'approved',
    'version': 2,
    'target_cents': 10000,
    'funded_cents': 2500,
    'transferred_cents': 0,
    'reimbursable_cents': 10000,
    'urgent': true,
    'public_data': {'title': 'Cirugía', 'photos': <String>[]},
  });
  @override
  Future<Json> dashboard() async => {
    'verification_status': 'approved',
    'case_counts': {'active': 1, 'draft': 1, 'review': 0, 'corrections': 0},
    'unread_messages': 2,
    'financial': {
      'assigned_cents': 9200,
      'transferred_cents': 5000,
      'in_review_cents': 4200,
    },
    'pending': [
      {
        'id': 'case-draft',
        'kind': 'case',
        'status': 'draft',
        'title': 'Nina',
        'feedback': '',
      },
    ],
    'recent_activity': [
      {
        'expense_id': 'expense-one',
        'expense_title': 'Cirugía',
        'allocated_cents': 2500,
        'transfer_status': 'pending',
      },
    ],
  };
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage(
        caseId == null ? [caseRecord] : [caseRecord, expenseRecord],
        caseId == null ? 1 : 2,
      );
  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async {
    if (kind != 'case') return const DataPage([], 0);
    return DataPage([
      caseRecord,
      RescueRecord({
        'id': 'case-correction',
        'owner_id': 'rescuer-one',
        'kind': 'case',
        'status': 'changes_requested',
        'version': 2,
        'feedback': 'Aclara la ubicación aproximada.',
        'public_data': {'pet_name': 'Nina'},
      }),
    ], 2);
  }

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
      'private_data': {'legal_name': 'Ana López', 'identity_type': 'ine'},
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

class FakeCaseUpdates extends CaseUpdateRepository {
  FakeCaseUpdates()
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  Future<List<CaseUpdate>> publicFor(String caseId) async => [];
}

void main() {
  test('money parsing preserves cent precision and rejects rounding or scientific notation', () {
    expect(parsePesos('250.50'), 25050);
    expect(parsePesos('0.01'), 1);
    expect(parsePesos('50'), 5000);
    for (final v in ['0', '-50', '1e3', '1.005', 'NaN', '1000000.01']) {
      expect(parsePesos(v), null);
    }
  });
  testWidgets('rescuer draft keeps private fields after a save conflict', (
    tester,
  ) async {
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
        caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
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
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
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
  });

  testWidgets('support home and case detail use real progress and expenses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
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
        caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
        routerInitialLocationProvider.overrideWithValue('/rescue-cases'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Descubre casos'), findsOneWidget);
    expect(find.text('Sé un Guardián'), findsOneWidget);
    expect(find.text('Choco'), findsOneWidget);
    expect(find.text('\$25 / \$100'), findsOneWidget);
    await tester.tap(find.text('Choco'));
    await tester.pumpAndSettle();
    expect(find.text('Mi historia'), findsOneWidget);
    expect(find.text('Ayúdame a recuperar'), findsOneWidget);
    expect(find.text('Cirugía'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Cirugía'));
    await tester.pumpAndSettle();
    expect(find.text('Aportar a este gasto'), findsOneWidget);
  });

  testWidgets('rescuer home labels real financial and pending states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue('/rescuer'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resumen comprobado'), findsOneWidget);
    expect(find.text('\$92.00 MXN'), findsOneWidget);
    expect(find.text('Transferido'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('2 sin leer'), findsOneWidget);
    expect(find.text('Actividad reciente'), findsOneWidget);
  });

  testWidgets('my cases exposes status-specific actions and feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue('/my-cases'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choco'), findsOneWidget);
    expect(find.text('Administrar caso'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('Necesita correcciones'), findsOneWidget);
    expect(find.text('Aclara la ubicación aproximada.'), findsOneWidget);
    expect(find.text('Corregir publicación'), findsOneWidget);
  });
}
