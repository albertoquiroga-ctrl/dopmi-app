import 'package:dopmi_mobile/features/adoption/community_repository.dart';

import '../test/rescuer_home_screen_test.dart' show HomeRescue, homeFixture;

/// Source bccd's ten Home captures, scoped to the capture harness.
/// No Source payment/donor simulations are imported into production UI.
class BccdHomeCaptureRescue extends HomeRescue {
  BccdHomeCaptureRescue({
    this.state = 'adoption',
    bool paymentsAcknowledged = false,
  }) {
    assert(
      const [
        'adoption',
        'evidence',
        'unverified',
        'review',
        'empty',
      ].contains(state),
    );
    final empty = state == 'empty' || state == 'unverified';
    home = {
      ...homeFixture(
        verification: switch (state) {
          'unverified' => 'not_started',
          'review' => 'submitted',
          _ => 'approved',
        },
        views: empty ? 0 : 100,
      ),
      'adoption_counts': _counts(empty),
      'support_counts': _counts(empty),
      'adoption_metrics': {
        'unique_viewers': empty ? 0 : 100,
        'pets_saved': empty ? 0 : 1,
        'tracking_started_at': '2026-10-05T00:00:00Z',
      },
      'unanswered_conversations': empty ? 0 : 1,
      'pending_evidence': empty ? <Json>[] : _evidence,
      'recent_activity': empty ? <Json>[] : _payments(),
      'payments_unseen_count': empty || paymentsAcknowledged ? 0 : 2,
      'payments_cursor': empty ? null : 'bccd-home-presented-cursor',
    };
    pages = {
      1: DataPage(
        empty ? <Json>[] : _payments(),
        empty ? 0 : 4,
        cursor: empty ? null : 'bccd-page-one-presented-cursor',
      ),
    };
  }

  BccdHomeCaptureRescue.adoption({bool paymentsAcknowledged = false})
    : this(state: 'adoption', paymentsAcknowledged: paymentsAcknowledged);
  BccdHomeCaptureRescue.evidence() : this(state: 'evidence');
  BccdHomeCaptureRescue.unverified() : this(state: 'unverified');
  BccdHomeCaptureRescue.review()
    : this(state: 'review', paymentsAcknowledged: true);
  BccdHomeCaptureRescue.empty() : this(state: 'empty');

  final String state;

  static Json _counts(bool empty) => {
    'active': empty ? 0 : 2,
    'review': empty ? 0 : 1,
    'draft': empty ? 0 : 1,
    'corrections': empty ? 0 : 1,
  };

  static const _evidence = <Json>[
    {
      'expense_id': 'bccd-rocky-vet',
      'case_id': 'bccd-rocky',
      'pet_name': 'Rocky',
      'expense_title': 'Veterinario',
      'status': 'draft',
      'urgent': true,
      'progress_percent': 30,
      'editable': true,
    },
    {
      'expense_id': 'bccd-milo-med',
      'case_id': 'bccd-milo',
      'pet_name': 'Milo',
      'expense_title': 'Medicina',
      'status': 'draft',
      'urgent': false,
      'progress_percent': 55,
      'editable': true,
    },
  ];

  static List<Json> _payments() {
    final now = DateTime.now().toUtc();
    return [
      _payment(
        'bccd-nina-med',
        'Nina',
        'Medicina',
        1500,
        now.subtract(const Duration(days: 3)),
        'nina-card.png',
      ),
      _payment(
        'bccd-nina-week',
        'Nina',
        '',
        9500,
        now.subtract(const Duration(days: 1)),
        'nina-card.png',
      ),
      _payment(
        'bccd-milo-vet',
        'Milo',
        'Veterinario',
        2500,
        now.subtract(const Duration(days: 2)),
        'milo-card.png',
      ),
      _payment(
        'bccd-milo-week',
        'Milo',
        '',
        7500,
        now.subtract(const Duration(days: 5)),
        'milo-card.png',
      ),
    ];
  }

  static Json _payment(
    String id,
    String name,
    String expense,
    int cents,
    DateTime occurred,
    String photo,
  ) => {
    'id': id,
    'case_id': 'bccd-${name.toLowerCase()}',
    'expense_id': '$id-expense',
    'pet_name': name,
    'expense_title': expense,
    'net_cents': cents,
    'photo': 'one/bccd-home/$photo',
    'occurred_at': occurred.toIso8601String(),
    'source': 'direct',
    'transfer_status': 'pending',
  };

  @override
  Future<String> fileUrl(String path) async =>
      'https://fixture.invalid/bccd-home/${Uri.encodeComponent(path.split('/').last)}';
}

/// Load these two Source assets into the capture-only HTTP photo client.
const bccdHomePhotoAssets = ['nina-card.png', 'milo-card.png'];
