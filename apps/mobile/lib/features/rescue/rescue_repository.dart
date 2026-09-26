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
  Json get publicData => Json.from(data['public_data'] as Map? ?? {});
  Json get privateData => Json.from(data['private_data'] as Map? ?? {});
  List<Json> get files =>
      (data['files'] as List? ?? []).map((e) => Json.from(e as Map)).toList();
  String get title =>
      (publicData['public_name'] ??
              publicData['pet_name'] ??
              publicData['title'] ??
              'Sin título')
          as String;
  bool get editable =>
      ['draft', 'changes_requested', 'rejected'].contains(status);
}

final rescueRepositoryProvider = Provider<RescueRepository>(
  (ref) => RescueRepository(Supabase.instance.client),
);

class RescueRepository {
  RescueRepository(this.client);
  final SupabaseClient client;
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async {
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

String pesos(int cents) =>
    '\$${(cents ~/ 100).toString()}.${(cents % 100).toString().padLeft(2, '0')} MXN';
String rescueError(Object error) {
  if (error is PostgrestException && ['22023', '40001'].contains(error.code)) {
    return error.message;
  }
  return communityError(error);
}
