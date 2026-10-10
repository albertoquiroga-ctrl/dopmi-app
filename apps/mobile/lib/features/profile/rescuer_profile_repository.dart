import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/media/media_store.dart';
import '../adoption/community_repository.dart';

final rescuerProfileRepositoryProvider = Provider<RescuerProfileRepository>(
  (ref) => SupabaseRescuerProfileRepository(Supabase.instance.client),
);

abstract class RescuerProfileRepository {
  String? get userId;
  Future<Json?> load();
  Future<Json> save(Json payload, {int? version});
  Future<Json> transition(int version, String action);
  Future<String> uploadAvatar(Uint8List bytes);
  Future<String> avatarUrl(String path);
}

class SupabaseRescuerProfileRepository implements RescuerProfileRepository {
  SupabaseRescuerProfileRepository(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Future<Json?> load() async {
    final value = await client.rpc('dopmi_my_rescuer_profile');
    return value == null ? null : Json.from(value);
  }

  @override
  Future<Json> save(Json payload, {int? version}) async => Json.from(
    await client.rpc(
      'dopmi_save_rescuer_profile',
      params: {'payload': payload, 'expected_version': version},
    ),
  );

  @override
  Future<Json> transition(int version, String action) async => Json.from(
    await client.rpc(
      'dopmi_transition_rescuer_profile',
      params: {'expected_version': version, 'action': action},
    ),
  );

  @override
  Future<String> uploadAvatar(Uint8List bytes) =>
      MediaStore(client).upload(userId!, bytes, MediaPurpose.rescuerAvatar);
  @override
  Future<String> avatarUrl(String path) =>
      MediaStore(client).signedUrl(path, MediaPurpose.rescuerAvatar);
}
