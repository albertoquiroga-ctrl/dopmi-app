import 'package:dopmi_mobile/features/rescue/verification_form.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/public_expense_card.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;

import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';

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

class EmptySupportRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      const DataPage([], 0);
}

class PendingSupportRescue extends FakeRescue {
  final pending = Completer<DataPage<RescueRecord>>();
  int catalogCalls = 0;

  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) {
    catalogCalls++;
    return pending.future;
  }
}

class RetrySupportRescue extends FakeRescue {
  bool failCatalog = true;
  int catalogCalls = 0;
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    catalogCalls++;
    if (failCatalog) throw Exception('offline');
    return super.catalog(page, caseId: caseId);
  }
}

class ClosedPublicCaseRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage([
        RescueRecord({...caseRecord.data, 'status': 'closed'}),
        expenseRecord,
      ], 2);
}

class PhotoPublicCaseRescue extends FakeRescue {
  int photoRequests = 0;
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage([
        RescueRecord({
          ...caseRecord.data,
          'public_data': {
            ...caseRecord.publicData,
            'photos': ['approved/one', 'approved/two'],
          },
        }),
        expenseRecord,
      ], 2);
  @override
  Future<String> fileUrl(String path) async {
    photoRequests++;
    throw Exception('offline');
  }
}

class PendingPublicPhotoRescue extends PhotoPublicCaseRescue {
  final pending = Completer<String>();
  @override
  Future<String> fileUrl(String path) {
    photoRequests++;
    if (photoRequests == 1) return Future.error(StateError('offline'));
    return pending.future;
  }
}

class PagedPublicCaseRescue extends FakeRescue {
  final calls = <int>[];
  bool failSecond = false,
      revokeSecond = false,
      emptySecond = false,
      duplicateSecond = false;
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    calls.add(page);
    if (page == 2 && failSecond) throw StateError('network interrupted');
    if (page == 2 && revokeSecond) return const DataPage([], 0);
    if (page == 2 && emptySecond) return const DataPage([], 23);
    final records = [
      caseRecord,
      for (var i = 1; i <= 22; i++)
        RescueRecord({
          ...expenseRecord.data,
          'id': 'expense-$i',
          'public_data': {
            'title': 'Gasto $i',
            'category': 'veterinary',
            'photos': <String>[],
          },
        }),
    ];
    final items = records.skip((page - 1) * 20).take(20).toList();
    if (page == 2 && duplicateSecond) items[0] = records[19];
    return DataPage(items, records.length);
  }
}

class PlannedPublicCaseRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    final data = await super.catalog(page, caseId: caseId);
    return DataPage(
      data.items
          .map(
            (r) => r.kind != 'case'
                ? r
                : RescueRecord({
                    ...r.data,
                    'public_data': {
                      ...r.publicData,
                      'need_items': [
                        {
                          'id': 'approved-one',
                          'type': 'medicine',
                          'title': 'Tratamiento revisado',
                          'amount_cents': 12345,
                          'detail': 'Indicado para su recuperación',
                          'urgent': true,
                        },
                      ],
                    },
                  }),
          )
          .toList(),
      data.total,
    );
  }
}

