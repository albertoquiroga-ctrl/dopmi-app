import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/media/media_store.dart';
export '../../core/media/prepare_photo.dart' show preparePhoto;

typedef Json = Map<String, dynamic>;
const photoBucket = 'dopmi-adoption-photos';
const statusLabels = {
  'draft': 'Borrador',
  'submitted': 'En revisión',
  'changes_requested': 'Necesita correcciones',
  'published': 'Publicada',
  'rejected': 'No aprobada',
  'adopted': 'Adopción realizada',
  'archived': 'Retirada',
};

class Adoption {
  Adoption(Json value) : data = Map.unmodifiable(value);
  final Json data;
  String text(String key) => data[key] as String? ?? '';
  String get id => text('id');
  String get owner => text('owner_id');
  String get name => text('pet_name');
  String get status => text('status');
  int get version => data['version'] as int? ?? 0;
  List<String> get photos => List<String>.from(data['photos'] as List? ?? []);
  bool get saved => data['saved'] == true;
  String get age {
    final months = data['age_months'] as int? ?? 0;
    if (months == 0) return 'Menos de un mes';
    if (months < 12) return '$months ${months == 1 ? 'mes' : 'meses'}';
    final years = months ~/ 12;
    return '$years ${years == 1 ? 'año' : 'años'}${months % 12 == 0 ? '' : ' y ${months % 12} meses'}';
  }
}

class DataPage<T> {
  const DataPage(this.items, this.total);
  final List<T> items;
  final int total;
}

class SupportOpportunity {
  SupportOpportunity(Json value) : data = Map.unmodifiable(value);
  final Json data;
  String text(String key) => data[key] as String? ?? '';
  String get id => text('case_id');
  String get expenseId => text('expense_id');
  String get name =>
      text('pet_name').trim().isEmpty ? 'Sin nombre' : text('pet_name');
  int get reimbursable => data['reimbursable_cents'] as int? ?? 0;
  int get funded => data['funded_cents'] as int? ?? 0;
}

class SavedEntry {
  SavedEntry(Json value) : data = Map.unmodifiable(value);
  final Json data;
  String text(String key) => data[key] as String? ?? '';
  String get id => text('id');
  bool get available => data['available'] == true;
  Json get publicData => Json.from(data['public_data'] as Map? ?? {});
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => SupabaseCommunityRepository(Supabase.instance.client),
);

