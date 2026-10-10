import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

import '../test/owned_cases_screen_test.dart'
    show OwnedCasesRepository, ArchiveCommunity;

/// Synthetic capture-only data matching Source bccd040. Never imported by app.
/// Signed URL fixtures resolve by basename against the pinned Source assets.
class BccdCasesCaptureRepository extends OwnedCasesRepository {
  BccdCasesCaptureRepository({this.state = 'adoptions'}) : super(_seed(state));
  final String state;
  String get initialProgram =>
      state.startsWith('support') ? 'support' : 'adoption';
  String? get initialStatus => state == 'corrections' ? 'corrections' : null;
  bool get startInArchive => state == 'archive' || state == 'support-archive';

  @override
  Future<String> fileUrl(String path) async => bccdCasePhotoUrl(path);

  @override
  Future<DataPage<RescueRecord>> completeCaseCatalog(String id) async {
    catalogReads++;
    final item = items.firstWhere((item) => item['id'] == id);
    final caseRecord = RescueRecord(Json.from(item['record'] as Map));
    final entries = _needs[id] ?? const <Json>[];
    return DataPage([
      caseRecord,
      for (final entry in entries)
        RescueRecord({
          'id': entry['id'],
          'owner_id': 'one',
          'parent_id': id,
          'kind': 'expense',
          'status': 'approved',
          'version': 3,
          'target_cents': (entry['target'] as int) * 100,
          'funded_cents': (entry['funded'] as int) * 100,
          'transferred_cents': 0,
          'urgent': entry['urgent'] == true,
          'public_data': {
            'title': entry['title'],
            'category': entry['category'],
            'photos': <String>[],
          },
        }),
    ], entries.length + 1);
  }
}

class BccdCasesCaptureCommunity extends ArchiveCommunity {
  BccdCasesCaptureCommunity(super.rescue);
  @override
  Future<int> unreadNotificationCount() async => 2;
  @override
  Future<String> photoUrl(String path) async => bccdCasePhotoUrl(path);
}

String bccdCasePhotoUrl(String path) =>
    'https://fixture.test/bccd-cases/${path.split('/').last}';

const bccdCaseCaptureAssetNames = <String>[
  'luna-card.png',
  'milo-card.png',
  'nina-card.png',
  'publish-sample-pet.jpg',
  'rocky.png',
  'toby.png',
];

List<Json> _seed(String state) {
  if (state == 'empty') return [];
  return [
    _item('max-rejected', 'Max', 'rocky.png', status: 'changes_requested'),
    _item('mia-draft', 'Mía', 'nina-card.png', status: 'draft'),
    _item('sol-review', 'Sol', 'publish-sample-pet.jpg', status: 'submitted'),
    _item('luna', 'Luna', 'luna-card.png', days: 23, views: 100, threads: 2),
    _item('rocky', 'Rocky', 'rocky.png', days: 12, views: 56, threads: 1),
    _item(
      'bruno-adopt-cerrado',
      'Bruno',
      'toby.png',
      status: 'archived',
      days: 45,
      views: 88,
      closeReason: 'other',
    ),
    _item(
      'cielo',
      'Cielo',
      'nina-card.png',
      status: 'adopted',
      days: 120,
      views: 210,
      closeReason: 'adopted',
    ),
    _item(
      'toby-case',
      'Toby',
      'toby.png',
      support: true,
      status: 'changes_requested',
    ),
    _item('bluh', 'Bluh', 'milo-card.png', support: true, status: 'draft'),
    _item(
      'nube-review',
      'Nube',
      'publish-sample-pet.jpg',
      support: true,
      status: 'submitted',
    ),
    _item(
      'nina',
      'Nina',
      'nina-card.png',
      support: true,
      status: 'approved',
      days: 9,
      views: 34,
    ),
    _item(
      'milo',
      'Milo',
      'milo-card.png',
      support: true,
      status: 'approved',
      days: 41,
      views: 68,
    ),
    _item(
      'copo-apoyo-arch-final',
      'Copo',
      'milo-card.png',
      support: true,
      status: 'closed',
      days: 62,
      views: 142,
    ),
    _item(
      'flecha-apoyo-arch-cerrado',
      'Flecha',
      'luna-card.png',
      support: true,
      status: 'closed',
      days: 28,
      views: 51,
    ),
  ];
}

