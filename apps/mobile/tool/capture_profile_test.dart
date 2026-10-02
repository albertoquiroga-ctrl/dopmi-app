import 'package:dopmi_mobile/features/profile/rescuer_verification_card.dart';
import 'package:dopmi_mobile/features/profile/rescuer_settings_details.dart';
import 'package:dopmi_mobile/features/profile/rescuer_settings_verification.dart';
import 'package:dopmi_mobile/features/profile/rescuer_logout_row.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_access.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';

import '../test/rescuer_profile_test.dart' show FakeRescuerProfile;

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_photo_client.dart';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
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

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';
import '../test/rescue_test.dart' show FakeRescue, FakeCaseUpdates;
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
import 'capture_design_test.dart' show saveCapture;

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
          'expense_id': 'fixture-expense-$i',
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

class DetailCaptureCommunity extends FakeCommunity {
  @override
  Future<String> photoUrl(String path) async => 'https://fixture.invalid/$path';
  @override
  Future<Json?> publicProfile(String id) async => {'verified': true};
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
      ('rescuer-home-unverified', '/rescuer'),
      ('rescuer-home-unverified-large', '/rescuer'),
      ('rescuer-home-review', '/rescuer'),
      ('rescuer-home-review-large', '/rescuer'),
      ('rescuer-home-empty', '/rescuer'),
      ('rescuer-home-empty-large', '/rescuer'),
      ('rescuer-home-actions', '/rescuer'),
      ('rescuer-home-actions-large', '/rescuer'),
      ('owned-case-detail', '/rescue/case-one'),
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
      ('support-home-large', '/rescue-cases'),
      ('case-detail', '/rescue-cases/case-one'),
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
      ('payment-history', '/payments'),
      ('payment-history-large', '/payments'),
      ('payment-history-empty', '/payments'),
      ('contribution-amount', '/contribute/Cirugía?case=case-one'),
      ('contribution-amount-large', '/contribute/Cirugía?case=case-one'),
      ('case-detail-large', '/rescue-cases/case-one'),
      ('case-detail-expenses', '/rescue-cases/case-one'),
      ('case-detail-amount', '/rescue-cases/case-one'),
      ('case-detail-amount-large', '/rescue-cases/case-one'),
      ('case-detail-expenses-large', '/rescue-cases/case-one'),
      ('match-home', '/messages'),
      ('match-home-large', '/messages'),
      ('adoption-support', '/adoptions'),
      ('adoption-support-large', '/adoptions'),
      ('rescuer-profile', '/profile'),
      ('rescuer-profile-reference', '/profile'),
      ('rescuer-profile-reference-wide', '/profile'),
      ('rescuer-profile-reference-focus', '/profile'),
      ('rescuer-profile-reference-large', '/profile'),
      ('rescuer-settings', '/settings'),
      ('rescuer-settings-footer', '/settings'),
      ('rescuer-settings-logout-focus', '/settings'),
      ('rescuer-settings-mode-focus', '/settings'),
      ('rescuer-settings-edit-focus', '/settings'),
      ('rescuer-settings-large', '/settings'),
      ('rescuer-profile-large', '/profile'),
      ('profile-overview', '/profile'),
      ('profile-overview-active', '/profile'),
      ('profile-overview-large', '/profile'),
      ('profile-mode-dialog', '/profile'),
      ('profile-settings', '/settings'),
      ('profile-support', '/profile'),
      ('about', '/about'),
      ('about-large', '/about'),
      ('transparency', '/transparency'),
      ('transparency-criteria', '/transparency'),
      ('publish-choice', '/publish'),
      ('publish-choice-large', '/publish'),
      ('publish-photos', '/my-adoptions/new'),
      ('publish-photos-large', '/my-adoptions/new'),
      ('publish-photo-grid', '/my-adoptions/post'),
      ('publish-photo-grid-large', '/my-adoptions/post'),
      ('publish-information', '/my-adoptions/post'),
      ('publish-information-large', '/my-adoptions/post'),
      ('publish-review', '/my-adoptions/post'),
      ('publish-review-large', '/my-adoptions/post'),
      ('publish-health', '/my-adoptions/post'),
      ('publish-health-large', '/my-adoptions/post'),
      ('expense-submitted', '/rescue/expense-one'),
      ('expense-submitted-large', '/rescue/expense-one'),
      ('expense-submitted-footer-large', '/rescue/expense-one'),
      ('case-publication', '/rescue/new?kind=case'),
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
      ('verification-approved', '/rescue/verification-id'),
      ('verification-approved-large', '/rescue/verification-id'),
      ('verification-review', '/rescue/verification-id'),
      ('verification-review-large', '/rescue/verification-id'),
    ]) {
      const captureFilter = String.fromEnvironment('CAPTURE_FILTER');
      if (captureFilter.isNotEmpty && !spec.$1.startsWith(captureFilter)) {
        continue;
      }
      captureCount++;
      // Synthetic preferences belong only to this flutter_test capturer.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final repo = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      await repo.saveProfile(name: 'Ana', phone: '', city: 'Monterrey, NL');
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
          : spec.$1 == 'rescuer-profile-reference-wide'
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
              spec.$1.startsWith('guardian-billing'))
          ? HistoryCaptureGuardian(
              empty:
                  spec.$1.endsWith('-empty') ||
                  spec.$1.contains('inactive') ||
                  spec.$1.contains('enrollment'),
            )
          : FakeGuardian();
      final community = spec.$1.startsWith('rescuer-profile-reference')
          ? RescuerReferenceCaptureCommunity()
          : spec.$1.startsWith('impact-feed')
          ? ImpactCaptureCommunity(spec.$1.contains('empty'))
          : (spec.$1.startsWith('adoption-detail') ||
                spec.$1 == 'adoption-end' ||
                spec.$1.startsWith('adoption-support') ||
                (spec.$1.startsWith('publish-photo-grid') ||
                    (spec.$1.startsWith('publish-information') ||
                        spec.$1.startsWith('publish-review') ||
                        spec.$1.startsWith('publish-health'))))
          ? DetailCaptureCommunity()
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
      if ((spec.$1.startsWith('adoption-detail') ||
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
          spec.$1.startsWith('owned-cases') ||
          spec.$1.startsWith('rescuer-home') ||
          spec.$1.startsWith('rescuer-profile') ||
          spec.$1.startsWith('rescuer-settings') ||
          spec.$1.startsWith('case-publication') ||
          spec.$1.startsWith('publish-') ||
          spec.$1.startsWith('verification-') ||
          spec.$1 == 'chat-bubbles-rescuer') {
        await repo.setExperience('rescuer');
      }
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          communityRepositoryProvider.overrideWithValue(community),
          if (spec.$1.startsWith('rescuer-profile') ||
              spec.$1.startsWith('rescuer-settings'))
            rescueRepositoryProvider.overrideWithValue(
              spec.$1.startsWith('rescuer-profile-reference')
                  ? RescuerReferenceCaptureRescue()
                  : FakeRescue(),
            ),
          if (spec.$1.startsWith('rescuer-settings'))
            rescuerProfileRepositoryProvider.overrideWithValue(
              FakeRescuerProfile()..value['owner_id'] = 'one',
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
              spec.$1.contains('empty')
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
          if (spec.$1.startsWith('contribution'))
            paymentRepositoryProvider.overrideWithValue(
              spec.$1.startsWith('contribution-result')
                  ? ResultCapturePayments(
                      spec.$1
                          .replaceFirst('contribution-result-', '')
                          .replaceFirst('-large', ''),
                    )
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
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
          ],
          if (spec.$1.startsWith('impact-feed'))
            rescueRepositoryProvider.overrideWithValue(SupportCaptureRescue()),
          if (spec.$1.startsWith('support-home'))
            rescueRepositoryProvider.overrideWithValue(SupportCaptureRescue()),
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
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
      }
      if (spec.$1.startsWith('rescuer-home-actions') ||
          spec.$1.startsWith('rescuer-home-empty')) {
        await Scrollable.ensureVisible(
          tester.element(find.text('Acciones pendientes')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
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
      if (spec.$1 != 'adoption-drag') {
        if (spec.$1 == 'rescuer-settings') {
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
        await tester.runAsync(
          () => saveCapture(key, '${out.path}/${spec.$1}.png'),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await repo.changes.close();
    }
    expect(
      captureCount,
      greaterThan(0),
      reason: 'CAPTURE_FILTER must select at least one screen',
    );
    debugNetworkImageHttpClientProvider = null;
    debugDisableShadows = true;
  });
}
