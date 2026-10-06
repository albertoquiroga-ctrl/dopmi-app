import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/media/media_store.dart';

import '../adoption/community_repository.dart';

const rescueBucket = 'dopmi-rescue-evidence';
const rescueStatuses = {
  'draft': 'Borrador',
  'submitted': 'En revisión',
  'changes_requested': 'Necesita correcciones',
  'approved': 'Aprobado',
  'rejected': 'No aprobado',
  'closed': 'Caso cerrado',
};
const rescueKinds = {
  'verification': 'Verificación',
  'case': 'Caso',
  'expense': 'Gasto',
};
const evidenceRoles = {
  'identity': 'Identificación oficial',
  'address': 'Comprobante de domicilio',
  'receipt': 'Comprobante del gasto',
  'proof': 'Evidencia del gasto realizado',
  'public': 'Foto para publicación',
};

class RescueRecord {
  RescueRecord(this.data);
  final Json data;
  String get id => data['id'] as String;
  String get kind => data['kind'] as String;
  String get status => data['status'] as String;
  int get version => data['version'] as int? ?? 0;
  String? get parent => data['parent_id'] as String?;
  bool get saved => data['saved'] == true;
  int get targetCents => data['target_cents'] as int? ?? 0;
  int get fundedCents => data['funded_cents'] as int? ?? 0;
  int get transferredCents => data['transferred_cents'] as int? ?? 0;
  Json get publicData => Json.from(data['public_data'] as Map? ?? {});
  Json get privateData => Json.from(data['private_data'] as Map? ?? {});
  List<Json> get files =>
      (data['files'] as List? ?? []).map((e) => Json.from(e as Map)).toList();
  String get title {
    for (final key in ['public_name', 'pet_name', 'title']) {
      final value = publicData[key] as String?;
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return kind == 'case' ? 'Sin nombre' : 'Sin título';
  }

  bool get editable =>
      ['draft', 'changes_requested', 'rejected'].contains(status);
}

final rescueRepositoryProvider = Provider<RescueRepository>(
  (ref) => RescueRepository(Supabase.instance.client),
);

class RescueRepository {
  RescueRepository(this.client);
  final SupabaseClient client;
  Future<Json> dashboard() async =>
      Json.from(await client.rpc('dopmi_rescuer_dashboard'));
  Future<Json> dashboardV2() async =>
      Json.from(await client.rpc('dopmi_rescuer_dashboard_v2'));
  Future<Json> ownedCases(
    int page, {
    String program = 'adoption',
    List<String> statuses = const [],
    bool archived = false,
  }) async => Json.from(
    await client.rpc(
      'dopmi_owned_cases',
      params: {
        'page_number': page,
        'program': program,
        'statuses': statuses,
        'archived': archived,
      },
    ),
  );
  Future<DataPage<Json>> receivedActivity(int page) async {
    final result = Json.from(
      await client.rpc('dopmi_rescuer_activity', params: {'page_number': page}),
    );
    return DataPage(
      (result['items'] as List).map((item) => Json.from(item)).toList(),
      result['total'] as int,
      cursor: result['presented_cursor'] as String?,
    );
  }

  Future<void> acknowledgePayments(String cursor) async {
    await client.rpc(
      'dopmi_acknowledge_rescuer_payments',
      params: {'presented_cursor': cursor},
    );
  }

  Future<void> closeAdoption(
    String id,
    int version,
    String reason, {
    bool? dopmiSupport,
    String description = '',
  }) async {
    await client.rpc(
      'dopmi_close_adoption',
      params: {
        'post_id': id,
        'expected_version': version,
        'reason': reason,
        'dopmi_support': dopmiSupport,
        'description': description,
      },
    );
  }

  Future<void> archiveSupport(String id, int version) async {
    await client.rpc(
      'dopmi_archive_support_case',
      params: {'record_id': id, 'expected_version': version},
    );
  }

  Future<Adoption> reactivateAdoption(Adoption post) async {
    return SupabaseCommunityRepository(client)
        .save(Json.from(post.data), id: post.id, version: post.version);
  }

  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async {
    if (kind == 'case' && parent == null) {
      final result = Json.from(
        await client.rpc('dopmi_my_cases', params: {'page_number': page}),
      );
      return DataPage(
        (result['items'] as List)
            .map((item) => RescueRecord(Json.from(item as Map)))
            .toList(),
        result['total'] as int,
      );
    }
    var query = client
        .from('dopmi_rescue_records')
        .select()
        .eq('owner_id', client.auth.currentUser!.id)
        .eq('kind', kind);
    if (parent != null) query = query.eq('parent_id', parent);
    final result = await query
        .order('updated_at', ascending: false)
        .order('id')
        .range((page - 1) * 20, page * 20 - 1)
        .count(CountOption.exact);
    return DataPage(result.data.map(RescueRecord.new).toList(), result.count);
  }

