import 'dart:async';
import 'dart:convert';

import '../test/notifications_test.dart' show NotificationCommunity;

import 'package:dopmi_mobile/features/communication/match_thread_row.dart';
import 'package:dopmi_mobile/core/reference_focus_outline.dart';
import 'package:dopmi_mobile/features/rescue/support_home.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_activity.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_metrics.dart';
import 'package:dopmi_mobile/features/profile/rescuer_verification_card.dart';
import 'package:dopmi_mobile/features/profile/rescuer_settings_details.dart';
import 'package:dopmi_mobile/features/profile/rescuer_settings_verification.dart';
import 'package:dopmi_mobile/features/profile/rescuer_logout_row.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_access.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/help_support_dialog.dart';
import 'package:dopmi_mobile/features/profile/rescuer_social_dialog.dart';
import 'package:dopmi_mobile/features/profile/support_repository.dart';

import '../test/rescuer_profile_test.dart' show FakeRescuerProfile;

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_photo_client.dart';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/public_profile_layout.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_overview.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_hero.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/community_test.dart'
    show FakeCommunity, SavedRescuerCommunity, PagedSavedCommunity;
import '../test/fake_identity_repository.dart';
import '../test/fake_account_photo_repository.dart';

import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';

import '../test/rescue_test.dart' show FakeRescue, FakeCaseUpdates;
import '../test/rescuer_pending_evidence_test.dart' show PendingEvidenceRescue;
import '../test/case_publication_test.dart' show DraftCaseRescue;
import '../test/expense_field_test.dart'
    show DraftExpenseRescue, SubmittedExpenseRescue;
import '../test/payments_test.dart' show FakePayments;

import 'package:dopmi_mobile/features/payments/payment_repository.dart';

import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/owned_case_history.dart';

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

import '../test/guardian_history_test.dart' show cycle;
import '../test/guardian_test.dart' show FakeGuardian, activePlan;

import 'package:dopmi_mobile/features/payments/guardian_payment_card.dart';

import 'capture_design_test.dart' show saveCapture;

class MyAdoptionsCaptureCommunity extends FakeCommunity {
  MyAdoptionsCaptureCommunity({required this.empty, required this.fail});
  final bool empty, fail;
  @override
  Future<DataPage<Adoption>> mine(int page) async {
    if (fail) throw Exception('fixture unavailable');
    if (empty) return const DataPage([], 0);
    final items = [
      for (final status in [
        'draft',
        'submitted',
        'changes_requested',
        'published',
      ])
        Adoption({
          ...post.data,
          'id': 'own-$status',
          'owner_id': 'one',
          'pet_name': status == 'draft' ? '' : 'Luna',
          'status': status,
          if (status == 'changes_requested')
            'review_feedback':
                'Agrega una foto clara y confirma los cuidados necesarios.',
        }),
    ];
    return DataPage(items, items.length);
  }
}

class PublicProfileCaptureCommunity extends FakeCommunity {
  PublicProfileCaptureCommunity({this.reference = false});
  final bool reference;
  @override
  Future<Json?> publicProfile(String id) async => {
    ...?await super.publicProfile(id),
    'verified': true,
    if (reference) ...{
      'name': 'María R.',
      'city': 'Monterrey',
      'region': 'MX',
      'bio': 'Rescata perritos de calle desde 2019. Trabaja con una clínica veterinaria aliada en Monterrey.',
    },
    'instagram_url': 'https://instagram.com/fixture-refugio',
    'facebook_url': 'https://facebook.com/fixture-refugio',
    'metrics': {
      'published_cases': 1,
      'active_donation_cases': 1,
      'active_adoptions': 1,
      'published_donation_cases': 1,
      'published_adoptions': 3,
      'funded_cents': 2500,
      'completed_needs': 0,
      'helped_pets': 3,
      'closed_cases': 0,
    },
  };
}

class PublicProfileStateCaptureCommunity extends PublicProfileCaptureCommunity {
  PublicProfileStateCaptureCommunity(this.state) : super(reference: true);
  String state;
  final requestedProfiles = <String>[];
  final pending = Completer<Json?>();
  Future<void> finishLoading() async {
    state = 'ready';
    pending.complete(await super.publicProfile('owner'));
  }

  @override
  Future<Json?> publicProfile(String id) async {
    requestedProfiles.add(id);
    if (state == 'loading') return pending.future;
    if (state == 'error') throw Exception('fixture unavailable');
    if (state == 'unavailable') return null;
    return super.publicProfile(id);
  }
}

class ReportCaptureCommunity extends PublicProfileCaptureCommunity {
  ReportCaptureCommunity({required this.wait}) : super(reference: true);
  final bool wait;
  final pending = Completer<String>();
  @override
  Future<String> report(
    String type,
    String id,
    String reason,
    String details,
  ) async {
    if (wait) return pending.future;
    throw Exception('fixture network unavailable');
  }
}

class ManagedUpdatesCaptureRepository extends FakeCaseUpdates {
  ManagedUpdatesCaptureRepository({required this.empty, required this.fail});
  final bool empty, fail;
  @override
  Future<List<CaseUpdate>> mine(String caseId) async {
    if (fail) throw Exception('fixture unavailable');
    if (empty) return [];
    return [
      for (final status in [
        'draft',
        'submitted',
        'changes_requested',
        'approved',
      ])
        CaseUpdate({
          'id': 'update-$status',
          'case_id': caseId,
          'body': status == 'draft'
              ? ''
              : 'Luna recibió atención veterinaria y continúa su recuperación.',
          'status': status,
          'version': 1,
          'photos': <String>[],
        }),
    ];
  }
}

class OwnedHistoryCaptureUpdates extends FakeCaseUpdates {
  @override
  Future<List<CaseUpdate>> publicFor(String caseId) async => [
    CaseUpdate({
      'id': 'story-one',
      'case_id': caseId,
      'body': 'Choco recibió atención veterinaria y continúa su recuperación.',
      'photos': ['approved-story-one'],
      'published_at': '2026-09-30T16:00:00Z',
    }),
    CaseUpdate({
      'id': 'story-two',
      'case_id': caseId,
      'body': 'Seguimos los cuidados indicados por el equipo veterinario.',
      'photos': <String>[],
      'published_at': '2026-10-01T16:00:00Z',
    }),
  ];
  @override
  Future<String> photoUrl(String path) async =>
      'https://fixture.example.test/story/$path.png';
}

class CasePublicationCaptureRescue extends DraftCaseRescue {
  CasePublicationCaptureRescue({this.withNeeds = false, this.nameless = false});
  final bool withNeeds, nameless;
  @override
  Future<Json> detail(String id) async {
    final data = await super.detail(id);
    if (withNeeds || nameless) {
      final record = Json.from(data['record'] as Map);
      record['public_data'] = {
        ...Json.from(record['public_data'] as Map),
        if (nameless) 'pet_name': '',
        if (withNeeds)
          'need_items': [
            {
              'id': '11111111-1111-4111-8111-111111111111',
              'type': 'medicine',
              'title': 'Medicina prescrita',
              'amount_cents': 12345,
              'detail': 'Tratamiento indicado para su recuperación.',
              'urgent': true,
            },
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'type': 'veterinary',
              'title': 'Consulta veterinaria',
              'amount_cents': 70000,
              'detail': '',
              'urgent': false,
            },
          ],
      };
      return {...data, 'record': record};
    }
    return data;
  }

  @override
  Future<String> fileUrl(String path) async =>
      'https://fixture.test/case-photo.jpg';
}

class OwnedCasesCaptureRescue extends FakeRescue {
  @override
  Future<String> fileUrl(String path) async =>
      'https://fixture.example.test/owned-case.png';

  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async => DataPage([
    for (final status in [
      'approved',
      'draft',
      'submitted',
      'changes_requested',
      'closed',
    ])
      RescueRecord({
        ...caseRecord.data,
        'id': 'fixture-$status',
        'status': status,
        'public_data': {
          'pet_name':
              'Caso de ${{'approved': 'Luna', 'draft': 'Toby', 'submitted': 'Nala', 'changes_requested': 'Milo', 'closed': 'Sol'}[status]}',
          'photos': status == 'approved'
              ? <String>['fixture-owned-photo']
              : <String>[],
          'age': '2 años',
        },
        'feedback': status == 'changes_requested'
            ? 'Adjunta la evidencia solicitada.'
            : '',
      }),
  ], 5);
}

class OwnedCaseDetailCaptureRescue extends FakeRescue {
  OwnedCaseDetailCaptureRescue(this.closed);
  final bool closed;
  @override
  Future<String> fileUrl(String path) async =>
      'https://fixture.example.test/owned/$path.png';
  @override
  Future<Json> detail(String id) async => {
    'record': {
      ...caseRecord.data,
      'id': id,
      'owner_id': 'one',
      'status': closed ? 'closed' : 'approved',
      'public_data': {
        ...caseRecord.publicData,
        'age': '2 años',
        'photos': ['owner-one', 'owner-two'],
      },
    },
    'history': <Json>[],
  };
  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async => kind == 'expense'
      ? DataPage([
          RescueRecord({...expenseRecord.data, 'owner_id': 'one'}),
        ], 1)
      : super.mine(kind, page, parent: parent);
}

class EmptyOwnedCasesCaptureRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async => DataPage([], 0);
}

class ActivityRowsCaptureRescue extends FakeRescue {
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'recent_activity': [
      for (var n = 0; n < 3; n++)
        {
          'expense_id': 'expense-$n',
          'expense_title': 'Medicamentos',
          'allocated_cents': 3314,
          'transfer_status': n == 1 ? 'transferred' : 'pending',
        },
    ],
  };
}

class EmptyDashboardCaptureRescue extends FakeRescue {
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'pending': <Json>[],
    'recent_activity': <Json>[],
    'unread_messages': 0,
  };
}

class VerificationCaptureRescue extends FakeRescue {
  VerificationCaptureRescue(this.status);
  final String status;
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'verification_status': status,
  };
}

class VerificationStateCaptureRescue extends FakeRescue {
  VerificationStateCaptureRescue(this.status);
  final String status;
  @override
  Future<Json> detail(String id) async {
    final data = await super.detail(id);
    return {
      ...data,
      'record': {...Json.from(data['record']), 'status': status},
    };
  }
}

class SupportCaptureRescue extends FakeRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      caseId != null
      ? super.catalog(page, caseId: caseId)
      : DataPage([
          for (final item in [
            ('Luna', 1200, 1800),
            ('Milo', 800, 1200),
            ('Nina', 4500, 9500),
            ('Rocky', 25000, 145000),
          ])
            RescueRecord({
              'id': item.$1,
              'kind': 'case',
              'status': 'approved',
              'target_cents': item.$3,
              'funded_cents': item.$2,
              'public_data': {
                'pet_name': item.$1,
                'photos': ['fixture/approved'],
              },
            }),
        ], 4);
  @override
  Future<String> fileUrl(String path) async =>
      'https://fixture.invalid/approved';
}

class EmptySupportCaptureRescue extends SupportCaptureRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage([], 0);
}

class FailedSupportCaptureRescue extends SupportCaptureRescue {
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      throw Exception('offline');
}

class CaseCaptureRescue extends SupportCaptureRescue {
  CaseCaptureRescue({this.planned = false});
  final bool planned;
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage([
        RescueRecord({
          'id': 'case-one',
          'owner_id': 'rescuer-one',
          'kind': 'case',
          'status': 'approved',
          'target_cents': 250000,
          'funded_cents': 50000,
          'rescuer_name': 'Patricia V.',
          'public_data': {
            'pet_name': 'Rocky',
            if (planned)
              'need_items': [
                {
                  'id': 'reviewed-one',
                  'type': 'medicine',
                  'title': 'Tratamiento revisado',
                  'amount_cents': 12345,
                  'detail': 'Indicado para su recuperación',
                  'urgent': true,
                },
              ],
            'city': 'Monterrey',
            'state': 'MX',
            'story': 'Rocky llegó con heridas y desnutrición. Con tu apoyo cubriremos su cirugía, controles y alimentación mientras se recupera y busca un hogar.',
            'photos': ['fixture/one', 'fixture/two', 'fixture/three'],
          },
        }),
        for (final item in [
          ('Cirugía', 'veterinary', 145000, 25000),
          ('Cita veterinario', 'veterinary', 70000, 20000),
          ('Desparasitante', 'medicine', 25000, 5000),
          ('Croquetas', 'food', 10000, 0),
        ])
          RescueRecord({
            'id': item.$1,
            'kind': 'expense',
            'status': 'approved',
            'parent_id': 'case-one',
            'target_cents': item.$3,
            'funded_cents': item.$4,
            'public_data': {
              'title': item.$1,
              'category': item.$2,
              'photos': <String>[],
            },
          }),
      ], 5);
}

class PrivateFileCaptureRescue extends FakeRescue {
  PrivateFileCaptureRescue({required this.pdf, required this.readFails});
  final bool pdf, readFails;
  final requestedPaths = <String>[];
  String get path => 'one/verification-id/fixture.${pdf ? 'pdf' : 'png'}';
  @override
  Future<Json> detail(String id) async {
    final result = await super.detail(id);
    return {
      ...result,
      'record': {
        ...Json.from(result['record']),
        'owner_id': 'one',
        'files': [
          {'path': path, 'role': 'identity', 'name': 'Archivo de prueba'},
        ],
      },
    };
  }

  @override
  Future<String> fileUrl(String requestedPath) async {
    requestedPaths.add(requestedPath);
    if (requestedPath != path) throw StateError('Unexpected private path');
    if (readFails) throw Exception('fixture unavailable');
    return 'https://fixture.invalid/private-document.${pdf ? 'pdf' : 'png'}';
  }
}

class ConnectCapturePayments extends FakePayments {
  ConnectCapturePayments({required this.ready, required this.readFails});
  final bool ready, readFails;
  @override
  Future<Json> action(String action, [Json payload = const {}]) async {
    if (action != 'connect_status') {
      throw StateError('The capturer only reads Connect status');
    }
    if (readFails) throw Exception('fixture unavailable');
    return {
      'verified': ready,
      'ready': ready,
      'transfers_enabled': ready,
      'payouts_enabled': ready,
      'payouts': ready
          ? [
              {'amount': 431400, 'currency': 'mxn', 'status': 'paid'},
              {'amount': 98000, 'currency': 'mxn', 'status': 'pending'},
            ]
          : [],
    };
  }
}

class ContributionCapturePayments extends FakePayments {
  @override
  Future<Json> funding(String expense) async => {
    'title': 'Cirugía',
    'reimbursable_cents': 145000,
    'funded_cents': 25000,
    'transferred_cents': 0,
    'available_cents': 120000,
    'payable': true,
  };
}

class WaitingContributionCapturePayments extends ContributionCapturePayments {
  final response = Completer<Json>();
  @override
  Future<Json> checkout(String expense, int cents, String key) async =>
      response.future;
}

