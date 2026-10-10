import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/media/media_store.dart';
import '../adoption/community_repository.dart';

class CaseUpdate {
  CaseUpdate(Json value) : data = Map.unmodifiable(value);
  final Json data;
  String text(String key) => data[key] as String? ?? '';
  String get id => text('id');
  String get caseId => text('case_id');
  String get body => text('body');
  String get status => text('status');
  int get version => data['version'] as int? ?? 0;
  List<String> get photos => List<String>.from(data['photos'] as List? ?? []);
  String? get publishedAt => data['published_at'] as String?;
}

final caseUpdateRepositoryProvider = Provider<CaseUpdateRepository>(
  (ref) => CaseUpdateRepository(Supabase.instance.client),
);

class CaseUpdateRepository {
  CaseUpdateRepository(this.client);
  final SupabaseClient client;

  Future<List<CaseUpdate>> publicFor(String caseId) async => (await client.rpc(
    'dopmi_public_case_updates',
    params: {'target_case': caseId},
  ) as List).map((value) => CaseUpdate(Json.from(value))).toList();

  Future<List<CaseUpdate>> mine(String caseId) async => (await client.rpc(
    'dopmi_my_case_updates',
    params: {'target_case': caseId},
  ) as List).map((value) => CaseUpdate(Json.from(value))).toList();

  Future<CaseUpdate> save(
    String caseId,
    String body,
    List<String> photos, {
    CaseUpdate? update,
  }) async => CaseUpdate(
    Json.from(
      await client.rpc(
        'dopmi_save_case_update',
        params: {
          'target_case': caseId,
          'update_id': update?.id,
          'expected_version': update?.version,
          'update_body': body,
          'update_photos': photos,
        },
      ),
    ),
  );

  Future<CaseUpdate> transition(CaseUpdate update, String action) async =>
      CaseUpdate(
        Json.from(
          await client.rpc(
            'dopmi_transition_case_update',
            params: {
              'update_id': update.id,
              'expected_version': update.version,
              'action': action,
            },
          ),
        ),
      );

  Future<String> upload(String updateId, Uint8List bytes) =>
      MediaStore(client).upload(updateId, bytes, MediaPurpose.caseUpdatePhoto);

  Future<String> photoUrl(String path) =>
      MediaStore(client).signedUrl(path, MediaPurpose.caseUpdatePhoto);
}
