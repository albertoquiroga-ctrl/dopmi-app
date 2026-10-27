import 'dart:ui' show SemanticsAction;

import 'package:dopmi_mobile/features/rescue/verification_form.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/navigation.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:dopmi_mobile/features/rescue/rescuer_funnel.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/public_expense_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'guardian_test.dart' show FakeGuardian;

import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_screen.dart';
import 'package:dopmi_mobile/features/payments/payment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';

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
  @override
  Future<RescuerFunnelMetrics> funnel(String period) async {
    final data = await dashboardV2();
    final counts = Json.from(data['support_counts'] as Map);
    final financial = Json.from(data['financial'] as Map);
    final at = DateTime.utc(2026, 10, 6, 12);
    return RescuerFunnelMetrics(
      period: period,
      periodStart: DateTime.utc(2026, 10),
      periodEnd: at,
      asOf: at,
      viewTrackingStartedAt: DateTime.utc(2026, 10),
      views: 0,
      favorites: 0,
      messages: 0,
      adoptions: 0,
      donors: 0,
      activeCases: (counts['active'] as num?)?.toInt() ?? 0,
      completedCases: 0,
      raisedCents: (financial['assigned_cents'] as num?)?.toInt() ?? 0,
    );
  }

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
  Future<Json> dashboardV2() async {
    final legacy = await dashboard();
    return {
      ...legacy,
      'adoption_counts': {
        'active': 0,
        'draft': 0,
        'review': 0,
        'corrections': 0,
      },
      'support_counts': legacy['case_counts'],
      'adoption_metrics': {'unique_viewers': 0, 'pets_saved': 0},
      'unanswered_conversations': 2,
      'pending_evidence': <Json>[],
      'payments_unseen_count': 1,
      'recent_activity': ((legacy['recent_activity'] as List?) ?? [])
          .map(
            (value) => <String, dynamic>{
              ...Json.from(value as Map),
              'id': 'individual:fixture',
              'case_id': 'case-one',
              'pet_name': 'Choco',
              'net_cents': value['allocated_cents'],
              'occurred_at': '2026-10-05T12:00:00Z',
              'source': value['source'] ?? 'individual',
            },
          )
          .toList(),
    };
  }

  @override
  Future<Json> ownedCases(
    int page, {
    String program = 'adoption',
    List<String> statuses = const [],
    bool archived = false,
  }) async {
    final records = program == 'support'
        ? (await mine('case', 1)).items
        : <RescueRecord>[];
    final filtered = records.where((record) {
      final category = switch (record.status) {
        'approved' => 'active',
        'submitted' => 'review',
        'pending_stripe' => 'pending_stripe',
        'draft' => 'draft',
        _ => 'corrections',
      };
      return (record.status == 'closed') == archived &&
          (statuses.isEmpty || statuses.contains(category));
    }).toList();
    return {
      'total': filtered.length,
      'total_owned': records.length,
      'items': filtered
          .skip((page - 1) * 20)
          .take(20)
          .map(
            (record) => <String, dynamic>{
              ...record.data,
              'program': program,
              'record': record.data,
              'pet_name': record.title,
              'need_types': <String>[],
            },
          )
          .toList(),
    };
  }

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

class EmptyPublicCaseRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage([
        RescueRecord({
          ...caseRecord.data,
          'target_cents': 0,
          'funded_cents': 0,
        }),
      ], 1);
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

class StripePendingCaseRescue extends FakeRescue {
  StripePendingCaseRescue({String status = 'draft'}) {
    current = RescueRecord({
      ...caseRecord.data,
      'owner_id': 'one',
      'status': status,
      'version': 4,
      'submitted_at': null,
      'target_cents': 0,
      'funded_cents': 0,
      'public_data': {
        'pet_name': 'Mora',
        'species': 'dog',
        'sex': 'unknown',
        'size': 'medium',
        'age': 'Adulto',
        'story': 'Rescatada bajo la lluvia, ahora necesita recuperarse.',
        'city': 'Monterrey',
        'state': 'Nuevo León',
        'need': 'Cuidados y seguimiento',
      },
      'files': <Json>[
        {'role': 'public', 'path': 'one/case-one/photo.jpg'},
      ],
    });
  }
  late RescueRecord current;
  final actions = <String>[];
  int detailReads = 0;
  int? submittedVersion;
  @override
  Future<Json> detail(String id) async {
    detailReads++;
    expect(id, current.id);
    return {'record': current.data, 'history': <Json>[]};
  }

  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async => kind == 'case' ? DataPage([current], 1) : const DataPage([], 0);

  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    expect(current.editable, isTrue);
    expect(record?.id, current.id);
    expect(record?.version, current.version);
    saveCalls++;
    current = RescueRecord({
      ...current.data,
      'version': current.version + 1,
      'public_data': publicData,
      'private_data': privateData,
      'files': files,
    });
    return current;
  }

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    expect(record.id, current.id);
    expect(record.version, current.version);
    actions.add(action);
    if (action == 'submit') submittedVersion = record.version;
    current = RescueRecord({
      ...current.data,
      'version': current.version + 1,
      'status': action == 'submit' ? 'pending_stripe' : 'draft',
      'submitted_at': null,
    });
    return current;
  }
}