class HistoryCaptureGuardian extends FakeGuardian {
  HistoryCaptureGuardian({this.empty = false});
  final bool empty;
  @override
  Future<Json> history({Json? cursor}) async => {
    'items': empty
        ? <Json>[]
        : [
            cycle('fixture-cycle-paid', 'assigned'),
            cycle('fixture-cycle-skipped', 'skipped'),
            cycle('fixture-cycle-pending', 'processing'),
          ],
    'next_cursor': null,
  };
}

class HistoryCapturePayments extends FakePayments {
  HistoryCapturePayments({this.empty = false});
  final bool empty;
  @override
  Future<DataPage<Json>> history(int page, {bool received = false}) async {
    if (empty) return const DataPage([], 0);
    final fixture = await fixturePaymentHistory();
    return DataPage([
      for (var i = 0; i < fixture.items.length; i++)
        {
          ...fixture.items[i],
          'id': 'fixture-payment-$i',
          'expense_id': i == 0 ? 'expense-one' : 'fixture-expense-$i',
          'created_at': '2026-04-${29 - i * 4}T12:00:00Z',
          'processor': 'stripe',
          'transfer_status': 'pending',
        },
    ], fixture.total);
  }
}

class ResultCapturePayments extends ContributionCapturePayments {
  ResultCapturePayments(this.status) {
    this.fail = false;
  }
  final String status;
  @override
  Future<DataPage<Json>> history(int page, {bool received = false}) async =>
      calls.isEmpty
      ? const DataPage([], 0)
      : DataPage([
          {
            'idempotency_key': calls.last,
            'payment_status': status,
            'gross_cents': 10000,
            'allocated_cents': status == 'confirmed' ? 9200 : 0,
            'transfer_status': status == 'confirmed'
                ? 'pending'
                : 'not_started',
          },
        ], 1);
}

Future<DataPage<Json>> fixturePaymentHistory() async => const DataPage([
  {
    'expense_title': 'Max · Comida',
    'payment_status': 'confirmed',
    'gross_cents': 10000,
  },
  {
    'expense_title': 'Luna · Medicina',
    'payment_status': 'confirmed',
    'gross_cents': 12000,
  },
  {
    'expense_title': 'Milo · Tratamiento veterinario',
    'payment_status': 'pending',
    'gross_cents': 2500,
  },
], 3);

class RescuerReferenceCaptureCommunity extends FakeCommunity {
  @override
  Future<Json?> publicProfile(String id) async => {
    'id': id,
    'name': 'María Rescatista',
    'city': 'Ciudad de México',
    'region': 'CDMX',
    'bio': 'Refugio dedicado al rescate y rehabilitación de animales en situación de calle. Trabajamos con amor y compromiso para darles una segunda oportunidad.',
  };
}

class RescuerReferenceCaptureRescue extends FakeRescue {
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'case_counts': {'active': 0, 'draft': 0, 'review': 0, 'corrections': 0},
    'financial': {
      'assigned_cents': 0,
      'transferred_cents': 0,
      'in_review_cents': 0,
    },
    'recent_activity': <Json>[],
    'pending': <Json>[],
  };
}

class NotificationCountCaptureCommunity extends FakeCommunity {
  @override
  Future<int> unreadNotificationCount() async => 3;
}

class NotificationKindsCaptureCommunity extends NotificationCommunity {
  @override
  Future<DataPage<Json>> notifications(int page) async => DataPage([
    for (final kind in ['message', 'review', 'rescue'])
      {
        'id': 'notice-$kind',
        'kind': kind,
        'title': kind == 'message'
            ? 'Patricia te escribió'
            : kind == 'review'
            ? 'Tu publicación fue revisada'
            : 'Tu caso fue revisado',
        'rescue_id': kind == 'rescue' ? 'case-one' : null,
        'post_id': kind == 'review' ? 'post-one' : null,
        'thread_id': kind == 'message' ? 'thread-one' : null,
        'created_at': '2026-10-02T12:00:00Z',
        'read_at': null,
      },
  ], 3);
}

class DetailCaptureCommunity extends FakeCommunity {
  @override
  Future<String> photoUrl(String path) async => 'https://fixture.invalid/$path';
  @override
  Future<Json?> publicProfile(String id) async => {'verified': true};
}

class ChatHeaderCaptureCommunity extends DetailCaptureCommunity {
  @override
  Future<Json> thread(String id) async => {
    'id': id,
    'pet_name': 'Luna',
    'participant_name': 'Patricia V.',
    'post_id': 'post',
    'status': 'active',
  };
}

class ImpactCaptureCommunity extends DetailCaptureCommunity {
  ImpactCaptureCommunity(this.empty);
  final bool empty;
  @override
  Future<List<Json>> personalImpact() async => empty
      ? []
      : [
          {
            'case_id': 'case-one',
            'allocated_cents': 9200,
            'public_data': {
              'pet_name': 'Choco',
              'photos': ['approved-fixture.jpg'],
            },
            'updates': [
              {
                'id': 'approved-update',
                'body': 'Choco volvió a comer. Su avance está publicado por el rescatista.',
                'published_at': '2026-09-30T12:00:00Z',
              },
            ],
          },
        ];
}