void main() {
  testWidgets('case photo renews signing on resume and stops after disposal', (
    tester,
  ) async {
    final rescue = PhotoPublicCaseRescue();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rescueRepositoryProvider.overrideWithValue(rescue)],
        child: const MaterialApp(
          home: Scaffold(body: RescuePublicPhoto('approved/photo')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(rescue.photoRequests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(rescue.photoRequests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(rescue.photoRequests, 2);
    expect(find.text('Reintentar foto'), findsOneWidget);
    expect(tester.getSize(find.byType(RescuePublicPhoto)).height, 220);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(rescue.photoRequests, 2);
    expect(tester.takeException(), isNull);
  });
  test(
    'peso labels group thousands while preserving signed cent precision',
    () {
      expect(pesos(0), '\$0.00 MXN');
      expect(pesos(5), '\$0.05 MXN');
      expect(pesos(99999), '\$999.99 MXN');
      expect(pesos(145000), '\$1,450.00 MXN');
      expect(pesos(100000001), '\$1,000,000.01 MXN');
      expect(pesos(-100005), '-\$1,000.05 MXN');
    },
  );
  for (final compact in [false, true]) {
    testWidgets('photo retry shows pending request; compact=$compact', (
      tester,
    ) async {
      final rescue = PendingPublicPhotoRescue();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rescueRepositoryProvider.overrideWithValue(rescue)],
          child: MaterialApp(
            home: Scaffold(
              body: RescuePublicPhoto('approved/photo', compact: compact),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final retry = compact
          ? find.byTooltip('Foto no disponible. Reintentar foto')
          : find.text('Reintentar foto');
      await tester.tap(retry);
      await tester.pump();
      expect(rescue.photoRequests, 2);
      expect(retry, findsNothing);
      expect(tester.getSize(find.byType(RescuePublicPhoto)).height, 220);
      if (compact) {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      } else {
        expect(find.text('Cargando foto…'), findsOneWidget);
      }
      rescue.pending.completeError(StateError('offline again'));
      await tester.pumpAndSettle();
      expect(retry, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'case titles handle absent or blank names without changing authored data',
    () {
      for (final name in [null, '', '   ']) {
        final record = RescueRecord({
          'kind': 'case',
          'public_data': {'pet_name': name},
        });
        expect(record.title, 'Sin nombre');
        expect(record.publicData['pet_name'], name);
      }
      expect(
        RescueRecord({
          'kind': 'case',
          'public_data': {'pet_name': 'Mora'},
        }).title,
        'Mora',
      );
    },
  );
  testWidgets(
    'owned case thumbnail retries a failed photo without overflow at large text',
    (tester) async {
      final rescue = PhotoPublicCaseRescue();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rescueRepositoryProvider.overrideWithValue(rescue)],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: SizedBox(
                  width: 76,
                  height: 76,
                  child: RescuePublicPhoto(
                    'owned/photo',
                    height: 76,
                    radius: 14,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rescue.photoRequests, 1);
      expect(
        tester.getSize(find.byType(RescuePublicPhoto)),
        const Size(76, 76),
      );
      await tester.tap(find.byTooltip('Foto no disponible. Reintentar foto'));
      await tester.pumpAndSettle();
      expect(rescue.photoRequests, 2);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'complete public case loads all approved pages and fails as a whole',
    () async {
      final repo = PagedPublicCaseRescue();
      final all = await repo.completeCaseCatalog('case-one');
      expect(repo.calls, [1, 2]);
      expect(all.items.length, 23);
      expect(all.items.last.id, 'expense-22');
      repo.failSecond = true;
      await expectLater(repo.completeCaseCatalog('case-one'), throwsStateError);
      repo.failSecond = false;
      repo.duplicateSecond = true;
      await expectLater(repo.completeCaseCatalog('case-one'), throwsStateError);
      repo.duplicateSecond = false;
      repo.emptySecond = true;
      await expectLater(repo.completeCaseCatalog('case-one'), throwsStateError);
      repo.emptySecond = false;
      repo.revokeSecond = true;
      expect((await repo.completeCaseCatalog('case-one')).items, isEmpty);
    },
  );

  Future<void> startPublicCase(
    WidgetTester tester,
    FakeRescue repo, {
    String path = '/rescue-cases/case-one',
    bool large = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(377, 852);
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(repo),
        caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
        routerInitialLocationProvider.overrideWithValue(path),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    if (settle) await tester.pumpAndSettle();
  }

  test('money parsing preserves cent precision and rejects rounding or scientific notation', () {
    expect(parsePesos('250.50'), 25050);
    expect(parsePesos('0.01'), 1);
    expect(parsePesos('50'), 5000);
    for (final v in ['0', '-50', '1e3', '1.005', 'NaN', '1000000.01']) {
      expect(parsePesos(v), null);
    }
  });
  for (final large in [false, true]) {
    testWidgets('pending support catalog preserves home; large=$large', (
      tester,
    ) async {
      final repo = PendingSupportRescue();
      await startPublicCase(
        tester,
        repo,
        path: '/rescue-cases',
        large: large,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.catalogCalls, 1);
      expect(find.text('Descubre casos'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label ?? '').startsWith(
                'No hay casos para apoyar.',
              ),
        ),
        findsNothing,
      );
      repo.pending.complete(DataPage([repo.caseRecord], 1));
      await tester.pumpAndSettle();
      expect(find.text('Choco'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repo.catalogCalls, 1);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'support catalog failure preserves home and retries; large=$large',
      (tester) async {
        final repo = RetrySupportRescue();
        await startPublicCase(
          tester,
          repo,
          path: '/rescue-cases',
          large: large,
        );
        expect(find.text('Descubre casos'), findsOneWidget);
        expect(find.textContaining('No pudimos completar'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label ?? '').startsWith(
                  'No hay casos para apoyar.',
                ),
          ),
          findsNothing,
        );
        expect(repo.catalogCalls, 1);
        repo.failCatalog = false;
        await tester.scrollUntilVisible(
          find.text('Volver a intentar'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Volver a intentar')),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Volver a intentar'));
        await tester.pumpAndSettle();
        expect(repo.catalogCalls, 2);
        await tester.scrollUntilVisible(
          find.text('Descubre casos'),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Descubre casos'), findsOneWidget);
        expect(find.text('Choco'), findsOneWidget);
        expect(find.textContaining('No pudimos completar'), findsNothing);
        expect(find.text('Volver a intentar'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
    repo.conflict = false;
    await tester.scrollUntilVisible(
      find.text('Guardar y continuar después'),
      400,
      maxScrolls: 30,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('verification-form-body')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byType(VerificationFormFrame)),
    );
    await tester.tap(find.text('Guardar y continuar después'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/rescuer');
    router.go('/rescue/verification-id');
    await tester.pumpAndSettle();
    repo.conflict = true;
    final phone = find.byKey(const ValueKey('verification-field-phone'));
    await tester.scrollUntilVisible(
      phone,
      -400,
      maxScrolls: 30,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('verification-form-body')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(phone, '8188888888');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 50));
    final save = find.text('Guardar y continuar después');
    await tester.scrollUntilVisible(
      save,
      300,
      maxScrolls: 30,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('verification-form-body')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
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
    expect(repo.saveCalls, 2);
    expect(
      find.text('La solicitud cambió. Recarga antes de continuar'),
      findsOneWidget,
    );
    repo.conflict = false;
    await tester.scrollUntilVisible(
      find.text('Guardar y continuar después'),
      400,
      maxScrolls: 30,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('verification-form-body')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar y continuar después'));
    await tester.pumpAndSettle();
    expect(repo.saved?['phone'], '8188888888');
    expect(router.routeInformationProvider.value.uri.path, '/rescuer');
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
    final repo = PlannedPublicCaseRescue();
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
    // Source CSS h1 letter-spacing:0; paragraph inherits normal (0).
    for (final copy in [
      'Descubre casos',
      'Con cada aporte mensual ayudarás a cubrir necesidades reales de mascotas que buscan un hogar.',
    ]) {
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(copy))
            .text
            .style!
            .letterSpacing,
        0,
      );
    }

    expect(find.text('Sé un Guardián'), findsOneWidget);
    expect(find.text('Choco'), findsOneWidget);
    expect(find.text('\$25 / \$100'), findsOneWidget);
    await tester.tap(find.text('Choco'));
    await tester.pumpAndSettle();
    expect(find.text('Mi historia'), findsOneWidget);
    expect(find.text('Costos estimados'), findsOneWidget);
    expect(find.text('Tratamiento revisado'), findsOneWidget);
    expect(
      find.text(r'$123.45 • Indicado para su recuperación'),
      findsOneWidget,
    );
    expect(find.text('Eliminar'), findsNothing);
    expect(find.text('Urgente'), findsNothing);
    expect(find.text('Ayúdame a recuperar:'), findsOneWidget);
    expect(find.text('Cirugía'), findsWidgets);
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Ocultar evidencia de Cirugía',
      ),
    );
    await tester.pump();
    final expenseChevron = find.descendant(
      of: find.byType(PublicExpenseCard).first,
      matching: find.byType(RotatedBox),
    );
    expect(tester.widget<RotatedBox>(expenseChevron).quarterTurns, 1);
    expect(find.byTooltip('Aportar a Cirugía'), findsOneWidget);
    expect(find.text('No hay evidencia pública disponible.'), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Ver evidencia de Cirugía',
      ),
    );
    await tester.pump();
    expect(tester.widget<RotatedBox>(expenseChevron).quarterTurns, 3);
    expect(find.text('No hay evidencia pública disponible.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Ocultar evidencia de Cirugía' &&
            w.properties.expanded == true,
      ),
      findsOneWidget,
    );
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
    expect(find.text('\$92.00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('\$92.00')).semanticsLabel,
      '\$92.00 MXN',
    );
    expect(find.text('Transferido'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('2 sin leer'), findsOneWidget);
    expect(find.text('Actividad reciente'), findsOneWidget);
    final messages = find.byWidgetPredicate(
      (w) => w is RescuerPendingCard && w.message,
    );
    final badge = find.descendant(of: messages, matching: find.text('2'));
    expect(badge, findsOneWidget);
    await tester.ensureVisible(badge);
    await tester.pumpAndSettle();
    await tester.tap(badge);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/messages');
    expect(tester.takeException(), isNull);
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
    expect(find.text('Administrar'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('NECESITA CORRECCIONES'), findsOneWidget);
    expect(find.text('Aclara la ubicación aproximada.'), findsOneWidget);
    expect(find.text('Corregir publicación'), findsOneWidget);
  });
  for (final entry in [
    'Suscríbete ahora',
    'Apoya a casos urgentes',
    'keyboard-enter',
    'keyboard-space',
  ]) {
    testWidgets(
      'empty support $entry remains usable with large text and opens Guardian without activating it',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        SharedPreferences.setMockInitialValues({});
        final guardian = FakeGuardian();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(EmptySupportRescue()),
            guardianEnabledProvider.overrideWithValue(true),
            guardianRepositoryProvider.overrideWithValue(guardian),
            routerInitialLocationProvider.overrideWithValue('/rescue-cases'),
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
        await tester.pumpAndSettle();
        expect(find.text('No hay casos para apoyar'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label ?? '').startsWith(
                  'No hay casos para apoyar.',
                ),
          ),
          findsOneWidget,
        );
        final label = entry.startsWith('keyboard-')
            ? 'Apoya a casos urgentes'
            : entry;
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.text(label)),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(tester.getBottomRight(find.text(label)).dy, lessThan(540));
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          final card = find.byKey(
            const ValueKey('guardian-support-card-action'),
          );
          final data = tester.getSemantics(card).getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect(data.label, contains('Apoya a casos urgentes'));
          if (entry.startsWith('keyboard-')) {
            final gesture = find
                .descendant(of: card, matching: find.byType(GestureDetector))
                .first;
            Focus.of(tester.element(gesture)).requestFocus();
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(
              entry == 'keyboard-space'
                  ? LogicalKeyboardKey.space
                  : LogicalKeyboardKey.enter,
            );
          } else {
            await tester.tap(find.text(label));
          }
          await tester.pumpAndSettle();
        } finally {
          semantics.dispose();
        }
        expect(find.byType(GuardianScreen), findsOneWidget);
        expect(guardian.reads, greaterThan(0));
        expect(guardian.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'closed public case keeps history and disables every contribution entry',
    (tester) async {
      await startPublicCase(tester, ClosedPublicCaseRescue());
      final footer = find.widgetWithText(
        FilledButton,
        'Sin gastos disponibles',
      );
      expect(tester.widget<FilledButton>(footer).onPressed, isNull);
      final expense = find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Ver evidencia de Cirugía',
      );
      await tester.scrollUntilVisible(
        expense,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(expense);
      await tester.pumpAndSettle();
      final action = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Aportación no disponible',
      );
      expect(tester.widget<IconButton>(action).onPressed, isNull);
      expect(find.text('Mi historia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'public gallery dots support keyboard focus, selection and exact spacing',
    (tester) async {
      await startPublicCase(tester, PhotoPublicCaseRescue());
      final first = find.byKey(const ValueKey('public-case-photo-0'));
      final second = find.byKey(const ValueKey('public-case-photo-1'));
      expect(tester.getSize(first), const Size(11, 48));
      expect(tester.getSize(second), const Size(10, 48));
      final firstInk = tester.widget<InkWell>(first);
      expect(firstInk.onTap, isNotNull);
      final outline = find.descendant(
        of: find.ancestor(of: first, matching: find.byType(Semantics)).first,
        matching: find.byKey(const ValueKey('reference-keyboard-outline')),
      );
      for (
        var attempt = 0;
        attempt < 10 && outline.evaluate().isEmpty;
        attempt++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(outline, findsOneWidget);
      expect(tester.getSize(outline), const Size(18, 18));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final selectedSecond = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Foto 2 de 2',
      );
      expect(
        tester.widget<Semantics>(selectedSecond).properties.selected,
        true,
      );
      final gallery = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(PageView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(gallery.position.pixels, 377);
      expect(gallery.position.isScrollingNotifier.value, false);
      expect(tester.getSize(second), const Size(11, 48));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        tester.widget<Semantics>(selectedSecond).properties.selected,
        false,
      );
      await tester.tap(second);
      await tester.pump();
      expect(gallery.position.pixels, 377);
      expect(gallery.position.isScrollingNotifier.value, false);
      await tester.tap(first);
      await tester.pump();
      expect(gallery.position.pixels, 0);
      expect(gallery.position.isScrollingNotifier.value, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'case photo retry preserves hero geometry and gallery supports swipe',
    (tester) async {
      final repo = PhotoPublicCaseRescue();
      await startPublicCase(tester, repo);
      final firstPhoto = find.byType(RescuePublicPhoto).first;
      final before = tester.getSize(firstPhoto);
      final requests = repo.photoRequests;
      await tester.tap(
        find.descendant(of: firstPhoto, matching: find.text('Reintentar foto')),
      );
      await tester.pumpAndSettle();
      expect(repo.photoRequests, requests + 1);
      expect(tester.getSize(firstPhoto), before);
      await tester.drag(find.byType(PageView), const Offset(-260, 0));
      await tester.pumpAndSettle();
      final dot = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Foto 2 de 2',
      );
      expect(tester.widget<Semantics>(dot).properties.selected, isTrue);
      expect(tester.getSize(find.byType(PageView)).height, 340);
      expect(tester.takeException(), isNull);
    },
  );
  for (final large in [false, true]) {
    testWidgets(
      'public gallery thumbnail selects the hero photo; large=$large',
      (tester) async {
        await startPublicCase(tester, PhotoPublicCaseRescue(), large: large);
        final thumbnail = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Ver foto 2',
        );
        await Scrollable.ensureVisible(
          tester.element(thumbnail),
          alignment: .25,
        );
        await tester.pumpAndSettle();
        // Select the thumbnail away from its offline-photo retry control.
        await tester.tapAt(tester.getTopLeft(thumbnail) + const Offset(20, 20));
        await tester.pumpAndSettle();
        final second = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Foto 2 de 2',
        );
        expect(tester.widget<Semantics>(second).properties.selected, isTrue);
        expect(
          tester
              .widgetList<RescuePublicPhoto>(find.byType(RescuePublicPhoto))
              .map((photo) => photo.path)
              .toSet(),
          {'approved/one', 'approved/two'},
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'public case exposes expenses beyond the first page without pagination controls',
    (tester) async {
      final repo = PagedPublicCaseRescue();
      await startPublicCase(tester, repo);
      expect(repo.calls, [1, 2]);
      expect(find.text('Gasto 22'), findsOneWidget);
      await tester.ensureVisible(find.text('Gasto 22'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Aportar a Gasto 22'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Aportar a Gasto 22'));
      await tester.tap(find.byTooltip('Aportar a Gasto 22'));
      await tester.pumpAndSettle();
      expect(find.text('Elige un monto a donar:'), findsOneWidget);
      expect(find.text('\$75'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