Json _item(
  String id,
  String name,
  String image, {
  bool support = false,
  String status = 'published',
  int? days,
  int views = 0,
  int threads = 0,
  String? closeReason,
}) {
  final needs = _needs[id] ?? const <Json>[];
  final target = needs.fold<int>(
    0,
    (sum, need) => sum + (need['target'] as int) * 100,
  );
  final funded = needs.fold<int>(
    0,
    (sum, need) => sum + (need['funded'] as int) * 100,
  );
  final path = 'one/bccd-cases/$image';
  final date = days == null
      ? null
      : DateTime.now()
            .toUtc()
            .subtract(Duration(days: days, minutes: 1))
            .toIso8601String();
  final record = <String, dynamic>{
    'id': id,
    'owner_id': 'one',
    'status': status,
    'version': 3,
    if (support) 'kind': 'case',
    'pet_name': name,
    'species': 'dog',
    'sex': 'female',
    'size': 'medium',
    'age_band': 'adult',
    'age_months': 24,
    'city': 'Monterrey',
    'region': 'Nuevo León',
    'story': 'Datos sintéticos para comparación Source bccd040.',
    'photos': [path],
    'coexistence': ['children'],
    'personality': ['happy'],
    'public_data': {
      'pet_name': name,
      'photos': [path],
      'city': 'Monterrey',
      'state': 'Nuevo León',
    },
    'private_data': <String, dynamic>{},
    'files': <Json>[],
    'target_cents': target,
    'funded_cents': funded,
    'transferred_cents': 0,
    'approved_at': date,
    'published_at': date,
  };
  return {
    'id': id,
    'program': support ? 'support' : 'adoption',
    'status': status,
    'version': 3,
    'pet_name': name,
    'cover_path': path,
    'published_at': date,
    'approved_at': date,
    'updated_at': date,
    'unique_view_count': views,
    'tracking_started_at': date,
    'thread_count': threads,
    'target_cents': target,
    'funded_cents': funded,
    'transferred_cents': 0,
    'need_types': [
      for (final category in const ['veterinary', 'medicine', 'food', 'other'])
        if (needs.any((need) => need['category'] == category)) category,
    ],
    'record': record,
    'close_reason': ?closeReason,
    if (id == 'bruno-adopt-cerrado')
      'close_reason_description': 'La familia canceló el proceso de adopción.',
    if (id == 'cielo') 'adopted_with_dopmi_support': true,
  };
}

const _needs = <String, List<Json>>{
  'milo': [
    {
      'id': 'milo-med',
      'title': 'Spray para heridas',
      'category': 'medicine',
      'target': 12,
      'funded': 8,
      'urgent': true,
    },
    {
      'id': 'milo-food',
      'title': 'Pack comida húmeda x12',
      'category': 'food',
      'target': 22,
      'funded': 22,
    },
    {
      'id': 'milo-vet',
      'title': 'Tratamiento de pata',
      'category': 'veterinary',
      'target': 80,
      'funded': 45,
    },
  ],
  'nina': [
    {
      'id': 'nina-vet',
      'title': 'Estudios de cadera',
      'category': 'veterinary',
      'target': 95,
      'funded': 95,
      'urgent': true,
    },
  ],
  'nube-review': [
    {
      'id': 'nube-med',
      'title': 'Medicina',
      'category': 'medicine',
      'target': 320,
      'funded': 0,
    },
  ],
  'toby-case': [
    {
      'id': 'toby-vet',
      'title': 'Cirugía de emergencia',
      'category': 'veterinary',
      'target': 240,
      'funded': 0,
      'urgent': true,
    },
  ],
  'copo-apoyo-arch-final': [
    {
      'id': 'copo-vet',
      'title': 'Esterilización',
      'category': 'veterinary',
      'target': 60,
      'funded': 60,
    },
    {
      'id': 'copo-food',
      'title': 'Alimento recuperación',
      'category': 'food',
      'target': 35,
      'funded': 35,
    },
  ],
  'flecha-apoyo-arch-cerrado': [
    {
      'id': 'flecha-vet',
      'title': 'Consulta y estudios',
      'category': 'veterinary',
      'target': 70,
      'funded': 30,
    },
    {
      'id': 'flecha-med',
      'title': 'Antibiótico',
      'category': 'medicine',
      'target': 25,
      'funded': 10,
    },
  ],
};