abstract class CommunityRepository {
  String? get userId;
  Future<DataPage<Adoption>> catalog(Json filters, int page);
  Future<DataPage<Adoption>> discovery(Json filters, int page);
  Future<List<SupportOpportunity>> discoverySupport();
  Future<Adoption?> detail(String id);
  Future<DataPage<Adoption>> mine(int page);
  Future<Adoption?> own(String id);
  Future<Adoption?> ownForCase(String caseId);
  Future<Adoption> save(Json payload, {String? id, int? version});
  Future<Adoption> transition(Adoption post, String action);
  Future<void> favorite(String id, bool saved);
  Future<DataPage<SavedEntry>> savedAdoptions(int page);
  Future<DataPage<SavedEntry>> savedCases(int page);
  Future<DataPage<SavedEntry>> savedRescuers(int page);
  Future<void> favoriteCase(String id, bool saved);
  Future<void> favoriteRescuer(String id, bool saved);
  Future<String> report(String type, String id, String reason, String details);
  Future<Json?> publicProfile(String id);
  Future<List<Json>> personalImpact();
  Future<String> uploadPhoto(String postId, Uint8List bytes);
  Future<String> photoUrl(String path);
  Future<String> startThread(String postId);
  Future<DataPage<Json>> threads(int page, {String search = ''});
  Future<Json> thread(String id);
  Future<List<Json>> messages(String threadId, {Json? before});
  Future<Json> sendMessage(String threadId, String messageId, String body);
  Future<void> closeThread(String id);
  Future<void> readThread(String id);
  Future<DataPage<Json>> notifications(int page);
  Future<int> unreadNotificationCount();
  Future<void> readNotification(String id);
  VoidCallback watch(List<String> tables, VoidCallback refresh);
}

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this.client, {this.observeRealtime});
  final SupabaseClient client;
  final void Function(RealtimeSubscribeStatus, Object?)? observeRealtime;
  @override
  String? get userId => client.auth.currentUser?.id;
  Future<dynamic> rpc(String name, [Json params = const {}]) =>
      client.rpc(name, params: params);
  @override
  Future<DataPage<Adoption>> catalog(Json filters, int page) async {
    final result = await rpc('dopmi_catalog', {
      'filters': filters,
      'page_number': page,
    });
    return DataPage(
      (result['items'] as List).map((e) => Adoption(Json.from(e))).toList(),
      result['total'] as int,
    );
  }

  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) async {
    final result = await rpc('dopmi_discovery', {
      'filters': filters,
      'page_number': page,
    });
    return DataPage(
      (result['items'] as List).map((e) => Adoption(Json.from(e))).toList(),
      result['total'] as int,
    );
  }

  @override
  Future<List<SupportOpportunity>> discoverySupport() async =>
      (await rpc('dopmi_discovery_support', {'page_size': 12}) as List)
          .map((value) => SupportOpportunity(Json.from(value)))
          .toList();

  @override
  Future<Adoption?> detail(String id) async {
    final data = await rpc('dopmi_adoption_detail', {'post_id': id});
    return data == null ? null : Adoption(Json.from(data));
  }

  @override
  Future<DataPage<Adoption>> mine(int page) async {
    final result = await client
        .from('dopmi_adoptions')
        .select()
        .eq('owner_id', userId!)
        .order('updated_at', ascending: false)
        .order('id')
        .range((page - 1) * 12, page * 12 - 1)
        .count(CountOption.exact);
    return DataPage(result.data.map(Adoption.new).toList(), result.count);
  }

  @override
  Future<Adoption?> own(String id) async {
    final data = await client
        .from('dopmi_adoptions')
        .select()
        .eq('id', id)
        .eq('owner_id', userId!)
        .maybeSingle();
    return data == null ? null : Adoption(data);
  }

  @override
  Future<Adoption?> ownForCase(String caseId) async {
    final data = await client
        .from('dopmi_adoptions')
        .select()
        .eq('rescue_case_id', caseId)
        .eq('owner_id', userId!)
        .maybeSingle();
    return data == null ? null : Adoption(data);
  }

  @override
  Future<Adoption> save(Json payload, {String? id, int? version}) async =>
      Adoption(
        Json.from(
          await rpc('dopmi_save_adoption', {
            'payload': payload,
            'target_id': id,
            'expected_version': version,
          }),
        ),
      );
  @override
  Future<Adoption> transition(Adoption post, String action) async => Adoption(
    Json.from(
      await rpc('dopmi_transition_adoption', {
        'post_id': post.id,
        'expected_version': post.version,
        'action': action,
      }),
    ),
  );
  @override
  Future<void> favorite(String id, bool saved) async =>
      await rpc('dopmi_set_favorite', {'post_id': id, 'saved': saved});
  Future<DataPage<SavedEntry>> savedPage(String name, int page) async {
    final result = await rpc(name, {'page_number': page});
    return DataPage(
      (result['items'] as List).map((e) => SavedEntry(Json.from(e))).toList(),
      result['total'] as int,
    );
  }

  @override
  Future<DataPage<SavedEntry>> savedAdoptions(int page) =>
      savedPage('dopmi_saved_adoptions', page);
  @override
  Future<DataPage<SavedEntry>> savedCases(int page) =>
      savedPage('dopmi_saved_case_list', page);
  @override
  Future<DataPage<SavedEntry>> savedRescuers(int page) =>
      savedPage('dopmi_saved_rescuer_list', page);
  @override
  Future<void> favoriteCase(String id, bool saved) async =>
      await rpc('dopmi_set_case_favorite', {'target_case': id, 'saved': saved});
  @override
  Future<void> favoriteRescuer(String id, bool saved) async => await rpc(
    'dopmi_set_rescuer_favorite',
    {'target_rescuer': id, 'saved': saved},
  );
  @override
  Future<String> report(
    String type,
    String id,
    String reason,
    String details,
  ) async => await rpc('dopmi_report_content', {
    'target_type': type,
    'target_id': id,
    'reason': reason,
    'details': details,
  }) as String;
  @override
  Future<Json?> publicProfile(String id) async {
    final result =
        await rpc('dopmi_rescuer_public', {'person_id': id}) ??
        await rpc('dopmi_public_profile', {'person_id': id});
    return result == null ? null : Json.from(result);
  }

  @override
  Future<List<Json>> personalImpact() async =>
      (await rpc('dopmi_personal_impact') as List)
          .map((value) => Json.from(value))
          .toList();

  @override
  Future<String> uploadPhoto(String postId, Uint8List bytes) =>
      MediaStore(client).upload(postId, bytes, MediaPurpose.adoptionPhoto);

  @override
  Future<String> photoUrl(String path) =>
      MediaStore(client).signedUrl(path, MediaPurpose.adoptionPhoto);
  @override
  Future<String> startThread(String postId) async =>
      await rpc('dopmi_start_thread', {'post_id': postId}) as String;
  @override
  Future<DataPage<Json>> threads(int page, {String search = ''}) async {
    final result = await rpc('dopmi_match_threads', {
      'search_text': search,
      'page_number': page,
    });
    return DataPage(
      (result['items'] as List).map((e) => Json.from(e)).toList(),
      result['total'] as int,
    );
  }

  @override
  Future<Json> thread(String id) =>
      client.from('dopmi_threads').select().eq('id', id).single();
  @override
  Future<List<Json>> messages(String threadId, {Json? before}) async =>
      (await rpc('dopmi_thread_messages', {
        'thread_id': threadId,
        'before_time': before?['created_at'],
        'before_id': before?['id'],
      }) as List).map((e) => Json.from(e)).toList();
  @override
  Future<Json> sendMessage(
    String threadId,
    String messageId,
    String body,
  ) async => Json.from(
    await rpc('dopmi_send_message', {
      'thread_id': threadId,
      'message_id': messageId,
      'message_body': body,
    }),
  );
  @override
  Future<void> closeThread(String id) async =>
      await rpc('dopmi_close_thread', {'thread_id': id});
  @override
  Future<void> readThread(String id) async =>
      await rpc('dopmi_read_thread', {'thread_id': id});
  @override
  Future<DataPage<Json>> notifications(int page) async {
    final result = await client
        .from('dopmi_notifications')
        .select()
        .order('created_at', ascending: false)
        .order('id')
        .range((page - 1) * 20, page * 20 - 1)
        .count(CountOption.exact);
    return DataPage(result.data, result.count);
  }

  @override
  Future<void> readNotification(String id) async =>
      await rpc('dopmi_read_notification', {'notification_id': id});
  @override
  Future<int> unreadNotificationCount() async {
    if (userId == null) return 0;
    return await client
        .from('dopmi_notifications')
        .count(CountOption.exact)
        .isFilter('read_at', null);
  }

  @override
  VoidCallback watch(List<String> tables, VoidCallback refresh) {
    final actor = userId;
    if (actor == null || tables.isEmpty) return () {};
    var disposed = false;
    void refreshCurrentAccount() {
      if (!disposed && userId == actor) refresh();
    }

    final channel = client.channel('dopmi-${const Uuid().v4()}');
    for (final table in tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => refreshCurrentAccount(),
      );
    }
    // The Phoenix join precedes PostgreSQL replication readiness. Re-read
    // after the database subscription is live, including each reconnect, to
    // recover changes made during the gap without waiting for the poll timer.
    channel.onSystemEvents((payload) {
      if (payload is Map &&
          payload['extension'] == 'postgres_changes' &&
          payload['status'] == 'ok') {
        refreshCurrentAccount();
      }
    });
    channel.subscribe((status, error) {
      observeRealtime?.call(status, error);
    });
    return () {
      disposed = true;
      unawaited(client.removeChannel(channel));
    };
  }
}

String communityError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '40001') {
      return 'La publicación cambió en otra sesión. Conservamos tus campos; vuelve a cargar la versión actual antes de guardar.';
    }
    if (error.code == '22023') return error.message;
    if (error.code == '42501') {
      return 'No tienes acceso a este contenido. Revisa tu sesión y la aceptación de términos en Mi cuenta.';
    }
    if (error.code == '23514') {
      return 'Revisa los campos y sus límites antes de guardar.';
    }
  }
  if (error is FormatException) return error.message;
  return 'No pudimos completar la solicitud. Comprueba tu conexión y vuelve a intentar.';
}