void main() {
  testWidgets('capture actual profile/settings/publication screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = const Size(377, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
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
    // Match the reference browser's installed emoji font on Windows captures.
    // Mobile production uses the platform emoji fallback; no system font is bundled.
    if (Platform.isWindows) {
      final emoji = File(
        '${Platform.environment['SystemRoot'] ?? 'C:/Windows'}/Fonts/seguiemj.ttf',
      );
      if (emoji.existsSync()) {
        final loader = FontLoader(
          'Segoe UI Emoji',
        )..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())));
        await tester.runAsync(loader.load);
      }
    }
    final out = Directory('../../.tools/design-review');
    for (final path in [
      for (final name in [
        'logo-paw',
        'empty-pending-heart',
        'icon-star',
        'icon-shield',
        'icon-edit',
        'icon-donation-in',
        'icon-settings',
        'icon-instagram',
        'icon-facebook',
        'icon-bookmark',
        'check-circle',
        'notif-case',
        'notif-pet',
        'icon-messages',
        'rtab-cases',
        'rtab-home',
        'onb-camera',
        'rtab-publish',
        'onb-adopt-heart',
        'icon-user',
        'icon-card',
        'icon-billing',
        'icon-clock',
        'icon-heart',
        'icon-bell',
        'icon-wallet',
        'icon-chat-yellow',
        'icon-doc',
        'icon-help',
        'icon-logout',
        'icon-chevron-right',
        'tab-adoption',
        'tab-donate',
        'intent-rescuer',
        'icon-x-muted',
        'discovery-message',
        'back',
        'location',
        'icon-share',
        'icon-alert-circle',
        'icon-verified',
        'check',
        'payment-card-error',
        'empty-publish-plus',
      ])
        'assets/profile/$name.svg',
      for (final name in [
        'rtab-home',
        'tab-donate',
        'icon-heart',
        'tab-profile',
      ])
        'assets/navigation/$name.svg',
    ]) {
      final asset = SvgAssetLoader(path);
      await tester.runAsync(
        () => svg.cache.putIfAbsent(
          asset.cacheKey(null),
          () => asset.loadBytes(null),
        ),
      );
    }
    await tester.runAsync(() => out.create(recursive: true));
    final fixturePhoto = await tester.runAsync(
      () => File('tool/fixtures/rocky.png').readAsBytes(),
    );
    debugNetworkImageHttpClientProvider = () =>
        FixturePhotoClient(fixturePhoto!);
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    var captureCount = 0;
    final capturedNames = <String>{};
    var expectedAccountNavigation = 0, actualAccountNavigation = 0;
    var expectedConnectNavigation = 0, actualConnectNavigation = 0;
    var expectedPrivateFileNavigation = 0, actualPrivateFileNavigation = 0;
    var expectedPublicRecovery = 0, actualPublicRecovery = 0;
    for (final spec in [
      ('adoption-swipe', '/adoptions'),
      ('adoption-large', '/adoptions'),
      ('adoption-drag', '/adoptions'),
      ('adoption-filters', '/adoptions'),
      ('adoption-filters-large', '/adoptions'),
      ('adoption-contact', '/adoptions'),
      ('adoption-contact-large', '/adoptions'),
      ('adoption-detail', '/adoptions/post'),
      ('adoption-detail-large', '/adoptions/post'),
      ('adoption-empty', '/adoptions'),
      ('adoption-empty-large', '/adoptions'),
      ('adoption-empty-wide-large', '/adoptions'),
      ('adoption-end', '/adoptions'),
      ('match-threads', '/messages'),
      ('match-threads-large', '/messages'),
      ('match-all', '/messages'),
      ('match-all-large', '/messages'),
      ('match-empty', '/messages'),
      ('match-empty-large', '/messages'),
      ('chat-bubbles', '/messages/thread-one'),
      ('chat-bubbles-large', '/messages/thread-one'),
      ('chat-bubbles-rescuer', '/messages/thread-one'),
      ('chat-detail-focus', '/messages/thread-one'),
      ('chat-detail-focus-large', '/messages/thread-one'),
      ('chat-keyboard', '/messages/thread-one'),
      ('chat-keyboard-large', '/messages/thread-one'),
      ('rescuer-home-unverified', '/rescuer'),
      ('rescuer-home-unverified-large', '/rescuer'),
      ('rescuer-home-review', '/rescuer'),
      ('rescuer-home-review-large', '/rescuer'),
      ('rescuer-home-empty', '/rescuer'),
      ('rescuer-home-empty-large', '/rescuer'),
      ('rescuer-home-actions', '/rescuer'),
      ('rescuer-home-actions-large', '/rescuer'),
      ('rescuer-home-evidence', '/rescuer'),
      ('rescuer-home-evidence-large', '/rescuer'),
      ('owned-case-detail', '/rescue/case-one'),
      ('owned-case-detail-back-focus', '/rescue/case-one'),
      ('owned-case-detail-dot-focus', '/rescue/case-one'),
      ('owned-case-detail-dot-focus-large', '/rescue/case-one'),
      ('owned-case-detail-back-focus-large', '/rescue/case-one'),
      ('owned-case-detail-large', '/rescue/case-one'),
      ('owned-case-detail-story', '/rescue/case-one'),
      ('owned-case-detail-story-large', '/rescue/case-one'),
      ('owned-case-detail-history-empty', '/rescue/case-one'),
      ('owned-case-detail-history-empty-large', '/rescue/case-one'),
      ('owned-case-detail-bottom', '/rescue/case-one'),
      ('owned-case-detail-bottom-large', '/rescue/case-one'),
      ('owned-case-detail-closed', '/rescue/case-one'),
      ('owned-case-detail-closed-large', '/rescue/case-one'),
      ('owned-cases', '/my-cases'),
      ('owned-cases-large', '/my-cases'),
      ('owned-cases-empty', '/my-cases'),
      ('owned-cases-empty-large', '/my-cases'),
      ('owned-cases-correction', '/my-cases'),
      ('owned-cases-correction-large', '/my-cases'),
      ('rescuer-home', '/rescuer'),
      ('rescuer-home-large', '/rescuer'),
      ('support-home', '/rescue-cases'),
      ('notifications-reference', '/notifications'),
      ('notifications-reference-large', '/notifications'),
      ('notifications-reference-read', '/notifications'),
      ('notifications-reference-kinds', '/notifications'),
      ('notifications-reference-kinds-large', '/notifications'),
      ('notifications-reference-header-focus', '/notifications'),
      ('notifications-reference-header-focus-large', '/notifications'),
      ('support-home-large', '/rescue-cases'),
      ('support-home-empty', '/rescue-cases'),
      ('support-home-empty-large', '/rescue-cases'),
      ('support-home-error', '/rescue-cases'),
      ('support-home-error-large', '/rescue-cases'),
      ('support-home-error-retry', '/rescue-cases'),
      ('support-home-error-retry-large', '/rescue-cases'),
      ('support-home-notification-focus', '/rescue-cases'),
      ('support-home-notification-focus-large', '/rescue-cases'),
      ('support-home-notification-badge', '/rescue-cases'),
      ('support-home-notification-badge-large', '/rescue-cases'),
      ('support-home-case-focus', '/rescue-cases'),
      ('support-home-case-focus-large', '/rescue-cases'),
      ('support-home-guardian-card-focus', '/rescue-cases'),
      ('support-home-guardian-card-focus-large', '/rescue-cases'),
      ('support-home-guardian-dock-focus', '/rescue-cases'),
      ('support-home-guardian-dock-focus-large', '/rescue-cases'),
      ('case-detail', '/rescue-cases/case-one'),
      ('case-detail-photo-focus', '/rescue-cases/case-one'),
      ('case-detail-photo-focus-large', '/rescue-cases/case-one'),
      ('case-detail-story', '/rescue-cases/case-one'),
      ('case-detail-story-large', '/rescue-cases/case-one'),
      ('case-detail-gallery', '/rescue-cases/case-one'),
      ('case-detail-gallery-large', '/rescue-cases/case-one'),
      ('case-detail-amount', '/rescue-cases/case-one'),
      ('case-detail-amount-large', '/rescue-cases/case-one'),
      ('case-detail-planned', '/rescue-cases/case-one'),
      ('case-detail-planned-large', '/rescue-cases/case-one'),
      (
        'contribution-result-confirmed',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-result-confirmed-large',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-result-pending',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-result-canceled',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-result-refunded',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),

      (
        'contribution-review',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-review-large',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-waiting',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      (
        'contribution-waiting-large',
        '/contribute/Cirugía?case=case-one&amount_cents=10000',
      ),
      ('payment-methods', '/settings/payment-methods'),
      ('payment-methods-large', '/settings/payment-methods'),
      ('payment-methods-inactive', '/settings/payment-methods'),
      ('payment-methods-cards', '/settings/payment-methods'),
      ('payment-methods-cards-canceled', '/settings/payment-methods'),
      ('payment-methods-cards-canceled-large', '/settings/payment-methods'),
      ('payment-methods-cards-canceled-waiting', '/settings/payment-methods'),
      (
        'payment-methods-cards-canceled-waiting-large',
        '/settings/payment-methods',
      ),
      (
        'payment-methods-cards-canceled-waiting-footer-large',
        '/settings/payment-methods',
      ),
      (
        'payment-methods-cards-independent-default-confirm',
        '/settings/payment-methods',
      ),
      (
        'payment-methods-cards-independent-default-confirm-large',
        '/settings/payment-methods',
      ),
      (
        'payment-methods-cards-independent-remove-confirm',
        '/settings/payment-methods',
      ),
      (
        'payment-methods-cards-independent-remove-confirm-large',
        '/settings/payment-methods',
      ),
      ('payment-methods-cards-add-confirm', '/settings/payment-methods'),
      ('payment-methods-cards-add-confirm-large', '/settings/payment-methods'),
      ('payment-methods-cards-added-toast', '/settings/payment-methods'),
      ('payment-methods-cards-added-toast-large', '/settings/payment-methods'),

      ('payment-methods-cards-large', '/settings/payment-methods'),
      ('payment-methods-cards-default-toast', '/settings/payment-methods'),
      (
        'payment-methods-cards-default-toast-large',
        '/settings/payment-methods',
      ),
      ('payment-methods-cards-remove-confirm', '/settings/payment-methods'),
      (
        'payment-methods-cards-remove-confirm-large',
        '/settings/payment-methods',
      ),
      ('guardian-billing-amount', '/guardian'),
      ('guardian-billing-amount-large', '/guardian'),
      ('guardian-billing-cancel', '/guardian'),
      ('guardian-billing-cancel-large', '/guardian'),
      ('guardian-billing-history-large', '/guardian'),
      ('guardian-billing-receipt', '/guardian'),
      ('guardian-billing-inactive', '/guardian'),
      ('guardian-billing-inactive-large', '/guardian'),
      ('impact-feed', '/impact?history=1'),
      ('impact-feed-large', '/impact?history=1'),
      ('impact-feed-empty', '/impact?history=1'),
      ('impact-feed-empty-large', '/impact?history=1'),
      ('impact-entry', '/impact'),
      ('impact-entry-large', '/impact'),
      ('guardian-promotion', '/impact/guardian'),
      ('guardian-promotion-large', '/impact/guardian'),
      ('guardian-promotion-controls-large', '/impact/guardian'),
      ('guardian-promotion-join-large', '/impact/guardian'),
      ('guardian-promotion-second', '/impact/guardian'),
      ('guardian-promotion-reports', '/impact/guardian'),
      ('guardian-billing-enrollment', '/guardian'),
      ('guardian-billing-enrollment-large', '/guardian'),
      ('guardian-billing-enrollment-custom', '/guardian'),
      ('guardian-billing-enrollment-custom-large', '/guardian'),
      ('guardian-billing-enrollment-confirmation', '/guardian'),
      ('guardian-billing-enrollment-confirmation-large', '/guardian'),
      ('guardian-billing-active', '/guardian'),
      ('guardian-billing-active-large', '/guardian'),
      ('guardian-activation-success', '/guardian'),
      ('guardian-activation-success-large', '/guardian'),
      ('guardian-activation-failed', '/guardian'),
      ('guardian-activation-failed-large', '/guardian'),
      ('saved-adoptions', '/saved'),
      ('saved-adoptions-large', '/saved'),
      ('saved-adoptions-empty', '/saved'),
      ('saved-adoptions-empty-large', '/saved'),
      ('saved-rescuers-empty', '/saved?kind=rescuer'),
      ('saved-rescuers-empty-large', '/saved?kind=rescuer'),
      ('saved-rescuers', '/saved?kind=rescuer'),
      ('saved-rescuers-large', '/saved?kind=rescuer'),
      ('saved-pagination-large', '/saved'),
      ('saved-pagination-second-large', '/saved'),
      ('basic-info', '/basic-info'),
      ('basic-info-large', '/basic-info'),
      ('basic-info-keyboard-large', '/basic-info'),
      ('basic-info-saved', '/basic-info'),
      ('basic-info-saved-large', '/basic-info'),
      ('legal-terms', '/terms'),
      ('legal-terms-large', '/terms'),
      ('legal-privacy', '/privacy-notice'),
      ('legal-privacy-large', '/privacy-notice'),
      ('help-center', '/help'),
      ('help-center-large', '/help'),
      ('help-center-topic-held', '/help'),
      ('help-center-topic-held-large', '/help'),
      ('help-center-footer', '/help'),
      ('help-center-footer-large', '/help'),
      ('help-center-adoption-large', '/help'),
      ('help-center-support', '/help'),
      ('help-center-support-large', '/help'),
      ('help-center-support-keyboard', '/help'),
      ('help-center-support-keyboard-large', '/help'),
      ('help-center-support-rescuer', '/help'),
      ('help-center-support-rescuer-large', '/help'),
      ('help-center-support-photo', '/help'),
      ('help-center-support-photo-large', '/help'),
      ('help-center-support-received', '/help'),
      ('help-center-support-received-large', '/help'),
      ('help-center-rules', '/help'),
      ('help-center-rules-large', '/help'),
      ('public-profile-editor', '/rescuer/profile/edit'),
      ('public-profile-editor-large', '/rescuer/profile/edit'),
      ('public-profile-editor-keyboard-large', '/rescuer/profile/edit'),
      ('guardian-history', '/guardian/history'),
      ('guardian-history-large', '/guardian/history'),
      ('guardian-history-empty', '/guardian/history'),
      ('guardian-history-empty-large', '/guardian/history'),
      ('payment-history', '/payments'),
      ('payment-history-large', '/payments'),
      ('payment-history-empty', '/payments'),
      ('contribution-amount', '/contribute/Cirugía?case=case-one'),
      ('contribution-amount-large', '/contribute/Cirugía?case=case-one'),
      ('case-detail-large', '/rescue-cases/case-one'),
      ('case-detail-expenses', '/rescue-cases/case-one'),
      ('case-detail-expenses-large', '/rescue-cases/case-one'),
      ('rescuer-messages', '/messages'),
      ('rescuer-messages-large', '/messages'),
      ('rescuer-messages-empty', '/messages'),
      ('rescuer-messages-empty-large', '/messages'),
      ('match-threads-photo-search', '/messages'),
      ('match-threads-photo-search-large', '/messages'),
      ('match-threads-photo-focus', '/messages'),
      ('match-threads-photo-focus-large', '/messages'),
      ('match-threads-focus', '/messages'),
      ('match-threads-focus-large', '/messages'),
      ('match-home', '/messages'),
      ('match-home-large', '/messages'),
      ('adoption-support', '/adoptions'),
      ('adoption-support-large', '/adoptions'),
      ('rescuer-profile', '/profile'),
      ('rescuer-profile-home-link-focus', '/profile'),
      ('rescuer-profile-row-focus', '/profile'),
      ('rescuer-profile-row-focus-large', '/profile'),
      ('rescuer-profile-reference', '/profile'),
      ('rescuer-profile-reference-wide', '/profile'),
      ('rescuer-profile-reference-focus', '/profile'),
      ('rescuer-profile-reference-activity-focus', '/profile'),
      ('rescuer-profile-reference-metric-focus', '/profile'),
      ('rescuer-profile-reference-transfer-focus', '/profile'),
      ('rescuer-profile-reference-transfer-focus-large', '/profile'),
      ('rescuer-profile-reference-large', '/profile'),
      ('rescuer-settings', '/settings'),
      ('rescuer-settings-scroll-blur', '/settings'),
      ('rescuer-settings-footer', '/settings'),
      ('rescuer-settings-logout-focus', '/settings'),
      ('rescuer-settings-mode-focus', '/settings'),
      ('rescuer-settings-edit-focus', '/settings'),
      ('rescuer-settings-large', '/settings'),
      ('rescuer-settings-social-dialog', '/settings'),
      ('rescuer-settings-social-dialog-valid', '/settings'),
      ('rescuer-settings-social-values', '/settings'),
      ('rescuer-settings-social-values-large', '/settings'),
      ('rescuer-settings-social-dialog-large', '/settings'),
      ('rescuer-settings-social-dialog-facebook', '/settings'),
      ('rescuer-settings-social-dialog-keyboard', '/settings'),
      ('rescuer-settings-social-dialog-keyboard-large', '/settings'),
      ('rescuer-profile-large', '/profile'),
      ('public-profile', '/people/owner'),
      ('public-profile-large', '/people/owner'),
      ('public-profile-reference', '/people/owner'),
      ('public-profile-reference-large', '/people/owner'),
      ('public-profile-state-loading', '/people/owner'),
      ('public-profile-state-loading-large', '/people/owner'),
      ('public-profile-state-error', '/people/owner'),
      ('public-profile-state-error-large', '/people/owner'),
      ('public-profile-state-unavailable', '/people/owner'),
      ('public-profile-state-unavailable-large', '/people/owner'),
      ('public-profile-metrics', '/people/owner'),
      ('public-profile-metrics-large', '/people/owner'),
      ('public-profile-metrics-stats', '/people/owner'),
      ('public-profile-metrics-stats-large', '/people/owner'),
      ('public-profile-adoptions', '/people/owner'),
      ('public-profile-adoptions-large', '/people/owner'),
      ('public-profile-report-reference-error', '/people/owner'),
      ('public-profile-report-reference-error-large', '/people/owner'),
      ('public-profile-report-reference-sending', '/people/owner'),
      ('public-profile-report-reference-sending-large', '/people/owner'),
      ('public-profile-report-reference', '/people/owner'),
      ('public-profile-report-reference-large', '/people/owner'),
      ('public-profile-report-reference-keyboard-large', '/people/owner'),
      ('public-profile-cases', '/people/owner'),
      ('public-profile-cases-large', '/people/owner'),
      ('profile-overview', '/profile'),
      ('profile-overview-active', '/profile'),
      ('profile-overview-large', '/profile'),
      ('profile-mode-dialog', '/profile'),
      ('profile-settings', '/settings'),
      ('profile-settings-large', '/settings'),
      ('profile-settings-footer', '/settings'),
      ('profile-settings-footer-large', '/settings'),
      ('profile-support', '/profile'),
      ('about', '/about'),
      ('about-large', '/about'),
      ('transparency', '/transparency'),
      ('transparency-criteria', '/transparency'),
      ('publish-choice', '/publish'),
      ('publish-choice-large', '/publish'),
      ('managed-updates', '/rescue-cases/case-one/updates'),
      ('managed-updates-large', '/rescue-cases/case-one/updates'),
      ('managed-updates-empty', '/rescue-cases/case-one/updates'),
      ('managed-updates-empty-large', '/rescue-cases/case-one/updates'),
      ('managed-updates-error', '/rescue-cases/case-one/updates'),
      ('managed-updates-error-large', '/rescue-cases/case-one/updates'),
      ('managed-updates-editor-new', '/rescue-cases/case-one/updates/new'),
      (
        'managed-updates-editor-new-large',
        '/rescue-cases/case-one/updates/new',
      ),
      (
        'managed-updates-editor-draft',
        '/rescue-cases/case-one/updates/update-changes_requested',
      ),
      (
        'managed-updates-editor-draft-large',
        '/rescue-cases/case-one/updates/update-changes_requested',
      ),
      (
        'managed-updates-editor-error',
        '/rescue-cases/case-one/updates/update-draft',
      ),
      (
        'managed-updates-editor-error-large',
        '/rescue-cases/case-one/updates/update-draft',
      ),
      ('account-access-options', '/settings/account'),
      ('private-file-image', '/rescue/verification-id'),
      ('private-file-image-large', '/rescue/verification-id'),
      ('private-file-image-content-large', '/rescue/verification-id'),
      ('private-file-pdf', '/rescue/verification-id'),
      ('private-file-pdf-large', '/rescue/verification-id'),
      ('private-file-pdf-content-large', '/rescue/verification-id'),
      ('private-file-error', '/rescue/verification-id'),
      ('private-file-error-large', '/rescue/verification-id'),
      ('private-file-error-content-large', '/rescue/verification-id'),
      ('connect-account-ready', '/connect'),
      ('connect-account-ready-large', '/connect'),
      ('connect-account-ready-content-large', '/connect'),
      ('connect-account-pending', '/connect'),
      ('connect-account-pending-large', '/connect'),
      ('connect-account-pending-content-large', '/connect'),
      ('connect-account-error', '/connect'),
      ('connect-account-error-large', '/connect'),
      ('connect-account-error-content-large', '/connect'),
      ('account-access-options-large', '/settings/account'),
      ('account-access-options-content-large', '/settings/account'),
      ('account-access-consent', '/consent'),
      ('account-access-consent-large', '/consent'),
      ('account-access-consent-content-large', '/consent'),
      ('account-access-privacy', '/account-privacy'),
      ('account-access-privacy-large', '/account-privacy'),
      ('account-access-privacy-content-large', '/account-privacy'),
      ('my-adoptions', '/my-adoptions'),
      ('my-adoptions-large', '/my-adoptions'),
      ('my-adoptions-empty', '/my-adoptions'),
      ('my-adoptions-empty-large', '/my-adoptions'),
      ('my-adoptions-error', '/my-adoptions'),
      ('my-adoptions-error-large', '/my-adoptions'),
      ('my-adoptions-content-large', '/my-adoptions'),
      ('my-adoptions-empty-content-large', '/my-adoptions'),
      ('my-adoptions-error-content-large', '/my-adoptions'),
      ('publish-photos', '/my-adoptions/new'),
      ('publish-photos-large', '/my-adoptions/new'),
      ('publish-photo-grid', '/my-adoptions/post'),
      ('publish-photo-grid-large', '/my-adoptions/post'),
      ('publish-information', '/my-adoptions/post'),
      ('publish-information-large', '/my-adoptions/post'),
      ('publish-review', '/my-adoptions/post'),
      ('publish-review-large', '/my-adoptions/post'),
      ('publish-review-social', '/my-adoptions/post'),
      ('publish-review-social-large', '/my-adoptions/post'),
      ('publish-health', '/my-adoptions/post'),
      ('publish-health-large', '/my-adoptions/post'),
      ('expense-submitted', '/rescue/expense-one'),
      ('expense-submitted-large', '/rescue/expense-one'),
      ('expense-submitted-footer-large', '/rescue/expense-one'),
      ('case-publication', '/rescue/new?kind=case'),
      ('case-publication-header-focus', '/rescue/new?kind=case'),
      ('case-publication-header-focus-large', '/rescue/new?kind=case'),
      ('case-publication-large', '/rescue/new?kind=case'),
      ('case-publication-information-nameless', '/rescue/case-one'),
      ('case-publication-information-nameless-large', '/rescue/case-one'),
      ('case-publication-review-nameless', '/rescue/case-one'),
      ('case-publication-review-nameless-large', '/rescue/case-one'),
      ('case-publication-needs-list', '/rescue/case-one'),
      ('case-publication-needs-list-large', '/rescue/case-one'),
      ('case-publication-review-list', '/rescue/case-one'),
      ('case-publication-review-list-large', '/rescue/case-one'),
      ('case-publication-needs-medicine', '/rescue/case-one'),
      ('case-publication-needs-medicine-large', '/rescue/case-one'),
      ('case-publication-needs-food', '/rescue/case-one'),
      ('case-publication-needs-food-large', '/rescue/case-one'),
      ('case-publication-needs-veterinary', '/rescue/case-one'),
      ('case-publication-needs-veterinary-large', '/rescue/case-one'),
      ('case-publication-needs', '/rescue/case-one'),
      ('case-publication-needs-large', '/rescue/case-one'),
      ('case-publication-review', '/rescue/case-one'),
      ('case-publication-review-large', '/rescue/case-one'),
      ('case-publication-information', '/rescue/case-one'),
      ('case-publication-information-large', '/rescue/case-one'),
      ('case-publication-grid', '/rescue/case-one'),
      ('case-publication-grid-large', '/rescue/case-one'),
      ('expense-record', '/rescue/expense-one'),
      ('expense-record-large', '/rescue/expense-one'),
      ('expense-review', '/rescue/expense-one'),
      ('expense-review-large', '/rescue/expense-one'),
      ('expense-review-private', '/rescue/expense-one'),
      ('expense-review-private-large', '/rescue/expense-one'),
      ('expense-dialog', '/rescue/expense-one'),
      ('expense-dialog-large', '/rescue/expense-one'),
      ('expense-evidence', '/rescue/expense-one'),
      ('expense-evidence-large', '/rescue/expense-one'),
      ('expense-information', '/rescue/expense-one'),
      ('expense-information-large', '/rescue/expense-one'),
      ('expense-private', '/rescue/expense-one'),
      ('expense-private-large', '/rescue/expense-one'),
      ('verification-intro', '/rescue/new?kind=verification'),
      ('verification-intro-large', '/rescue/new?kind=verification'),
      ('verification-form', '/rescue/new?kind=verification'),
      ('verification-form-large', '/rescue/new?kind=verification'),
      ('verification-form-documents', '/rescue/new?kind=verification'),
      ('verification-form-documents-large', '/rescue/new?kind=verification'),
      ('verification-form-progress', '/rescue/new?kind=verification'),
      ('verification-form-progress-large', '/rescue/new?kind=verification'),
      ('verification-approved', '/rescue/verification-id'),
      ('verification-approved-large', '/rescue/verification-id'),
      ('verification-review', '/rescue/verification-id'),
      ('verification-review-large', '/rescue/verification-id'),
    ]) {
      const captureFilter = String.fromEnvironment('CAPTURE_FILTER');
      if (captureFilter.isNotEmpty && !spec.$1.startsWith(captureFilter)) {
        continue;
      }
      expect(
        capturedNames.add(spec.$1),
        true,
        reason: 'Fixture names must not overwrite another captured state',
      );
      captureCount++;
      if (spec.$1.startsWith('public-profile-state-loading') ||
          spec.$1.startsWith('public-profile-state-error')) {
        expectedPublicRecovery++;
      }
      if (spec.$1.startsWith('private-file')) expectedPrivateFileNavigation++;
      if (spec.$1.startsWith('connect-account') &&
          !spec.$1.contains('content')) {
        expectedConnectNavigation++;
      }
      if (spec.$1 == 'account-access-options' ||
          spec.$1 == 'account-access-options-large') {
        expectedAccountNavigation++;
      }
      final waitingPayment = WaitingContributionCapturePayments();
      final privateFile = PrivateFileCaptureRescue(
        pdf: spec.$1.contains('-pdf'),
        readFails: spec.$1.startsWith('private-file-error'),
      );
      // Synthetic preferences belong only to this flutter_test capturer.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await repo.saveProfile(name: 'Ana', phone: '', city: 'Monterrey, NL');
      if (spec.$1.startsWith('account-access-consent')) {
        repo.profile = const Profile(
          id: 'one',
          name: 'Ana',
          phone: '',
          city: 'Monterrey, NL',
          mode: 'donor',
          intent: 'adopt',
          status: 'active',
          termsVersion: null,
          privacyVersion: null,
          adultConfirmed: false,
        );
      }
      if (spec.$1.startsWith('rescuer-profile-reference')) {
        // Synthetic account from the public mockup; never production identity.
        repo.user = const Identity(
          'one',
          'maria@rescatista.com',
          verified: true,
        );
        await repo.saveProfile(
          name: 'María Rescatista',
          phone: '+52 55 1234 5678',
          city: 'Ciudad de México, CDMX',
        );
      }
      final large = spec.$1.endsWith('-large');
      tester.view.physicalSize = large && spec.$1 != 'adoption-empty-wide-large'
          ? const Size(320, 640)
          : (spec.$1 == 'rescuer-profile-reference-wide' ||
                spec.$1.startsWith('rescuer-messages'))
          ? const Size(384, 852)
          : const Size(377, 852);
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      if (spec.$1.startsWith('adoption-support')) {
        final milo = await tester.runAsync(
          () => File('tool/fixtures/milo.png').readAsBytes(),
        );
        debugNetworkImageHttpClientProvider = () => FixturePhotoClient(milo!);
      } else {
        debugNetworkImageHttpClientProvider = () =>
            FixturePhotoClient(fixturePhoto!);
      }
      final guardian =
          (spec.$1.startsWith('payment-history') ||
              spec.$1.startsWith('guardian-billing') ||
              spec.$1.startsWith('guardian-history'))
          ? HistoryCaptureGuardian(
              empty:
                  spec.$1.endsWith('-empty') ||
                  (spec.$1.startsWith('guardian-history') &&
                      spec.$1.contains('-empty')) ||
                  spec.$1.contains('inactive') ||
                  spec.$1.contains('enrollment'),
            )
          : FakeGuardian();
      if (spec.$1.startsWith('payment-methods') &&
          !spec.$1.contains('inactive')) {
        guardian.value = {
          'plan': activePlan(),
          'activation': null,
          'method_change_available': true,
        };
      }
      if (spec.$1.startsWith('payment-methods-cards')) {
        if (spec.$1.contains('canceled')) {
          guardian.value = {
            'plan': {
              ...activePlan(),
              'status': 'canceled',
              'payment_in_flight': spec.$1.contains('waiting'),
            },
            'activation': null,
            'method_change_available': false,
          };
        }
        if (spec.$1.contains('independent')) {
          guardian.value = {'plan': null, 'activation': null};
        }
        guardian.applySelected = spec.$1.contains('default-toast');
        guardian.cards = [
          const GuardianPaymentCard(
            id: 'pm_one',
            brand: 'visa',
            last4: '4242',
            isDefault: true,
          ),
          const GuardianPaymentCard(
            id: 'pm_two',
            brand: 'mastercard',
            last4: '5556',
            isDefault: false,
          ),
        ];
      }
      if (spec.$1.startsWith('guardian-activation-')) {
        // Synthetic checkout is scoped to this flutter_test capturer.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({
          'dopmi-guardian:one:intent': jsonEncode({
            'kind': 'checkout',
            'key': 'capture-confirmed',
            'cents': 7525,
            'consent_version': guardianConsent,
          }),
        });
        guardian.value = {
          'plan': spec.$1.contains('failed')
              ? null
              : {
                  ...activePlan(),
                  'gross_cents': 7525,
                  'next_billing_at': '2026-11-02T18:00:00Z',
                },
          'activation': {
            'status': spec.$1.contains('failed') ? 'failed' : 'active',
            'key': 'capture-confirmed',
            'gross_cents': 7525,
          },
        };
      }
      final community = spec.$1.startsWith('my-adoptions')
          ? MyAdoptionsCaptureCommunity(
              empty: spec.$1.contains('empty'),
              fail: spec.$1.contains('error'),
            )
          : spec.$1.startsWith('saved-pagination')
          ? PagedSavedCommunity()
          : spec.$1 == 'saved-rescuers' || spec.$1 == 'saved-rescuers-large'
          ? SavedRescuerCommunity()
          : spec.$1.startsWith('saved-adoptions-empty')
          ? (FakeCommunity()..savedItems = [])
          : spec.$1.startsWith('notifications-reference-kinds')
          ? NotificationKindsCaptureCommunity()
          : spec.$1.startsWith('support-home-notification-badge')
          ? NotificationCountCaptureCommunity()
          : spec.$1.startsWith('notifications-reference')
          ? (NotificationCommunity()..read = spec.$1.endsWith('-read'))
          : spec.$1.startsWith('rescuer-profile-reference')
          ? RescuerReferenceCaptureCommunity()
          : (spec.$1.startsWith('chat-detail-focus') ||
                spec.$1.startsWith('chat-keyboard'))
          ? ChatHeaderCaptureCommunity()
          : spec.$1.startsWith('impact-feed')
          ? ImpactCaptureCommunity(spec.$1.contains('empty'))
          : (spec.$1 == 'adoption-swipe' ||
                spec.$1 == 'adoption-large' ||
                spec.$1.startsWith('adoption-detail') ||
                spec.$1 == 'adoption-end' ||
                spec.$1.startsWith('adoption-support') ||
                spec.$1.startsWith('match-threads-photo') ||
                (spec.$1.startsWith('publish-photo-grid') ||
                    (spec.$1.startsWith('publish-information') ||
                        spec.$1.startsWith('publish-review') ||
                        spec.$1.startsWith('publish-health'))))
          ? DetailCaptureCommunity()
          : spec.$1.startsWith('public-profile-state')
          ? PublicProfileStateCaptureCommunity(
              spec.$1
                  .replaceFirst('public-profile-state-', '')
                  .replaceFirst('-large', ''),
            )
          : spec.$1.startsWith('public-profile-report-reference') &&
                (spec.$1.contains('error') || spec.$1.contains('sending'))
          ? ReportCaptureCommunity(wait: spec.$1.contains('sending'))
          : spec.$1.startsWith('public-profile')
          ? PublicProfileCaptureCommunity(
              reference: spec.$1.contains('-reference'),
            )
          : FakeCommunity();
      if (spec.$1.startsWith('adoption-empty')) community.discoveryItems = [];
      if ((spec.$1.startsWith('publish-photo-grid') ||
          (spec.$1.startsWith('publish-information') ||
              spec.$1.startsWith('publish-review') ||
              spec.$1.startsWith('publish-health')))) {
        community.post = Adoption({
          ...community.post.data,
          'status': 'draft',
          'photos': ['fixture/one', 'fixture/two'],
        });
      }
      if ((spec.$1 == 'adoption-swipe' ||
          spec.$1 == 'adoption-large' ||
          spec.$1.startsWith('adoption-detail') ||
          spec.$1 == 'adoption-end')) {
        community.post = Adoption({
          ...community.post.data,
          'pet_name': 'Rocky',
          'publisher_name': 'Patricia V.',
          'sex': 'male',
          'size': 'large',
          'region': 'MX',
          'distance_km': 3.4,
          'story': 'Rescatado de la calle el mes pasado. Muy amistoso y listo para encontrar hogar.',
          'photos': ['fixture/one', 'fixture/two', 'fixture/three'],
          'saved': true,
        });
      }
      if (spec.$1 == 'adoption-drag') {
        // The actual deck includes a second card beneath a drag.
        community.discoveryItems = [
          community.post,
          Adoption({...community.post.data, 'id': 'next', 'pet_name': 'Milo'}),
        ];
      }
      if (spec.$1 == 'profile-overview-active' ||
          (spec.$1.startsWith('guardian-billing') &&
              !spec.$1.contains('inactive') &&
              !spec.$1.contains('enrollment'))) {
        guardian.value = {
          'plan': {
            ...activePlan(),
            if (spec.$1.startsWith('guardian-billing'))
              'next_billing_at': '2026-10-24T12:00:00Z',
          },
          'activation': null,
        };
      }
      if (spec.$1.startsWith('owned-case-detail') ||
          spec.$1.startsWith('private-file') ||
          spec.$1.startsWith('connect-account') ||
          spec.$1.startsWith('account-access-options') ||
          spec.$1.startsWith('managed-updates') ||
          spec.$1.startsWith('owned-cases') ||
          spec.$1.startsWith('rescuer-home') ||
          spec.$1.startsWith('rescuer-profile') ||
          spec.$1.startsWith('public-profile-editor') ||
          spec.$1.startsWith('rescuer-settings') ||
          spec.$1.startsWith('help-center-support-rescuer') ||
          spec.$1.startsWith('case-publication') ||
          spec.$1.startsWith('publish-') ||
          spec.$1.startsWith('verification-') ||
          spec.$1.startsWith('rescuer-messages') ||
          spec.$1 == 'chat-bubbles-rescuer') {
        await repo.setExperience('rescuer');
      }
      if (spec.$1.startsWith('rescuer-messages')) {
        community.threadItems = spec.$1.contains('empty')
            ? []
            : [
                {
                  'id': 'thread-one',
                  'participant_name': 'Ana Patricia Hernandez',
                  'updated_at': '2025-09-30T18:30:00Z',
                  'pet_name': 'Luna',
                  'last_message': 'Perfecto. Nos vemos el fin de semana.',
                  'unread_count': 3,
                  'status': 'active',
                },
                {
                  'id': 'thread-two',
                  'participant_name': 'Carlos M.',
                  'pet_name': 'Rocky',
                  'last_message': 'Puedo visitarlo este fin de semana?',
                  'unread_count': 0,
                  'status': 'active',
                },
                {
                  'id': 'thread-three',
                  'participant_name': 'Lucia G.',
                  'pet_name': 'Milo',
                  'last_message': 'Gracias por la actualizacion!',
                  'unread_count': 0,
                  'status': 'closed',
                },
              ];
      }
      final container = ProviderContainer(
        overrides: [
          if (spec.$1.startsWith('payment-history'))
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          identityRepositoryProvider.overrideWithValue(repo),
          accountPhotoRepositoryProvider.overrideWithValue(
            emptyAccountPhotoRepository(repo),
          ),
          communityRepositoryProvider.overrideWithValue(community),
          if (spec.$1.startsWith('public-profile-cases'))
            rescueRepositoryProvider.overrideWithValue(FakeRescue()),
          if (spec.$1.startsWith('private-file'))
            rescueRepositoryProvider.overrideWithValue(privateFile),
          if (spec.$1.startsWith('rescuer-profile') ||
              spec.$1.startsWith('rescuer-settings') ||
              spec.$1.startsWith('connect-account') ||
              spec.$1.startsWith('account-access-options'))
            rescueRepositoryProvider.overrideWithValue(
              spec.$1.startsWith('rescuer-profile-reference')
                  ? RescuerReferenceCaptureRescue()
                  : spec.$1.startsWith('rescuer-profile-row-focus')
                  ? ActivityRowsCaptureRescue()
                  : FakeRescue(),
            ),
          if (spec.$1.startsWith('rescuer-settings') ||
              spec.$1.startsWith('public-profile-editor'))
            rescuerProfileRepositoryProvider.overrideWithValue(
              SettingsSocialCaptureProfile()
                ..value['owner_id'] = 'one'
                ..value['instagram_url'] =
                    (spec.$1 == 'rescuer-settings-social-dialog-valid' ||
                        spec.$1.startsWith('rescuer-settings-social-values'))
                    ? 'https://www.instagram.com/maria.rescata'
                    : '',
            ),
          if (spec.$1.startsWith('case-publication'))
            rescueRepositoryProvider.overrideWithValue(
              CasePublicationCaptureRescue(
                withNeeds: spec.$1.contains('-list'),
                nameless: spec.$1.contains('-nameless'),
              ),
            ),
          if (spec.$1.startsWith('expense-'))
            rescueRepositoryProvider.overrideWithValue(
              spec.$1.startsWith('expense-record')
                  ? (SubmittedExpenseRescue()..remoteStatus = 'submitted')
                  : spec.$1.startsWith('expense-submitted')
                  ? SubmittedExpenseRescue()
                  : DraftExpenseRescue(),
            ),
          if (spec.$1.startsWith('verification-approved') ||
              spec.$1.startsWith('verification-review'))
            rescueRepositoryProvider.overrideWithValue(
              VerificationStateCaptureRescue(
                spec.$1.startsWith('verification-approved')
                    ? 'approved'
                    : 'submitted',
              ),
            ),

          if (spec.$1.startsWith('owned-case-detail'))
            rescueRepositoryProvider.overrideWithValue(
              OwnedCaseDetailCaptureRescue(spec.$1.contains('closed')),
            ),
          if (spec.$1.startsWith('owned-cases'))
            rescueRepositoryProvider.overrideWithValue(
              spec.$1.contains('empty')
                  ? EmptyOwnedCasesCaptureRescue()
                  : OwnedCasesCaptureRescue(),
            ),
          if (spec.$1.startsWith('rescuer-home'))
            rescueRepositoryProvider.overrideWithValue(
              spec.$1.contains('evidence')
                  ? PendingEvidenceRescue()
                  : spec.$1.contains('empty')
                  ? EmptyDashboardCaptureRescue()
                  : spec.$1.contains('unverified')
                  ? VerificationCaptureRescue('not_started')
                  : spec.$1.contains('review')
                  ? VerificationCaptureRescue('submitted')
                  : FakeRescue(),
            ),
          if (spec.$1.startsWith('payment-history'))
            paymentRepositoryProvider.overrideWithValue(
              HistoryCapturePayments(empty: spec.$1.endsWith('-empty')),
            ),
          if (spec.$1.startsWith('connect-account'))
            paymentRepositoryProvider.overrideWithValue(
              ConnectCapturePayments(
                ready: spec.$1.contains('ready'),
                readFails: spec.$1.contains('error'),
              ),
            ),
          if (spec.$1.startsWith('contribution'))
            paymentRepositoryProvider.overrideWithValue(
              spec.$1.startsWith('contribution-result')
                  ? ResultCapturePayments(
                      spec.$1
                          .replaceFirst('contribution-result-', '')
                          .replaceFirst('-large', ''),
                    )
                  : spec.$1.startsWith('contribution-waiting')
                  ? waitingPayment
                  : ContributionCapturePayments(),
            ),
          if (spec.$1.startsWith('owned-case-detail'))
            paymentRepositoryProvider.overrideWithValue(
              ContributionCapturePayments(),
            ),
          if (spec.$1.startsWith('owned-case-detail'))
            caseUpdateRepositoryProvider.overrideWithValue(
              spec.$1.contains('history-empty')
                  ? FakeCaseUpdates()
                  : OwnedHistoryCaptureUpdates(),
            ),
          if (spec.$1.startsWith('case-detail') ||
              spec.$1.startsWith('contribution')) ...[
            rescueRepositoryProvider.overrideWithValue(
              CaseCaptureRescue(
                planned: spec.$1.startsWith('case-detail-planned'),
              ),
            ),
            caseUpdateRepositoryProvider.overrideWithValue(
              spec.$1.startsWith('case-detail-story')
                  ? OwnedHistoryCaptureUpdates()
                  : FakeCaseUpdates(),
            ),
          ],
          if (spec.$1.startsWith('impact-feed'))
            rescueRepositoryProvider.overrideWithValue(SupportCaptureRescue()),
          if (spec.$1.startsWith('support-home'))
            rescueRepositoryProvider.overrideWithValue(
              spec.$1.startsWith('support-home-empty')
                  ? EmptySupportCaptureRescue()
                  : spec.$1.startsWith('support-home-error')
                  ? FailedSupportCaptureRescue()
                  : SupportCaptureRescue(),
            ),
          if (spec.$1.startsWith('managed-updates'))
            caseUpdateRepositoryProvider.overrideWithValue(
              ManagedUpdatesCaptureRepository(
                empty: spec.$1.contains('empty'),
                fail: spec.$1.contains('error'),
              ),
            ),
          guardianEnabledProvider.overrideWithValue(true),
          guardianRepositoryProvider.overrideWithValue(guardian),
          profilePaymentHistoryProvider.overrideWithValue(
            fixturePaymentHistory,
          ),
          routerInitialLocationProvider.overrideWithValue(spec.$2),
        ],
      );
      final key = GlobalKey();
      if (spec.$1.startsWith('adoption-support')) {
        community.discoveryItems = [
          community.post,
          Adoption({...community.post.data, 'id': 'second'}),
        ];
        community.supportItems = [
          SupportOpportunity({
            'case_id': 'case-one',
            'expense_id': 'expense-one',
            'pet_name': 'Milo',
            'photo': 'approved/milo.png',
            'expense_title': 'Spray para heridas',
            'reimbursable_cents': 1200,
            'funded_cents': 800,
          }),
        ];
      }
      if (spec.$1.startsWith('match-threads-photo')) {
        community.post = Adoption({
          ...community.post.data,
          'photos': ['approved/rocky.png'],
        });
        await tester.runAsync(() async {
          final ready = Completer<void>();
          final stream = const NetworkImage(
            'https://fixture.invalid/approved/rocky.png',
          ).resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener(
            (info, synchronous) => ready.complete(),
            onError: (Object error, StackTrace? stack) =>
                ready.completeError(error, stack),
          );
          stream.addListener(listener);
          try {
            await ready.future.timeout(const Duration(seconds: 10));
          } finally {
            stream.removeListener(listener);
          }
        });
      }
      if (spec.$1.startsWith('match-threads')) {
        community.threadItems = [
          {
            'id': 'one',
            'post_id': 'post',
            'pet_name': 'Rocky',
            'participant_name': 'Patricia V.',
            'last_message': 'Perfecto. ¿Cuándo podrías visitarlo?',
            'unread_count': 1,
            'status': 'active',
            'updated_at': '2026-09-30T18:30:00Z',
          },
          {
            'id': 'two',
            'pet_name': 'Toby',
            'participant_name': 'Carlos Ruiz',
            'last_message':
                'Gracias por tu interés en adoptar. ¿Quieres conocerlo?',
            'unread_count': 0,
            'status': 'active',
          },
        ];
      }
      if (spec.$1.startsWith('match-empty')) community.savedItems = [];
      if (spec.$1.startsWith('chat-bubbles')) {
        community.stored.addAll({
          'one': {
            'id': 'one',
            'sender_id': 'rescuer',
            'body': 'Hola, gracias por interesarte en Luna.',
            'created_at': '2026-10-01T16:30:00Z',
          },
          'two': {
            'id': 'two',
            'sender_id': 'one',
            'body': 'Me gustaría conocerla este fin de semana.',
            'created_at': '2026-10-01T16:31:00Z',
          },
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        ),
      );
      // Let the signed URL future mount its image, then let the fixture image
      // stream decode before settling animated loading indicators.
      for (var imagePhase = 0; imagePhase < 3; imagePhase++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
      }
      if (spec.$1.startsWith('public-profile-state-loading')) {
        await tester.pump();
      } else {
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      if (spec.$1.startsWith('private-file')) {
        final openFile = find.text('Ver archivo 1');
        await tester.scrollUntilVisible(
          openFile,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(openFile);
        await tester.pumpAndSettle();
        expect(openFile.hitTestable(), findsOneWidget);
        await tester.tap(openFile);
        for (var phase = 0; phase < 3; phase++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        }
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/rescue-file');
        expect(privateFile.requestedPaths, [privateFile.path]);
        if (spec.$1.contains('content')) {
          final reload = find.text('Recargar archivo');
          await tester.scrollUntilVisible(
            reload,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(reload);
          await tester.pumpAndSettle();
          expect(reload.hitTestable(), findsOneWidget);
          await tester.tap(reload);
          await tester.pumpAndSettle();
          expect(privateFile.requestedPaths, [
            privateFile.path,
            privateFile.path,
          ]);
        }
      }
      if (spec.$1.startsWith('saved-pagination')) {
        await tester.ensureVisible(find.byTooltip('Página siguiente'));
        await tester.pumpAndSettle();
        if (spec.$1.contains('-second')) {
          await tester.tap(find.byTooltip('Página siguiente'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip('Página anterior'));
          await tester.pumpAndSettle();
          expect(find.text('Guardado 21'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
      if (spec.$1.startsWith('help-center-support')) {
        final support = find.widgetWithText(
          FilledButton,
          'Contactar a soporte',
        );
        await tester.scrollUntilVisible(
          support,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(support);
        await tester.pumpAndSettle();
        await tester.tap(support);
        await tester.pumpAndSettle();
        final photoState = spec.$1.contains('-photo');
        final receiptState = spec.$1.contains('-received');
        if (photoState || receiptState) {
          await tester.tap(find.byTooltip('Cerrar'));
          await tester.pumpAndSettle();
          final photo = await tester.runAsync(
            () => File('tool/fixtures/milo.png').readAsBytes(),
          );
          unawaited(
            showHelpSupportDialog(
              tester.element(support),
              topics: const ['Cómo funcionan los apoyos'],
              initialTopic: 0,
              pickImage: () async => photo,
              repository: SupportRepository(
                (_, params) async => {
                  'request_id': params['target_request'],
                  'status': 'received',
                },
                upload: (id, _) async => 'fixture/$id/photo.jpg',
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        final next = find.widgetWithText(FilledButton, 'Enviar mensaje');
        expect(tester.widget<FilledButton>(next).onPressed, isNull);
        expect(find.text('Continuar en correo'), findsNothing);
        await tester.enterText(
          find.byType(TextField).last,
          'Necesito ayuda con mi cuenta.',
        );
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
        if (spec.$1.contains('-keyboard')) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        expect(next.hitTestable(), findsOneWidget);
        expect(find.text('Recibimos tu mensaje.'), findsNothing);
        if (!large &&
            !photoState &&
            !receiptState &&
            !spec.$1.contains('-keyboard')) {
          expect(
            tester.getSize(find.byType(DropdownButtonFormField<int>)).height,
            closeTo(45, .1),
          );
          expect(
            tester.getSize(find.byType(TextField).first).height,
            closeTo(44, .1),
          );
          expect(
            tester.getSize(find.byType(TextField).last).height,
            closeTo(96, .1),
          );
          final card = tester.getRect(
            find.byKey(const ValueKey('help-support-card')),
          );
          expect(card.height, closeTo(505.59375, .5));
          expect(
            tester.getCenter(find.byTooltip('Cerrar')).dx,
            closeTo(331.71875, .1),
          );
          expect(
            tester.getCenter(find.byTooltip('Cerrar')).dy - card.top,
            closeTo(24, .1),
          );
          expect(
            tester
                .widget<FilledButton>(next)
                .style!
                .backgroundColor!
                .resolve({}),
            const Color(0xfff7cb2d),
          );
        }
        if (photoState) {
          final attach = find.widgetWithText(
            OutlinedButton,
            'Adjuntar imagen (opcional)',
          );
          await tester.ensureVisible(attach);
          await tester.pumpAndSettle();
          await tester.tap(attach);
          // Image preparation runs in a real isolate. Keep servicing real time
          // until it finishes instead of settling an animated loading state.
          for (
            var attempt = 0;
            attempt < 200 && find.text('Cambiar imagen').evaluate().isEmpty;
            attempt++
          ) {
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            });
            await tester.pump();
          }
          expect(find.text('Cambiar imagen'), findsOneWidget);
          await tester.pumpAndSettle();
          expect(find.text('Cambiar imagen'), findsOneWidget);
          expect(find.byType(Image), findsOneWidget);
          await tester.runAsync(
            () => precacheImage(
              tester.widget<Image>(find.byType(Image)).image,
              tester.element(find.byType(Image)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
        }
        if (receiptState) {
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(find.text('Recibimos tu mensaje.'), findsOneWidget);
          expect(find.text('Entendido'), findsOneWidget);
          expect(find.text('Enviar mensaje'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
      if (spec.$1.startsWith('help-center-rules')) {
        final rules = find.widgetWithText(
          OutlinedButton,
          'Cómo funcionan los apoyos',
        );
        await tester.ensureVisible(rules);
        await tester.pumpAndSettle();
        await tester.tap(rules);
        await tester.pumpAndSettle();
        final heading = find.text('Cuando apoyas a un caso');
        await tester.scrollUntilVisible(
          heading,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(heading), alignment: .1);
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextButton, 'Cuando apoyas a un caso'),
          findsNothing,
        );
        expect(find.textContaining('gastos ya pagados'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      if (spec.$1.startsWith('help-center-footer')) {
        final footer = find.widgetWithText(TextButton, 'Aviso de privacidad');
        await tester.scrollUntilVisible(
          footer,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(footer), alignment: 1);
        await tester.pumpAndSettle();
        expect(footer.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      if (spec.$1 == 'help-center-adoption-large') {
        final topic = find.widgetWithText(OutlinedButton, 'Adoptar');
        await tester.ensureVisible(topic);
        await tester.pumpAndSettle();
        expect(topic.hitTestable(), findsOneWidget);
        await tester.tap(topic);
        await tester.pumpAndSettle();
        final faq = find.text('¿Cómo contacto a una rescatista?');
        await tester.ensureVisible(faq);
        await tester.pumpAndSettle();
        expect(faq.hitTestable(), findsOneWidget);
        await tester.tap(faq);
        await tester.pumpAndSettle();
        final answer = find.textContaining('La conversación sólo es visible');
        expect(answer, findsOneWidget);
        await tester.ensureVisible(answer);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      if (spec.$1.startsWith('public-profile-editor-keyboard')) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        final facebook = find.byKey(
          const ValueKey('public-profile-Facebook (https://)'),
        );
        await tester.scrollUntilVisible(
          facebook,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(facebook, 'https://facebook.com/refugio');
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Guardar borrador');
        await tester.scrollUntilVisible(
          save,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(340));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Guardamos tu borrador.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      if (spec.$1.startsWith('basic-info-saved')) {
        final save = find.widgetWithText(FilledButton, 'Guardar cambios');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Cambios guardados'), findsOneWidget);
      }
      if (spec.$1.startsWith('basic-info-keyboard')) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.ensureVisible(find.byType(TextFormField).last);
        await tester.enterText(
          find.byType(TextFormField).last,
          'Ciudad de México, CDMX',
        );
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Guardar cambios');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(340));
        expect(tester.takeException(), isNull);
      }
      if (spec.$1.startsWith('chat-keyboard')) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.enterText(
          find.byType(TextField),
          'Quiero conocer a Luna.',
        );
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.byTooltip('Enviar mensaje')).dy,
          lessThanOrEqualTo(tester.view.physicalSize.height - 300),
        );
      }
      if (spec.$1.startsWith('public-profile-report-reference')) {
        final report = find.byTooltip('Reportar');
        if (report.hitTestable().evaluate().isEmpty) {
          await Scrollable.ensureVisible(
            tester.element(report),
            alignment: .35,
          );
        }
        await tester.pumpAndSettle();
        expect(report.hitTestable(), findsOneWidget);
        await tester.tap(report);
        await tester.pumpAndSettle();
        expect(find.text('Reportar rescatista'), findsOneWidget);
        if (spec.$1.contains('keyboard')) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.enterText(
            find.byType(TextField),
            'Información del perfil incorrecta',
          );
          await tester.pumpAndSettle();
          final send = find.widgetWithText(FilledButton, 'Enviar reporte');
          await tester.ensureVisible(send);
          await tester.pumpAndSettle();
          expect(send.hitTestable(), findsOneWidget);
          expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(340));
        }
        if (spec.$1.contains('error') || spec.$1.contains('sending')) {
          await tester.enterText(
            find.byType(TextField),
            'Información del perfil incorrecta',
          );
          final send = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(FilledButton),
          );
          await tester.ensureVisible(send);
          await tester.pumpAndSettle();
          await tester.tap(send);
          if (spec.$1.contains('sending')) {
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            expect(tester.widget<FilledButton>(send).onPressed, isNull);
          } else {
            await tester.pumpAndSettle();
            expect(
              find.text(
                'No pudimos completar la solicitud. Comprueba tu conexión y vuelve a intentar.',
              ),
              findsOneWidget,
            );
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              'Información del perfil incorrecta',
            );
            await tester.ensureVisible(send);
            await tester.pumpAndSettle();
          }
        }
        expect(tester.takeException(), isNull);
      }
      if (spec.$1.startsWith('public-profile-adoptions')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('En adopción')),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('En adopción'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Conoce la historia de Luna'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('public-profile-metrics')) {
        final target = spec.$1.contains('-stats')
            ? find.text('Casos de donación')
            : find.textContaining('Numeralia de lo que');
        await Scrollable.ensureVisible(tester.element(target), alignment: .15);
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('public-profile-cases')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('Casos')),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Casos'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ver caso'));
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'support-home') {
        // Source dock measured in IAB377x852, a3c969c.
        final cta = tester.getRect(
          find.byKey(const ValueKey('guardian-support-cta')),
        );
        final price = tester.getRect(find.text('Desde \$50 / mes'));
        expect(cta.top, closeTo(716, 1));
        expect(cta.height, closeTo(44, 1));
        expect(cta.width, closeTo(152.4, 1));
        expect(cta.left, closeTo(189.2, 1));
        expect(price.width, closeTo(114.475, 1));
        expect(price.top, closeTo(729.6, 1));
      }
      if (spec.$1 == 'support-home-empty') {
        expect(
          tester.getTopLeft(find.text('Sé un Guardián')).dy,
          closeTo(136.8, 1),
        );
        expect(
          tester.getTopLeft(find.byType(GuardianSupportCard)).dy,
          closeTo(252.55, 1),
        );
        expect(
          tester
              .widget<GuardianSupportCard>(find.byType(GuardianSupportCard))
              .height,
          closeTo(895.2, 1),
        );
      }
      if (spec.$1 == 'adoption-empty') {
        // Effective Source cascade measured in IAB at377x852, a3c969c.
        final card = tester.getRect(
          find.byKey(const ValueKey('discovery-empty-card')),
        );
        final action = tester.getRect(
          find.widgetWithText(FilledButton, 'Ir a Apoyar'),
        );
        debugPrint(
          'Empty metrics: card=$card action=$action title=${tester.getRect(find.byKey(const ValueKey('discovery-empty-heading')))}',
        );
        expect(card.top, closeTo(144, 1));
        expect(card.width, closeTo(320, 1));
        expect(card.height, closeTo(276.9, 1));
        // Source fractional line boxes vs Flutter whole-pixel line heights
        // accumulate 1.1px here (measured title62 vs62.4, body60 vs60.9).
        expect(action.top, closeTo(336.1, 2));
        expect(action.width, closeTo(270.4, 1));
      }
      if (spec.$1 == 'guardian-promotion-controls-large') {
        final dot = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Ir a la página 3 de 3',
        );
        await tester.ensureVisible(dot);
        await tester.tap(dot);
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'guardian-promotion-join-large') {
        await tester.ensureVisible(find.text('Unirme como Guardián'));
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'guardian-promotion-second' ||
          spec.$1 == 'guardian-promotion-reports') {
        final index = spec.$1.endsWith('reports') ? 3 : 2;
        final dot = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Ir a la página $index de 3',
        );
        await tester.ensureVisible(dot);
        await tester.tap(dot);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Conviértete en Guardián'));
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, 200),
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('guardian-billing-enrollment')) {
        await tester.tap(find.text('Suscribirme'));
        await tester.pumpAndSettle();
        if (spec.$1.contains('custom')) {
          await tester.ensureVisible(find.text('Otra cantidad'));
          await tester.tap(find.text('Otra cantidad'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('guardian-enrollment-custom-amount')),
            '75.25',
          );
          await tester.pumpAndSettle();
          if (!large) {
            FocusManager.instance.primaryFocus?.unfocus();
            Scrollable.of(
              tester.element(
                find.byKey(const ValueKey('guardian-enrollment-custom-amount')),
              ),
            ).position.jumpTo(0);
            await tester.pumpAndSettle();
            expect(
              InputDecorator.containerOf(
                tester.element(
                  find.descendant(
                    of: find.byKey(
                      const ValueKey('guardian-enrollment-custom-amount'),
                    ),
                    matching: find.byType(EditableText),
                  ),
                ),
              )!.size.height,
              closeTo(75.2, 1),
            );
          }
        }
        if (spec.$1.contains('confirmation')) {
          await tester.ensureVisible(find.text('Activar en Stripe'));
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1 == 'guardian-billing-history-large') {
        await tester.ensureVisible(find.text('Historial de pagos'));
        await Scrollable.ensureVisible(
          tester.element(find.text('Historial de pagos')),
          alignment: .1,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('guardian-activation-') && large) {
        final label = spec.$1.contains('failed')
            ? 'Intentar de nuevo'
            : 'Volver a Apoyar';
        final text = tester.getRect(find.text(label));
        final button = tester.getRect(find.widgetWithText(FilledButton, label));
        expect(text.top, greaterThanOrEqualTo(button.top));
        expect(text.bottom, lessThanOrEqualTo(button.bottom));
        await tester.ensureVisible(find.text('Volver a Apoyar'));
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'guardian-billing-receipt') {
        await tester.ensureVisible(find.text('Suscripción').first);
        await tester.tap(find.text('Suscripción').first);
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.text('Neto asignado: \$43.14 MXN')),
          alignment: .2,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('guardian-billing-amount')) {
        await tester.ensureVisible(find.text('Cambiar cantidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cambiar cantidad'));
        await tester.pumpAndSettle();
        expect(find.text('Guardar nueva cantidad'), findsOneWidget);
      }
      if (spec.$1.startsWith('guardian-billing-cancel')) {
        await tester.ensureVisible(find.text('Cancelar suscripción'));
        await tester.tap(find.text('Cancelar suscripción'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('contribution-result')) {
        await tester.ensureVisible(find.text('Confirmar en Stripe'));
        await tester.tap(find.text('Confirmar en Stripe'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('contribution-waiting')) {
        await tester.ensureVisible(find.text('Confirmar en Stripe'));
        await tester.tap(find.text('Confirmar en Stripe'));
        await tester.pump(const Duration(milliseconds: 300));
        await Scrollable.ensureVisible(
          tester.element(find.text('Confirmar en Stripe')),
          alignment: .35,
        );
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (spec.$1.startsWith('adoption-support')) {
        for (var i = 0; i < 2; i++) {
          await Scrollable.ensureVisible(
            tester.element(find.byTooltip('Pasar')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Pasar'));
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1.startsWith('adoption-support')) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'match-threads-large') {
        await tester.scrollUntilVisible(
          find.text('Perfecto. ¿Cuándo podrías visitarlo?'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('match-all')) {
        await tester.tap(find.text('Ver más'));
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'match-empty-large') {
        await tester.scrollUntilVisible(
          find.text('Explorar'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Explorar')),
          alignment: .35,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('case-detail-planned')) {
        await tester.scrollUntilVisible(
          find.text('Tratamiento revisado'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Costos estimados')),
          alignment: .1,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('case-detail-amount')) {
        await tester.tap(find.text('Donar'));
        await tester.pumpAndSettle();
        if (!large) {
          expect(tester.getSize(find.byType(TextField)).height, closeTo(52, 1));
          expect(
            tester.getSize(find.text('Otra cantidad:')).height,
            closeTo(18.4, 1),
          );
        }
      }
      if (spec.$1.startsWith('case-detail-expenses')) {
        final card = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Ocultar evidencia de Cirugía',
        );
        await tester.scrollUntilVisible(
          card,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(card), alignment: .1);
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('notifications-reference-header-focus')) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('reference-keyboard-outline')),
          findsOneWidget,
        );
      }
      if (spec.$1.startsWith('support-home-error-retry')) {
        final retry = find.text('Volver a intentar');
        await tester.scrollUntilVisible(
          retry,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(retry), alignment: .3);
        await tester.pumpAndSettle();
        expect(retry.hitTestable(), findsOneWidget);
      }
      if (spec.$1.startsWith('support-home-notification-focus')) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('reference-keyboard-outline')),
          findsOneWidget,
        );
      }
      if (spec.$1.startsWith('support-home-case-focus')) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('reference-keyboard-outline')),
          findsOneWidget,
        );
      }
      if (spec.$1.startsWith('support-home-guardian-')) {
        final dock = spec.$1.contains('-dock-');
        final target = dock
            ? find.byType(GuardianSupportDock)
            : find.byKey(const ValueKey('guardian-support-card-action'));
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
        }
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        final gesture = find
            .descendant(of: target, matching: find.byType(GestureDetector))
            .first;
        Focus.of(tester.element(gesture)).requestFocus();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('reference-keyboard-outline')),
          findsOneWidget,
        );
      }
      if (spec.$1 == 'support-home-large') {
        await tester.scrollUntilVisible(
          find.text('Suscríbete ahora'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Suscríbete ahora')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('chat-detail-focus')) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('chat-detail-link')),
            matching: find.byKey(const ValueKey('reference-keyboard-outline')),
          ),
          findsOneWidget,
        );
      }
      if (spec.$1.startsWith('chat-bubbles')) {
        await tester.scrollUntilVisible(
          find.text('Hola, gracias por interesarte en Luna.'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Hola, gracias por interesarte en Luna.')),
          alignment: .15,
        );
        await tester.pumpAndSettle();
        final metrics = <String, Object>{};
        for (final entry in {
          'composer': find.byType(TextField),
          'send': find.byTooltip('Enviar mensaje'),
        }.entries) {
          expect(entry.value, findsOneWidget);
          final rect = tester.getRect(entry.value);
          metrics[entry.key] = {
            'x': rect.left,
            'y': rect.top,
            'width': rect.width,
            'height': rect.height,
          };
        }
        await tester.runAsync(
          () =>
              File('${out.path}/${spec.$1}-metrics.json')
                  .writeAsString(jsonEncode(metrics)),
        );
      }
      if (spec.$1 == 'adoption-end') {
        await tester.tap(find.byTooltip('Pasar'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('adoption-contact')) {
        await Scrollable.ensureVisible(
          tester.element(find.byTooltip('Contactar')),
          alignment: .25,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Contactar'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('adoption-filters')) {
        await tester.tap(find.byTooltip('Filtros'));
        await tester.pumpAndSettle();
        if (spec.$1 == 'adoption-filters') {
          await tester.tap(
            find.descendant(
              of: find.byType(Dialog),
              matching: find.text('Hembra'),
            ),
          );
          await tester.tap(find.byTooltip('Mediano'));
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1 == 'adoption-drag') {
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Luna')),
        );
        await gesture.moveBy(const Offset(65, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        await tester.runAsync(
          () => saveCapture(key, '${out.path}/${spec.$1}.png'),
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'profile-support') {
        await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'transparency-criteria') {
        final target = find.text('Ver criterios');
        await tester.scrollUntilVisible(target, 300);
        await Scrollable.ensureVisible(tester.element(target), alignment: .25);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'profile-mode-dialog') {
        final target = find.text('Publica un caso de adopción');
        await Scrollable.ensureVisible(tester.element(target), alignment: .25);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(DonorModeDialog), findsOneWidget);
        final body = tester.getRect(
          find.descendant(
            of: find.byType(DonorModeDialog),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        final cancel = tester.getRect(
          find.widgetWithText(TextButton, 'Ahora no'),
        );
        expect(
          cancel.height,
          40,
          reason: 'Source text-link-button normal minimum height',
        );
        await tester.runAsync(
          () => File('${out.path}/profile-mode-metrics.json').writeAsString(
            jsonEncode({
              'body': {
                'x': body.left,
                'y': body.top,
                'width': body.width,
                'height': body.height,
              },
              'cancel': {
                'x': cancel.left,
                'y': cancel.top,
                'width': cancel.width,
                'height': cancel.height,
              },
            }),
          ),
        );
      }
      if (spec.$1.startsWith('rescuer-home-actions') ||
          spec.$1.startsWith('rescuer-home-evidence') ||
          spec.$1.startsWith('rescuer-home-empty')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('Acciones pendientes')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.contains('reference-metric-focus') ||
          spec.$1.contains('reference-transfer-focus')) {
        final metric = find
            .byType(RescuerProfileMetric)
            .at(spec.$1.contains('transfer') ? 2 : 0);
        final outline = find.descendant(
          of: metric,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 10 && outline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(outline, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(metric), alignment: .4);
        await tester.pumpAndSettle();
        final cardRect = tester.getRect(metric);
        final focusRect = tester.getRect(outline);
        expect(focusRect, cardRect.inflate(5));
        expect(cardRect.width, greaterThanOrEqualTo(48));
        expect(cardRect.height, greaterThanOrEqualTo(84));
        expect(focusRect.left, greaterThanOrEqualTo(0));
        expect(
          focusRect.right,
          lessThanOrEqualTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio,
          ),
        );
      }
      if (spec.$1 == 'rescuer-profile-reference-activity-focus') {
        final activity = find.byType(RescuerProfileActivity);
        final button = find.descendant(
          of: activity,
          matching: find.byType(FilledButton),
        );
        final outline = find.descendant(
          of: activity,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 12 && outline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(outline, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(button), alignment: .4);
        await tester.pumpAndSettle();
        expect(tester.getRect(outline), tester.getRect(button).inflate(5));
      }
      if (spec.$1.startsWith('match-threads-photo-search')) {
        final open = find.byTooltip('Buscar conversaciones');
        await tester.scrollUntilVisible(
          open,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(open), alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(open);
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        expect(field, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(field), alignment: .35);
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('match-threads-focus') ||
          spec.$1.startsWith('match-threads-photo-focus')) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('match-thread-list')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final row = find.byType(MatchThreadRow).first;
        if (spec.$1.startsWith('match-threads-photo')) {
          final image = find.descendant(
            of: row,
            matching: find.byType(RawImage),
          );
          expect(image, findsOneWidget);
          expect(tester.widget<RawImage>(image).image, isNotNull);
          expect(tester.getSize(image), const Size(48, 48));
        }
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final outline = find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 40 && outline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(outline, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(row), alignment: .4);
        await tester.pumpAndSettle();
        expect(tester.getRect(outline), tester.getRect(row).inflate(5));
      }
      if (spec.$1.startsWith('rescuer-profile-row-focus')) {
        final row = find.byType(RescuerProfileActivityRow).at(1);
        await Scrollable.ensureVisible(tester.element(row), alignment: .4);
        await tester.pumpAndSettle();
        final outline = find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 16 && outline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(outline, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(row), alignment: .4);
        await tester.pumpAndSettle();
        expect(tester.getRect(outline), tester.getRect(row).inflate(5));
      }
      if (spec.$1 == 'rescuer-profile-home-link-focus') {
        final link = find.byType(RescuerActivityHomeLink);
        final outline = find.descendant(
          of: link,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 12 && outline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(outline, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(link), alignment: .3);
        await tester.pumpAndSettle();
        expect(tester.getSize(link).height, 48);
        expect(tester.getSize(outline).height, 54);
      }
      if (spec.$1 == 'rescuer-profile-reference-focus') {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final outline = find.descendant(
          of: find.byType(RescuerIdentityCard),
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        expect(outline, findsOneWidget);
        expect(tester.getSize(outline).height, closeTo(54, 1));
      }
      if (spec.$1 == 'rescuer-profile-reference' ||
          spec.$1 == 'rescuer-profile-reference-wide') {
        final hero = tester.getRect(find.byType(RescuerIdentityCard));
        expect(hero.top, closeTo(74, 1));
        expect(hero.height, closeTo(147.2, 1));
        final verification = tester.getRect(
          find.byType(RescuerVerificationCard),
        );
        expect(verification.top, closeTo(341.2, 1));
        expect(verification.height, closeTo(80.4, 1));
        final about = tester.getRect(
          find.byKey(const ValueKey('rescuer-profile-about')),
        );
        expect(about.top, closeTo(439.6, 1));
        expect(about.height, closeTo(202.7, 1));
        expect(
          tester.getSize(find.text('Ciudad de México, CDMX')).height,
          closeTo(32, 1),
        );
      }
      if (spec.$1 == 'rescuer-profile') {
        final heading = tester.getRect(find.text('Mi perfil'));
        final hero = tester.getRect(find.byType(RescuerIdentityCard));
        expect(heading.top, closeTo(20, 1));
        expect(heading.height, closeTo(30, 1));
        expect(hero.top, closeTo(74, 1));
        expect(hero.left, closeTo(16, 1));
        expect(hero.width, closeTo(345, 1));
      }
      if (spec.$1.startsWith('owned-case-detail-story')) {
        await Scrollable.ensureVisible(
          tester.element(find.byType(OwnedCaseStory).first),
          alignment: 0,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('owned-case-detail-back-focus')) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('reference-keyboard-outline')),
          findsOneWidget,
        );
      }
      if (spec.$1.startsWith('owned-case-detail-dot-focus')) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final outline = find.byKey(
          const ValueKey('reference-keyboard-outline'),
        );
        expect(outline, findsOneWidget);
        expect(tester.getSize(outline), const Size(18, 18));
        expect(find.text('1 / 2'), findsOneWidget);
      }
      if (spec.$1.startsWith('case-detail-photo-focus')) {
        final dot = find.byKey(const ValueKey('public-case-photo-0'));
        final outline = find.descendant(
          of: find.ancestor(of: dot, matching: find.byType(Semantics)).first,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (
          var attempt = 0;
          attempt < 10 && outline.evaluate().isEmpty;
          attempt++
        ) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(outline, findsOneWidget);
        expect(tester.getSize(outline), const Size(18, 18));
      }
      if (spec.$1.startsWith('case-detail-gallery')) {
        final thumbnail = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Ver foto 3',
        );
        await Scrollable.ensureVisible(
          tester.element(thumbnail),
          alignment: .25,
        );
        await tester.pumpAndSettle();
        await tester.tap(thumbnail);
        await tester.pumpAndSettle();
        final selected = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Foto 3 de 3',
        );
        expect(tester.widget<Semantics>(selected).properties.selected, isTrue);
      }
      if (spec.$1.startsWith('case-detail-story')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('La historia hasta ahora')),
          alignment: .1,
        );
        await tester.pumpAndSettle();
        expect(find.byType(OwnedCaseStory), findsNWidgets(2));
      }
      if (spec.$1.startsWith('owned-case-detail-bottom')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('Consultar expediente')),
          alignment: 1,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('owned-cases-correction')) {
        await tester.scrollUntilVisible(
          find.text('Caso de Milo'),
          200,
          maxScrolls: 20,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Caso de Milo')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
      }
      if ((spec.$1.startsWith('publish-information') ||
          spec.$1.startsWith('publish-review') ||
          spec.$1.startsWith('publish-health'))) {
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        if (large) {
          await Scrollable.ensureVisible(
            tester.element(find.text('Sexo')),
            alignment: 0,
          );
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1.startsWith('publish-review')) {
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.text('Información básica')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('publish-review-social')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('Social')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1 == 'publish-review-social-large') {
        await Scrollable.ensureVisible(
          tester.element(
            find.byKey(
              const ValueKey('publication-review-trait-social_children'),
            ),
          ),
          alignment: 1,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('publish-health')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('Salud')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('case-publication-needs')) {
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Continuar'));
          await tester.pumpAndSettle();
        }
      }
      for (final entry in {
        'medicine': 'Medicina',
        'food': 'Comida',
        'veterinary': 'Veterinario',
      }.entries) {
        if (spec.$1.startsWith('case-publication-needs-${entry.key}')) {
          final card = find.text(entry.value);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          await tester.tap(card);
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1.startsWith('case-publication-review')) {
        for (var i = 0; i < 3; i++) {
          await tester.tap(
            find.text(i == 2 ? 'Continuar a revisión' : 'Continuar'),
          );
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1.contains('-list')) {
        await tester.ensureVisible(find.text('Medicina prescrita'));
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('case-publication-information')) {
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        if (spec.$1 == 'case-publication-information') {
          final fields = <String, Object?>{};
          for (final key in ['pet_name', 'age', 'story']) {
            final target = find.byKey(ValueKey('case-field-$key'));
            final rect = tester.getRect(target);
            fields[key] = {'width': rect.width, 'height': rect.height};
          }
          await tester.runAsync(() async {
            await File('${out.path}/case-information-metrics.json')
                .writeAsString(jsonEncode(fields));
          });
        }
      }
      if (spec.$1.startsWith('expense-review')) {
        for (var i = 0; i < 2; i++) {
          await tester.scrollUntilVisible(
            find.text('Siguiente'),
            300,
            maxScrolls: 100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
        }
        final outer = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        outer.position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Revisa antes de enviar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('expense-review-private')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('Solo para revisión privada')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('expense-submitted')) {
        for (var i = 0; i < 3; i++) {
          final action = find.text(i < 2 ? 'Siguiente' : 'Enviar a revisión');
          await tester.scrollUntilVisible(
            action,
            300,
            maxScrolls: 100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(action);
          await tester.pumpAndSettle();
        }
      }
      if (spec.$1 == 'expense-submitted-footer-large') {
        await tester.scrollUntilVisible(
          find.text('Entendido'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('expense-evidence')) {
        final target = find.text('Documentos y evidencia');
        await tester.scrollUntilVisible(
          target,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(target), alignment: 0);
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('expense-') &&
          !spec.$1.startsWith('expense-evidence') &&
          !spec.$1.startsWith('expense-dialog') &&
          !spec.$1.startsWith('expense-submitted') &&
          !spec.$1.startsWith('expense-review') &&
          !spec.$1.startsWith('expense-record')) {
        final next = find.text('Siguiente');
        await tester.scrollUntilVisible(
          next,
          300,
          maxScrolls: 100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final target = spec.$1.startsWith('expense-private')
            ? find.text('Importe pagado en pesos MXN')
            : find.text('Información para publicación');
        await tester.scrollUntilVisible(
          target,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(target), alignment: .1);
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('verification-form')) {
        final next = find.text('Continuar a verificación');
        await Scrollable.ensureVisible(tester.element(next), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('verification-form-documents')) {
        final documents = find.text('Documentos');
        await tester.scrollUntilVisible(
          documents,
          250,
          maxScrolls: 30,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('verification-form-body')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await Scrollable.ensureVisible(tester.element(documents), alignment: 0);
        await tester.pumpAndSettle();
      }
      if (spec.$1.startsWith('verification-form-progress')) {
        final heading = find.text('Progreso del formulario');
        await tester.scrollUntilVisible(
          heading,
          250,
          maxScrolls: 30,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('verification-form-body')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await Scrollable.ensureVisible(tester.element(heading), alignment: 0);
        await tester.pumpAndSettle();
        expect(find.text('Incompleto').hitTestable(), findsOneWidget);
        expect(
          find.text('1 de 11 requisitos capturados').hitTestable(),
          findsOneWidget,
        );
        final bar = find.byType(LinearProgressIndicator);
        expect(
          tester.widget<LinearProgressIndicator>(bar).value,
          closeTo(1 / 11, .0001),
        );
      }
      if (spec.$1.startsWith('case-publication-header-focus')) {
        final header = find.byKey(const ValueKey('publication-header-back'));
        final focusScope = find.ancestor(
          of: header,
          matching: find.byType(ReferenceFocusOutline),
        );
        final outline = find.descendant(
          of: focusScope,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 12 && outline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(outline, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(header), alignment: .1);
        await tester.pumpAndSettle();
        expect(tester.getRect(outline), tester.getRect(header).inflate(5));
      }
      if (spec.$1 != 'adoption-drag') {
        if (spec.$1 == 'rescuer-settings') {
          final modeCard = find.byType(RescuerDonorModeCard);
          final track = find.byKey(const ValueKey('rescuer-donor-switch'));
          expect(tester.getSize(modeCard).height, closeTo(71, .1));
          expect(tester.getSize(track), const Size(32, 19));
          expect(
            tester.getRect(modeCard).right - tester.getRect(track).right,
            closeTo(17, .1),
          );
          final touch = find.ancestor(
            of: track,
            matching: find.byType(InkWell),
          );
          expect(tester.getSize(touch), const Size(48, 48));
          expect(tester.getCenter(touch), tester.getCenter(track));
          expect(
            tester.getTopLeft(find.text('Estado de verificación')).dy,
            closeTo(88, 1),
          );
          expect(
            tester.getTopLeft(find.byType(SettingsVerificationCard)).dy,
            closeTo(121.4, 1),
          );
          expect(
            tester.getCenter(find.text('Configuración')).dx,
            closeTo(377 / 2, 1),
          );
          expect(
            tester.getCenter(find.byTooltip('Regresar')).dx,
            closeTo(38, 1),
          );
          final social = tester.getRect(find.byType(SettingsDataRow).first);
          final editor = tester.getRect(find.byTooltip('Editar Instagram'));
          expect(social.height, closeTo(70, 1));
          expect(editor.size, const Size(48, 48));
          expect(editor.center.dx, closeTo(social.right - 35, 1));
        }
        if (spec.$1 == 'rescuer-settings-scroll-blur') {
          final headerRect = tester.getRect(find.byType(AppBar));
          await tester.drag(find.byType(ListView).first, const Offset(0, -90));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byType(AppBar)), headerRect);
          expect(
            tester.getTopLeft(find.text('Estado de verificación')).dy,
            lessThan(headerRect.bottom),
          );
        }
        if (spec.$1 == 'rescuer-settings-footer' ||
            spec.$1 == 'rescuer-settings-logout-focus' ||
            spec.$1 == 'rescuer-settings-mode-focus' ||
            spec.$1 == 'rescuer-settings-edit-focus') {
          await tester.scrollUntilVisible(
            find.text('Cerrar sesión'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text('Cerrar sesión')),
            alignment: .7,
          );
          await tester.pumpAndSettle();
          final helpBottom = tester
              .getBottomLeft(find.byType(RescuerNavigationRow))
              .dy;
          final logoutTop = tester.getTopLeft(find.byType(RescuerLogoutRow)).dy;
          expect(logoutTop - helpBottom, closeTo(10, 1));
          if (spec.$1.endsWith('-focus')) {
            final focusTarget = spec.$1 == 'rescuer-settings-mode-focus'
                ? find.byType(RescuerDonorModeCard)
                : spec.$1 == 'rescuer-settings-edit-focus'
                ? find.byTooltip('Editar Instagram')
                : find.byType(RescuerLogoutRow);
            final outline = find.descendant(
              of: focusTarget,
              matching: find.byKey(
                const ValueKey('reference-keyboard-outline'),
              ),
            );
            for (var i = 0; i < 20 && outline.evaluate().isEmpty; i++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pump();
            }
            expect(outline, findsOneWidget);
            if (spec.$1 == 'rescuer-settings-edit-focus') {
              await Scrollable.ensureVisible(
                tester.element(focusTarget),
                alignment: .4,
              );
              await tester.pumpAndSettle();
              expect(tester.getSize(outline), const Size(50, 50));
            }
          }
        }
        if (spec.$1 == 'profile-settings') {
          final rows = find.byType(RescuerNavigationRow);
          for (var i = 0; i < 3; i++) {
            final card = tester.getRect(rows.at(i));
            expect(card.top, closeTo([88.0, 170.0, 264.0][i], .1));
            expect(card.height, closeTo([70.0, 82.0, 82.0][i], .1));
          }
        }
        if (spec.$1.startsWith('rescuer-settings-social-values')) {
          final row = find.byType(SettingsDataRow).first;
          await Scrollable.ensureVisible(tester.element(row), alignment: .35);
          await tester.pumpAndSettle();
          expect(find.text('@maria.rescata'), findsOneWidget);
          if (!spec.$1.endsWith('-large')) {
            expect(tester.getSize(row).height, closeTo(70, .1));
          }
        }
        if (spec.$1.startsWith('rescuer-settings-social-dialog')) {
          final network = spec.$1.endsWith('-facebook')
              ? 'Facebook'
              : 'Instagram';
          final edit = find.byTooltip('Editar $network');
          await Scrollable.ensureVisible(tester.element(edit), alignment: .35);
          await tester.pumpAndSettle();
          await tester.tap(edit);
          await tester.pumpAndSettle();
          expect(find.byType(RescuerSocialDialog), findsOneWidget);
          if (spec.$1 == 'rescuer-settings-social-dialog') {
            final card = tester.getRect(
              find.byKey(const ValueKey('rescuer-social-card')),
            );
            expect(card.top, closeTo(279.90625, .1));
            expect(
              tester.getCenter(find.byTooltip('Cerrar')).dx,
              closeTo(331.71875, .1),
            );
            expect(
              tester.getCenter(find.byTooltip('Cerrar')).dy,
              closeTo(303.90625, .1),
            );
            expect(card.height, closeTo(292.1875, .1));
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('rescuer-social-input')))
                  .height,
              closeTo(44, .1),
            );
            expect(
              tester.getSize(find.byType(FilledButton)).height,
              closeTo(36, .1),
            );
            expect(
              tester.getSize(find.byType(OutlinedButton)).height,
              closeTo(48, .1),
            );
          }
          expect(find.text('Editar $network'), findsOneWidget);
          if (spec.$1.endsWith('-valid')) {
            expect(
              tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
              isNotNull,
            );
          }
          if (spec.$1.contains('social-dialog-keyboard')) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 320);
            await tester.pumpAndSettle();
            final cancel = find.text('Cancelar');
            final scroll = find.descendant(
              of: find.byType(RescuerSocialDialog),
              matching: find.byType(SingleChildScrollView),
            );
            await Scrollable.ensureVisible(
              tester.element(cancel),
              alignment: .8,
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(cancel).bottom,
              lessThanOrEqualTo(tester.view.physicalSize.height - 320),
            );
            expect(scroll, findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }
        if (spec.$1.startsWith('profile-settings-footer')) {
          await tester.scrollUntilVisible(
            find.text('Cerrar sesión'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text('Cerrar sesión')),
            alignment: .7,
          );
          await tester.pumpAndSettle();
        }
        if (spec.$1.startsWith('payment-methods-cards-add')) {
          await tester.scrollUntilVisible(find.text('Agregar tarjeta'), 180);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Agregar tarjeta'));
          await tester.pumpAndSettle();
          expect(find.textContaining('no activa Guardián'), findsOneWidget);
          if (spec.$1.startsWith('payment-methods-cards-added-toast')) {
            await tester.ensureVisible(find.text('Guardar y continuar'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Guardar y continuar'));
            await tester.pumpAndSettle();
            guardian.savedCard = {
              'key': guardian.calls.last['key'],
              'status': 'saved',
              'card_id': 'pm_added',
            };
            guardian.cards = [
              ...guardian.cards,
              const GuardianPaymentCard(
                id: 'pm_added',
                brand: 'visa',
                last4: '9999',
                isDefault: false,
              ),
            ];
            await tester.scrollUntilVisible(
              find.text('Actualizar estado'),
              180,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Actualizar estado'));
            await tester.pumpAndSettle();
            expect(find.text('Tarjeta agregada'), findsOneWidget);
          }
        }
        if (spec.$1.startsWith('payment-methods-cards-independent')) {
          await tester.tap(
            spec.$1.contains('remove')
                ? find.byTooltip('Eliminar tarjeta')
                : find.text('Hacer predeterminada'),
          );
          await tester.pumpAndSettle();
        }
        if (spec.$1.startsWith('payment-methods-cards-default-toast')) {
          await tester.scrollUntilVisible(
            find.text('Hacer predeterminada'),
            180,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Hacer predeterminada'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Autorizar y continuar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Autorizar y continuar'));
          await tester.pumpAndSettle();
          expect(
            find.text('Método predeterminado actualizado'),
            findsOneWidget,
          );
        }
        if (spec.$1.startsWith('payment-methods-cards-remove-confirm')) {
          await tester.ensureVisible(find.byTooltip('Eliminar tarjeta'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Eliminar tarjeta'));
          await tester.pumpAndSettle();
          expect(find.text('¿Eliminar esta tarjeta?'), findsOneWidget);
        }
        if (spec.$1.startsWith('payment-methods-cards-canceled')) {
          final waiting = spec.$1.contains('waiting');
          if (!large) {
            final rows = find.byType(GuardianPaymentCardRow);
            expect(rows, findsNWidgets(2));
            if (!waiting) {
              expect(tester.getTopLeft(rows.at(0)).dy, closeTo(121.390625, .1));
              expect(tester.getTopLeft(rows.at(1)).dy, closeTo(201.390625, .1));
            }
            for (var i = 0; i < 2; i++) {
              expect(
                tester.getSize(rows.at(i)).height,
                70,
                reason: 'Source card-row $i measured 70px at 377px width',
              );
            }
          }
          expect(
            find.text('Hacer predeterminada'),
            waiting ? findsNothing : findsOneWidget,
          );
          expect(
            find.byTooltip('Eliminar tarjeta'),
            waiting ? findsNothing : findsOneWidget,
          );
          expect(
            find.textContaining('Hay un apoyo pendiente de confirmación.'),
            waiting ? findsOneWidget : findsNothing,
          );
          expect(guardian.calls, isEmpty);
          if (spec.$1.contains('footer')) {
            await tester.scrollUntilVisible(
              find.text('Actualizar estado'),
              220,
            );
            await tester.ensureVisible(find.text('Actualizar estado'));
            await tester.pumpAndSettle();
          }
        }
        if (spec.$1.startsWith('my-adoptions')) {
          final target = spec.$1.contains('error')
              ? find.text('Volver a intentar')
              : spec.$1.contains('empty')
              ? find.text(
                  'Aquí encontrarás tus borradores, las publicaciones en revisión y sus respuestas.',
                )
              : find.text('Borrador sin nombre');
          if (spec.$1.contains('content')) {
            await tester.scrollUntilVisible(target, 200);
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            expect(target.hitTestable(), findsOneWidget);
          } else if (!spec.$1.endsWith('-large')) {
            expect(target, findsOneWidget);
          }
        }
        if (spec.$1.startsWith('account-access') ||
            spec.$1.startsWith('connect-account')) {
          expect(container.read(routerProvider).state.uri.path, spec.$2);
        }
        if (spec.$1 == 'public-profile-reference') {
          final identity = tester.widget<PublicProfileIdentity>(
            find.byType(PublicProfileIdentity),
          );
          final targets = <String, Finder>{
            'identity': find.byType(PublicProfileIdentity),
            'avatar': find.byWidget(identity.avatar),
            'name': find.text(identity.name),
            'city': find.text(identity.city),
            'count': find.text('${identity.caseCount} casos publicados'),
            'bio': find.text(identity.bio),
            'socialHeading': find.text('Redes sociales'),
            'instagram': find.widgetWithText(OutlinedButton, 'Instagram'),
            'facebook': find.widgetWithText(OutlinedButton, 'Facebook'),
            'tabs': find.byType(PublicProfileTabs),
            'activityTab': find.widgetWithText(TextButton, 'Actividad'),
          };
          final metrics = <String, Object>{};
          for (final entry in targets.entries) {
            expect(entry.value, findsOneWidget);
            final rect = tester.getRect(entry.value);
            metrics[entry.key] = {
              'x': rect.left,
              'y': rect.top,
              'width': rect.width,
              'height': rect.height,
            };
          }
          await tester.runAsync(
            () =>
                File('${out.path}/${spec.$1}-metrics.json')
                    .writeAsString(jsonEncode(metrics)),
          );
        }
        if (spec.$1.startsWith('public-profile-state')) {
          expect(container.read(routerProvider).state.uri.path, spec.$2);
          final fixture = community as PublicProfileStateCaptureCommunity;
          expect(fixture.requestedProfiles, ['owner']);
          expect(find.byType(PublicProfileIdentity), findsNothing);
          if (fixture.state == 'loading') {
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
          } else if (fixture.state == 'error') {
            expect(
              find.text('Volver a intentar').hitTestable(),
              findsOneWidget,
            );
          } else {
            expect(
              find.text('Este perfil público no está disponible.'),
              findsOneWidget,
            );
          }
        }
        if (spec.$1 == 'connect-account-ready') {
          expect(find.text(r'$4,314.00 MXN'), findsOneWidget);
          expect(find.text(r'$980.00 MXN'), findsOneWidget);
        }
        if (spec.$1.startsWith('connect-account') &&
            spec.$1.contains('content')) {
          final target = find.text('Completar datos en Stripe');
          await tester.scrollUntilVisible(target, 250);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          if (spec.$1.contains('ready')) {
            expect(find.text(r'$4,314.00 MXN'), findsOneWidget);
            expect(find.text(r'$980.00 MXN'), findsOneWidget);
          }
        }
        if (spec.$1.startsWith('account-access') &&
            spec.$1.contains('content')) {
          final label = spec.$1.contains('options')
              ? 'Configurar pagos con Stripe'
              : spec.$1.contains('consent')
              ? 'Privacidad y eliminación de cuenta'
              : 'Eliminar mi cuenta';
          final target = find.text(label);
          await tester.scrollUntilVisible(target, 200);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
        }
        TestGesture? helpHold;
        if (spec.$1.startsWith('help-center-topic-held')) {
          final topic = find.widgetWithText(
            OutlinedButton,
            'Cómo funcionan los apoyos',
          );
          await tester.ensureVisible(topic);
          await tester.pumpAndSettle();
          expect(topic.hitTestable(), findsOneWidget);
          helpHold = await tester.startGesture(tester.getCenter(topic));
          await tester.pump(const Duration(milliseconds: 150));
          await tester.pump();
          final ink = tester.widget<InkWell>(
            find.descendant(of: topic, matching: find.byType(InkWell)).first,
          );
          expect(ink.statesController!.value, contains(WidgetState.pressed));
        }
        await tester.runAsync(
          () => saveCapture(key, '${out.path}/${spec.$1}.png'),
        );
        if (spec.$1.startsWith('public-profile-state-loading') ||
            spec.$1.startsWith('public-profile-state-error')) {
          final fixture = community as PublicProfileStateCaptureCommunity;
          final loading = fixture.state == 'loading';
          if (loading) {
            await fixture.finishLoading();
          } else {
            fixture.state = 'ready';
            await tester.tap(find.text('Volver a intentar'));
          }
          await tester.pumpAndSettle();
          expect(find.byType(PublicProfileIdentity), findsOneWidget);
          expect(find.text('María R.'), findsOneWidget);
          expect(
            fixture.requestedProfiles,
            loading ? ['owner'] : ['owner', 'owner'],
          );
          expect(container.read(routerProvider).state.uri.path, spec.$2);
          actualPublicRecovery++;
        }
        if (spec.$1.startsWith('private-file')) {
          expect(find.byTooltip('Regresar').hitTestable(), findsOneWidget);
          await tester.tap(find.byTooltip('Regresar'));
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, spec.$2);
          expect(privateFile.saveCalls, 0);
          actualPrivateFileNavigation++;
        }
        if (spec.$1.startsWith('connect-account') &&
            !spec.$1.contains('content')) {
          expect(find.byTooltip('Regresar').hitTestable(), findsOneWidget);
          await tester.tap(find.byTooltip('Regresar'));
          await tester.pumpAndSettle();
          expect(
            container.read(routerProvider).state.uri.path,
            '/settings/account',
          );
          expect(repo.profile.mode, 'rescuer');
          actualConnectNavigation++;
        }
        if (spec.$1 == 'account-access-options' ||
            spec.$1 == 'account-access-options-large') {
          final privacy = find.text('Privacidad y eliminación');
          await tester.scrollUntilVisible(privacy, 200);
          await tester.ensureVisible(privacy);
          await tester.pumpAndSettle();
          expect(privacy.hitTestable(), findsOneWidget);
          await tester.tap(privacy);
          await tester.pumpAndSettle();
          expect(
            container.read(routerProvider).state.uri.path,
            '/account-privacy',
          );
          await tester.tap(find.byTooltip('Regresar'));
          await tester.pumpAndSettle();
          expect(
            container.read(routerProvider).state.uri.path,
            '/settings/account',
          );
          expect(find.byTooltip('Regresar').hitTestable(), findsOneWidget);
          await tester.tap(find.byTooltip('Regresar'));
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, '/profile');
          expect(repo.profile.mode, 'rescuer');
          actualAccountNavigation++;
        }
        if (spec.$1 == 'my-adoptions' || spec.$1 == 'my-adoptions-large') {
          final back = find.byTooltip('Regresar');
          expect(back.hitTestable(), findsOneWidget);
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, '/profile');
        }
        if (helpHold != null) {
          await helpHold.cancel();
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, '/help');
          final topic = find.widgetWithText(
            OutlinedButton,
            'Cómo funcionan los apoyos',
          );
          expect(
            tester
                .widget<OutlinedButton>(topic)
                .style!
                .backgroundColor!
                .resolve({}),
            Colors.white,
          );
          await tester.tap(topic);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<OutlinedButton>(topic)
                .style!
                .backgroundColor!
                .resolve({}),
            const Color(0xfffff8e0),
          );
        }
        if (spec.$1.contains('social-dialog-keyboard')) {
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(find.byType(RescuerSocialDialog), findsNothing);
          expect(
            (container.read(
              rescuerProfileRepositoryProvider,
            ) as SettingsSocialCaptureProfile).saves,
            0,
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      if (spec.$1.startsWith('contribution-waiting')) {
        waitingPayment.response.completeError(Exception('fixture complete'));
        await tester.pump();
      }
      tester.view.resetViewInsets();
      container.dispose();
      await repo.changes.close();
    }
    expect(
      actualAccountNavigation,
      expectedAccountNavigation,
      reason:
          'Every selected account navigation fixture must execute its checks',
    );
    expect(
      actualConnectNavigation,
      expectedConnectNavigation,
      reason:
          'Every selected Connect navigation fixture must execute its checks',
    );
    expect(
      actualPrivateFileNavigation,
      expectedPrivateFileNavigation,
      reason: 'Every selected private file fixture must return to its request',
    );
    expect(
      actualPublicRecovery,
      expectedPublicRecovery,
      reason: 'Every selected loading or failed public profile must recover',
    );
    expect(
      captureCount,
      greaterThan(0),
      reason: 'CAPTURE_FILTER must select at least one screen',
    );
    debugNetworkImageHttpClientProvider = null;
    debugDisableShadows = true;
  });
}

class SettingsSocialCaptureProfile extends FakeRescuerProfile {
  @override
  String? get userId => 'one';
}
