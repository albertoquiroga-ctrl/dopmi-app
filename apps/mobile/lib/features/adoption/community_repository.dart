import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => SupabaseCommunityRepository(Supabase.instance.client),
);

abstract class CommunityRepository {
  String? get userId;
  Future<DataPage<Adoption>> catalog(Json filters, int page);
  Future<Adoption?> detail(String id);
  Future<DataPage<Adoption>> mine(int page);
  Future<Adoption?> own(String id);
  Future<Adoption> save(Json payload, {String? id, int? version});
  Future<Adoption> transition(Adoption post, String action);
  Future<void> favorite(String id, bool saved);
  Future<Json?> publicProfile(String id);
  Future<String> uploadPhoto(String postId, Uint8List bytes);
  Future<String> photoUrl(String path);
  Future<String> startThread(String postId);
  Future<DataPage<Json>> threads(int page);
  Future<Json> thread(String id);
  Future<List<Json>> messages(String threadId, {Json? before});
  Future<Json> sendMessage(String threadId, String messageId, String body);
  Future<void> closeThread(String id);
  Future<void> readThread(String id);
  Future<DataPage<Json>> notifications(int page);
  Future<void> readNotification(String id);
  VoidCallback watch(List<String> tables, VoidCallback refresh);
}

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this.client);
  final SupabaseClient client;
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
  @override
  Future<Json?> publicProfile(String id) async {
    final result = await rpc('dopmi_public_profile', {'person_id': id});
    return result == null ? null : Json.from(result);
  }

  @override
  Future<String> uploadPhoto(String postId, Uint8List bytes) async {
    final safe = await compute(preparePhoto, bytes);
    final path = '$userId/$postId/${const Uuid().v4()}.jpg';
    await client.storage
        .from(photoBucket)
        .uploadBinary(
          path,
          safe,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return path;
  }

  @override
  Future<String> photoUrl(String path) =>
      client.storage.from(photoBucket).createSignedUrl(path, 60);
  @override
  Future<String> startThread(String postId) async =>
      await rpc('dopmi_start_thread', {'post_id': postId}) as String;
  @override
  Future<DataPage<Json>> threads(int page) async {
    final result = await rpc('dopmi_list_threads', {'page_number': page});
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
  VoidCallback watch(List<String> tables, VoidCallback refresh) {
    if (userId == null || tables.isEmpty) return () {};
    final channel = client.channel('dopmi-${const Uuid().v4()}');
    for (final table in tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => refresh(),
      );
    }
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) refresh();
    });
    return () {
      unawaited(client.removeChannel(channel));
    };
  }
}

Uint8List preparePhoto(Uint8List bytes) {
  if (bytes.length < 16) {
    throw const FormatException(
      'No pudimos abrir esa foto. Elige un archivo JPG, PNG o WebP.',
    );
  }
  if (bytes.length > 15 * 1024 * 1024) {
    throw const FormatException('La foto debe pesar menos de 15 MB.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException(
      'Elige una foto JPG, PNG o WebP de hasta 40 megapíxeles.',
    );
  }
  var photo = decoder!.decodeFrame(0);
  if (photo == null) throw const FormatException('No pudimos abrir esa foto.');
  photo = img.bakeOrientation(photo);
  if (photo.width > 1600 || photo.height > 1600) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1600 : null,
      height: photo.height > photo.width ? 1600 : null,
    );
  }
  // Copy pixels into a clean image so EXIF, location, comments and other metadata are not uploaded.
  final clean = img.Image.fromBytes(
    width: photo.width,
    height: photo.height,
    bytes: photo.getBytes(order: img.ChannelOrder.rgb).buffer,
    numChannels: 3,
  );
  return Uint8List.fromList(img.encodeJpg(clean, quality: 85));
}

String communityError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '40001') {
      return 'La publicación cambió en otra sesión. Conservamos tus campos; vuelve a cargar la versión actual antes de guardar.';
    }
    if (error.code == '22023') return error.message;
    if (error.code == '42501') {
      return 'No tienes acceso a este contenido. Revisa tu sesión y el aviso de desarrollo en Mi cuenta.';
    }
    if (error.code == '23514') {
      return 'Revisa los campos y sus límites antes de guardar.';
    }
  }
  if (error is FormatException) return error.message;
  return 'No pudimos completar la solicitud. Comprueba tu conexión y vuelve a intentar.';
}
