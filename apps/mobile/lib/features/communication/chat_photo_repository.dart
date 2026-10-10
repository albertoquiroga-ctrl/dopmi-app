import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/media/media_store.dart';
import '../adoption/community_repository.dart';

final chatPhotoRepositoryProvider = Provider<ChatPhotoRepository>(
  (_) => SupabaseChatPhotoRepository(Supabase.instance.client),
);

abstract class ChatPhotoRepository {
  String? get userId;
  Future<String> upload(String threadId, String messageId, Uint8List bytes);
  Future<Json> send(
    String threadId,
    String messageId,
    String body,
    String attachmentPath,
  );
  Future<String> photoUrl(String path);
  Future<void> discard(String path);
}

class SupabaseChatPhotoRepository implements ChatPhotoRepository {
  SupabaseChatPhotoRepository(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Future<String> upload(String threadId, String messageId, Uint8List bytes) =>
      MediaStore(client).uploadChat(threadId, messageId, bytes);
  @override
  Future<Json> send(
    String threadId,
    String messageId,
    String body,
    String attachmentPath,
  ) async => Json.from(
    await client.rpc(
      'dopmi_send_message_v2',
      params: {
        'thread_id': threadId,
        'message_id': messageId,
        'message_body': body,
        'attachment_path': attachmentPath,
      },
    ) as Map,
  );
  @override
  Future<String> photoUrl(String path) =>
      MediaStore(client).signedUrl(path, MediaPurpose.chatPhoto);
  @override
  Future<void> discard(String path) async {
    // Storage itself denies deleting any attachment referenced by a message.
    await client.storage.from(MediaPurpose.chatPhoto.bucket).remove([path]);
  }
}