  Future<Json> detail(String id) async => Json.from(
    await client.rpc('dopmi_rescue_detail', params: {'record_id': id}),
  );
  Future<void> removeDraftExpense(String id, int version) async {
    await client.rpc(
      'dopmi_remove_draft_expense',
      params: {'record_id': id, 'expected_version': version},
    );
  }

  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async => RescueRecord(
    Json.from(
      await client.rpc(
        'dopmi_save_rescue',
        params: {
          'record_kind': kind,
          'public_fields': publicData,
          'private_fields': privateData,
          'attachments': files,
          'target_id': record?.id,
          'expected_version': record?.version,
          'case_id': record?.parent ?? parent,
        },
      ),
    ),
  );
  Future<RescueRecord> transition(RescueRecord record, String action) async =>
      RescueRecord(
        Json.from(
          await client.rpc(
            'dopmi_transition_rescue',
            params: {
              'record_id': record.id,
              'expected_version': record.version,
              'action': action,
            },
          ),
        ),
      );
  Future<RescueRecord> closeSupportCase(RescueRecord record) async =>
      RescueRecord(
        Json.from(
          await client.rpc(
            'dopmi_close_support_case',
            params: {
              'record_id': record.id,
              'expected_version': record.version,
            },
          ),
        ),
      );
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    final result = await client.rpc(
      'dopmi_rescue_public',
      params: {'case_id': caseId, 'page_number': page},
    );
    return DataPage(
      (result['items'] as List).map((e) => RescueRecord(Json.from(e))).toList(),
      result['total'] as int,
    );
  }

  /// Resolve only through the public catalog; private payment evidence is not
  /// authorization to expose a withdrawn case.
  Future<String?> publicCaseForExpense(String expenseId) async =>
      (await publicCaseRecordForExpense(expenseId))?.id;

  Future<RescueRecord?> publicCaseRecordForExpense(String expenseId) async {
    final expensePage = await catalog(1, caseId: expenseId);
    final expenses = expensePage.items.where(
      (record) => record.id == expenseId && record.kind == 'expense',
    );
    if (expenses.isEmpty) return null;
    final parent = expenses.first.parent;
    if (parent == null || parent.isEmpty) return null;
    final snapshot = await completeCaseCatalog(parent);
    final hasCase = snapshot.items.any(
      (record) => record.id == parent && record.kind == 'case',
    );
    final hasExpense = snapshot.items.any(
      (record) =>
          record.id == expenseId &&
          record.kind == 'expense' &&
          record.parent == parent,
    );
    return hasCase && hasExpense
        ? snapshot.items.firstWhere(
            (record) => record.id == parent && record.kind == 'case',
          )
        : null;
  }

  /// Load the complete approved case snapshot before exposing contribution choices.
  /// Every page still goes through the public, authorization-filtered RPC.
  Future<DataPage<RescueRecord>> completeCaseCatalog(String caseId) async {
    final records = <String, RescueRecord>{};
    var page = 1;
    while (true) {
      final result = await catalog(page, caseId: caseId);
      // Revocation during pagination must discard data collected earlier.
      if (result.total == 0) return const DataPage([], 0);
      if (result.items.isEmpty) {
        throw StateError(
          'El catálogo cambió durante la carga. Vuelve a intentarlo.',
        );
      }
      for (final record in result.items) {
        records[record.id] = record;
      }
      if (page * 20 >= result.total) {
        if (records.length != result.total) {
          throw StateError(
            'El catálogo cambió durante la carga. Vuelve a intentarlo.',
          );
        }
        break;
      }
      page++;
    }
    return DataPage(records.values.toList(), records.length);
  }

  Future<String> fileUrl(String path) =>
      MediaStore(client).signedUrl(path, MediaPurpose.rescuePhoto);
  Future<String> upload(
    String recordId,
    Uint8List bytes, {
    required bool pdf,
  }) => MediaStore(client).upload(
    recordId,
    bytes,
    pdf ? MediaPurpose.rescueDocument : MediaPurpose.rescuePhoto,
  );
}

/// Decimal parsing never uses a floating-point amount for money.
int? parsePesos(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final cents =
      int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  return cents > 0 && cents <= 100000000 ? cents : null;
}

String pesos(int cents) {
  final magnitude = cents.abs();
  final whole = (magnitude ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  final fraction = (magnitude % 100).toString().padLeft(2, '0');
  return '${cents < 0 ? '-' : ''}\$$whole.$fraction MXN';
}

String rescueError(Object error) {
  if (error is PostgrestException &&
      ['22023', '40001', 'PT409'].contains(error.code)) {
    return error.message;
  }
  return communityError(error);
}