class StripeCasePayments extends PaymentRepository {
  StripeCasePayments(this.rescue, {this.promoteOnRefresh = false})
    : super(rescue.client);
  final StripePendingCaseRescue rescue;
  final bool promoteOnRefresh;
  final actions = <String>[];
  @override
  Future<Json> action(String action, [Json fields = const {}]) async {
    expect(action, 'connect_status');
    expect(fields, isEmpty);
    actions.add(action);
    if (promoteOnRefresh) {
      rescue.current = RescueRecord({
        ...rescue.current.data,
        'status': 'submitted',
        'version': rescue.current.version + 1,
        'submitted_at': '2026-10-27T12:00:00Z',
      });
    }
    // A ready endpoint response alone must never promote the local case.
    return {'ready': true};
  }
}

class StripeCaseVideos extends VideoRepository {
  StripeCaseVideos()
    : super(
        identity: () => 'one:fixture',
        invoke: (_) async => throw const VideoFailure('unexpected_upload'),
      );
  @override
  Future<VideoPolicy> policy(String parentId) async => VideoPolicy(
    enabled: false,
    thanksRequired: false,
    urgencyAllowed: false,
    assets: [],
  );
}

Future<GoRouter> mountStripeCase(
  WidgetTester tester,
  StripePendingCaseRescue rescue,
  StripeCasePayments payments, {
  bool large = false,
}) async {
  tester.view.physicalSize = large
      ? const Size(320, 640)
      : const Size(377, 852);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  final videos = StripeCaseVideos();
  final router = GoRouter(
    initialLocation: '/rescue/case-one',
    routes: [
      GoRoute(
        path: '/rescue/:id',
        builder: (_, state) => RescueEditorScreen(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/my-cases',
        builder: (_, _) =>
            const Scaffold(body: Text('Mis casos después del envío')),
      ),
      GoRoute(
        path: '/connect',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Volver de Stripe'),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(videos.dispose);
  addTearDown(() => identity.changes.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(rescue),
        paymentRepositoryProvider.overrideWithValue(payments),
        rescueVideosRepositoryProvider.overrideWithValue(videos),
      ],
      child: MaterialApp.router(
        theme: dopmiTheme(rescuer: true),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapStripeCase(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    // Read-only cases use PageFrame's lazy outer ListView. Build controls below
    // the initial viewport by scrolling that list before ensureVisible.
    final scrollable = find
        .descendant(
          of: find.byType(PageFrame),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scrollable,
      maxScrolls: 20,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'new support submission waits privately for Stripe without a review success; large=$large',
      (tester) async {
        final rescue = StripePendingCaseRescue();
        final payments = StripeCasePayments(rescue);
        final router = await mountStripeCase(
          tester,
          rescue,
          payments,
          large: large,
        );
        final originalFiles = rescue.current.files;
        for (var step = 0; step < 3; step++) {
          await tapStripeCase(tester, find.text('Continuar'));
        }
        await tapStripeCase(tester, find.text('Enviar a revisión'));
        expect(find.text('Sólo un paso más…'), findsOneWidget);
        expect(find.text('Enviado a revisión'), findsNothing);
        expect(
          find.textContaining('guardado de forma privada'),
          findsOneWidget,
        );
        expect(rescue.current.pendingStripe, isTrue);
        expect(rescue.current.version, rescue.submittedVersion! + 1);
        expect(rescue.current.id, 'case-one');
        expect(rescue.current.files, originalFiles);
        expect(payments.actions, isEmpty);
        final dialog = find.byKey(const ValueKey('pending-stripe-dialog'));
        final card = tester.getRect(
          find.byKey(const ValueKey('pending-stripe-dialog-card')),
        );
        expect(card.left, greaterThanOrEqualTo(19.9));
        expect(card.right, lessThanOrEqualTo((large ? 320 : 377) - 19.9));
        expect(
          find.descendant(of: dialog, matching: find.byType(SvgPicture)),
          findsNWidgets(3),
        );
        final close = find.byKey(const ValueKey('pending-stripe-dialog-close'));
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
        for (final title in [
          'Pagos seguros',
          'Procesa las aportaciones',
          'Regístrate para recibir',
        ]) {
          await tester.ensureVisible(find.text(title));
          await tester.pumpAndSettle();
          expect(find.text(title).hitTestable(), findsOneWidget);
          expect(
            tester.getRect(find.text(title)).overlaps(tester.getRect(close)),
            isFalse,
            reason: 'The close target must scroll with the header rather than intercept Stripe guidance.',
          );
          expect(
            tester.getRect(find.text(title)).right,
            lessThanOrEqualTo(card.right - 23.9),
          );
        }
        final warning = find.textContaining(
          'Cuando Stripe confirme que tu cuenta está lista',
        );
        await tester.ensureVisible(warning);
        await tester.pumpAndSettle();
        expect(warning.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(warning).overlaps(tester.getRect(close)),
          isFalse,
        );
        final primary = find.byKey(const ValueKey('pending-stripe-continue'));
        final secondary = find.byKey(const ValueKey('pending-stripe-return'));
        await tester.ensureVisible(secondary);
        await tester.pumpAndSettle();
        final primaryRect = tester.getRect(primary);
        final secondaryRect = tester.getRect(secondary);
        expect(primaryRect.width, closeTo(card.width - 48, .1));
        expect(secondaryRect.width, closeTo(primaryRect.width, .1));
        expect(primaryRect.overlaps(secondaryRect), isFalse);
        expect(primaryRect.height, greaterThanOrEqualTo(48));
        expect(secondaryRect.height, greaterThanOrEqualTo(48));
        if (large) {
          expect(close.hitTestable(), findsNothing);
          await tapStripeCase(tester, primary);
          expect(router.state.uri.path, '/connect');
          expect(payments.actions, isEmpty);
          await tapStripeCase(tester, find.text('Volver de Stripe'));
          expect(router.state.uri.path, '/rescue/case-one');
          expect(payments.actions, ['connect_status']);
          expect(rescue.current.pendingStripe, isTrue);
          expect(find.text('Enviado a revisión'), findsNothing);
        } else {
          await tapStripeCase(tester, secondary);
          expect(router.state.uri.path, '/my-cases');
          expect(router.state.uri.queryParameters['program'], 'support');
        }
        expect(rescue.actions, ['submit']);
        expect(rescue.current.files, originalFiles);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final promoted in [false, true]) {
    testWidgets(
      'returning from Connect rereads the authoritative case; promoted=$promoted',
      (tester) async {
        final rescue = StripePendingCaseRescue(status: 'pending_stripe');
        final payments = StripeCasePayments(rescue, promoteOnRefresh: promoted);
        final router = await mountStripeCase(
          tester,
          rescue,
          payments,
          large: !promoted,
        );
        expect(router.state.uri.path, '/rescue/case-one');
        expect(rescue.detailReads, greaterThan(0));
        expect(find.text('Enviar a revisión'), findsNothing);
        expect(rescue.current.editable, isFalse);
        final reads = rescue.detailReads;
        await tapStripeCase(tester, find.text('Continuar a Stripe'));
        expect(router.state.uri.path, '/connect');
        await tapStripeCase(tester, find.text('Volver de Stripe'));
        expect(payments.actions, ['connect_status']);
        expect(rescue.detailReads, greaterThan(reads));
        expect(rescue.actions, isEmpty);
        expect(rescue.current.id, 'case-one');
        expect(
          rescue.current.status,
          promoted ? 'submitted' : 'pending_stripe',
        );
        expect(rescue.current.version, promoted ? 5 : 4);
        if (!promoted) {
          // Returning preserves the read-only list's scroll position. Bring the
          // private-state notice above the CTA back into the lazy viewport.
          await tester.scrollUntilVisible(
            find.textContaining('Tu caso sigue privado'),
            -200,
            scrollable: find
                .descendant(
                  of: find.byType(PageFrame),
                  matching: find.byType(Scrollable),
                )
                .first,
            maxScrolls: 20,
          );
          await tester.pumpAndSettle();
        }
        expect(
          find.textContaining('Tu caso ya se envió a revisión Dopmi'),
          promoted ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('Tu caso sigue privado'),
          promoted ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'a private Stripe-waiting case withdraws to the same editable draft',
    (tester) async {
      final rescue = StripePendingCaseRescue(status: 'pending_stripe');
      await mountStripeCase(tester, rescue, StripeCasePayments(rescue));
      final files = rescue.current.files;
      await tapStripeCase(tester, find.text('Retirar a borrador'));
      expect(rescue.actions, ['withdraw']);
      expect(rescue.current.editable, isTrue);
      expect(rescue.current.id, 'case-one');
      expect(rescue.current.version, 5);
      expect(rescue.current.files, files);
      expect(find.text('Guardar borrador'), findsOneWidget);
      expect(rescue.saveCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
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
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(rescue.photoRequests, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(rescue.photoRequests, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(rescue.photoRequests, 4);
    expect(find.text('Reintentar foto'), findsOneWidget);
    expect(tester.getSize(find.byType(RescuePublicPhoto)).height, 220);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(rescue.photoRequests, 4);
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
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      final retry = compact
          ? find.byTooltip('Foto no disponible. Reintentar foto')
          : find.text('Reintentar foto');
      await tester.tap(retry);
      await tester.pump();
      expect(rescue.photoRequests, 3);
      expect(retry, findsNothing);
      expect(tester.getSize(find.byType(RescuePublicPhoto)).height, 220);
      if (compact) {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      } else {
        expect(find.text('Cargando foto…'), findsOneWidget);
      }
      rescue.pending.completeError(StateError('offline again'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
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
      expect(rescue.photoRequests, 2);
      expect(
        tester.getSize(find.byType(RescuePublicPhoto)),
        const Size(76, 76),
      );
      await tester.tap(find.byTooltip('Foto no disponible. Reintentar foto'));
      await tester.pumpAndSettle();
      expect(rescue.photoRequests, 4);
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
      expect(
        find.byKey(const ValueKey('guardian-support-card-action')),
        findsOneWidget,
      );
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
        final promotion = find.byKey(
          const ValueKey('guardian-support-card-action'),
        );
        await tester.scrollUntilVisible(
          promotion,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(promotion, findsOneWidget);
        repo.failCatalog = false;
        await tester.scrollUntilVisible(
          find.text('Volver a intentar'),
          -150,
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
          find.text('Choco'),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('guardian-support-card-action')),
          findsOneWidget,
        );
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
    expect(find.text('Ayudar se siente bien'), findsNothing);
    expect(find.text('Suscríbete ahora'), findsOneWidget);

    final heroImage = find.image(
      const AssetImage('assets/guardian/guardian-carousel-hero.jpg'),
    );
    final heroSlide = find
        .ancestor(of: heroImage, matching: find.byType(Stack))
        .first;
    expect(
      find.descendant(of: heroSlide, matching: find.text('Sé un Guardián')),
      findsNothing,
    );
    expect(
      find.image(
        const AssetImage('assets/guardian/guardian-carousel-hero.jpg'),
      ),
      findsOneWidget,
    );
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
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Ver evidencia de Cirugía',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Ver evidencia de Cirugía',
      ),
    );
    await tester.pump();
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
    final contribution = find.widgetWithText(FilledButton, 'Quiero apoyar');
    expect(contribution, findsOneWidget);
    expect(tester.widget<FilledButton>(contribution).onPressed, isNotNull);
    expect(find.byTooltip('Apoyar al caso'), findsNothing);
    expect(
      tester
          .widget<PublicExpenseCard>(find.byType(PublicExpenseCard))
          .showContributeAction,
      isFalse,
    );
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
    await identity.setExperience('rescuer');
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
    expect(find.text('Mis pendientes'), findsOneWidget);
    expect(find.text('Mis pendientes para avanzar'), findsNothing);
    final messages = find.byKey(const ValueKey('home-quick-messages'));
    await tester.ensureVisible(messages);
    await tester.pumpAndSettle();
    await tester.tap(messages);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/messages');
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Mensajes recientes'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(DopmiBottomBar),
        matching: find.text('Inicio'),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/rescuer');
    final inbox = find.descendant(
      of: find.byType(DopmiBottomBar),
      matching: find.text('Mensajes'),
    );
    await tester.tap(inbox);
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
        routerInitialLocationProvider.overrideWithValue(
          '/my-cases?program=support',
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
    await tester.pumpAndSettle();
    expect(find.text('Choco'), findsOneWidget);
    expect(find.byTooltip('Editar publicación'), findsNothing);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('En proceso'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('owned-case-open-case-one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('owned-case-open-case-correction')),
      findsOneWidget,
    );
  });
  for (final entry in [
    'Suscríbete ahora',
    'Sé un Guardián',
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
        final label = entry.startsWith('keyboard-') ? 'Sé un Guardián' : entry;
        final target = label == 'Sé un Guardián'
            ? find.byKey(const ValueKey('guardian-support-card-action'))
            : find.text(label);
        await tester.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
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
          expect(data.label, contains('Sé un Guardián'));
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
            await tester.tap(target);
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
  for (final scale in [1.0, 1.15, 2.0]) {
    testWidgets(
      'case without available expenses keeps content without solicitation; scale=$scale',
      (tester) async {
        await startPublicCase(
          tester,
          EmptyPublicCaseRescue(),
          large: scale == 2,
        );
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle();
        expect(find.text('Ayúdame a recuperar:'), findsNothing);
        expect(find.text('Mi historia'), findsOneWidget);
        expect(find.byType(PublicRescueVideos), findsOneWidget);
        final notice = find.text(
          'Este caso no tiene gastos disponibles para aportar.',
        );
        await tester.scrollUntilVisible(
          notice,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(notice, findsOneWidget);
        final footer = find.widgetWithText(
          FilledButton,
          'Sin gastos disponibles',
        );
        expect(tester.widget<FilledButton>(footer).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'closed public case keeps history and disables every contribution entry',
    (tester) async {
      await startPublicCase(tester, ClosedPublicCaseRescue());
      expect(find.text('Ayúdame a recuperar:'), findsNothing);
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
      final expenseCard = tester.widget<PublicExpenseCard>(
        find.byType(PublicExpenseCard),
      );
      expect(expenseCard.canContribute, isFalse);
      expect(expenseCard.showContributeAction, isFalse);
      expect(find.byTooltip('Apoyar al caso'), findsNothing);
      expect(find.text('Quiero apoyar'), findsNothing);
      expect(tester.widget<FilledButton>(footer).onPressed, isNull);
      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(find.text('Elige un monto a donar:'), findsNothing);
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
      final firstDot = find.descendant(
        of: first,
        matching: find.byType(DecoratedBox),
      );
      final secondDot = find.descendant(
        of: second,
        matching: find.byType(DecoratedBox),
      );
      final firstRect = tester.getRect(firstDot);
      final secondRect = tester.getRect(secondDot);
      final heroRect = tester.getRect(find.byType(PageView));
      expect(firstRect.size, const Size(8, 8));
      expect(secondRect.size, const Size(7, 7));
      expect(heroRect.bottom - firstRect.bottom, closeTo(28, .01));
      expect(secondRect.left - firstRect.right, closeTo(6, .01));
      expect(
        (firstRect.left + secondRect.right) / 2,
        closeTo(heroRect.center.dx, .01),
      );
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
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final firstPhoto = find.byType(RescuePublicPhoto).first;
      final before = tester.getSize(firstPhoto);
      final requests = repo.photoRequests;
      await tester.tap(
        find.descendant(of: firstPhoto, matching: find.text('Reintentar foto')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.photoRequests, requests + 2);
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
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.calls, [1, 2]);
      expect(find.text('Gasto 22'), findsOneWidget);
      await tester.ensureVisible(find.text('Gasto 22'));
      await tester.pumpAndSettle();
      expect(find.byType(PublicExpenseCard), findsNWidgets(22));
      expect(find.byTooltip('Apoyar al caso'), findsNothing);
      final contribution = find.widgetWithText(FilledButton, 'Quiero apoyar');
      expect(contribution, findsOneWidget);
      expect(tester.widget<FilledButton>(contribution).onPressed, isNotNull);
      await tester.ensureVisible(contribution);
      await tester.tap(contribution);
      await tester.pumpAndSettle();
      expect(find.text('Elige un monto a donar:'), findsOneWidget);
      expect(find.text('\$75'), findsNothing);
      expect(find.text('\$50'), findsOneWidget);
      expect(find.text('\$200'), findsOneWidget);
      expect(find.text('\$500'), findsOneWidget);
      expect(find.text('Total faltante'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
