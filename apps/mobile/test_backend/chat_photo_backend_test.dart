import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/media_store.dart';
import 'package:dopmi_mobile/features/communication/chat_photo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Fresh local fixtures only. Never reads or reuses historical acceptance data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  final configPath = Platform.environment['DOPMI_LOCAL_CONFIG'];
  if (configPath == null) {
    throw StateError(
      'DOPMI_LOCAL_CONFIG is required for the isolated local stack.',
    );
  }
  final config = jsonDecode(File(configPath).readAsStringSync()) as Map;
  final api = Uri.parse(config['API_URL'] as String);
  final database = Uri.parse(config['DB_URL'] as String);
  final configuredContainer = Platform.environment['DOPMI_LOCAL_DB_CONTAINER'];
  final isolated =
      api.port == 54381 &&
      database.port == 54382 &&
      (configuredContainer == null ||
          configuredContainer == 'supabase_db_dopmi-dde1');
  final githubCi =
      Platform.environment['GITHUB_ACTIONS'] == 'true' &&
      configuredContainer == 'supabase_db_dopmi' &&
      api.port == 54321 &&
      database.port == 54322;
  if (api.scheme != 'http' ||
      !['127.0.0.1', 'localhost'].contains(api.host) ||
      api.userInfo.isNotEmpty ||
      api.query.isNotEmpty ||
      api.fragment.isNotEmpty ||
      !['', '/'].contains(api.path) ||
      !['127.0.0.1', 'localhost'].contains(database.host) ||
      !['postgres', 'postgresql'].contains(database.scheme) ||
      (!isolated && !githubCi)) {
    throw StateError(
      'Only the isolated local stack or explicitly configured GitHub CI stack is allowed.',
    );
  }
  final databaseContainer = isolated
      ? 'supabase_db_dopmi-dde1'
      : 'supabase_db_dopmi';
  final service = SupabaseClient(
    api.toString(),
    config['SERVICE_ROLE_KEY'] as String,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final clients = <SupabaseClient>[];
  final users = <String>[];
  final posts = <String>[];
  final threads = <String>[];
  final messages = <String>[];
  final objects = <String, SupabaseClient>{};
  final adminMemberships = <String>[];
  final runId = const Uuid().v4();
  final journal = File(
    '${Directory.systemTemp.path}/dopmi-chat-photo-$runId.json',
  );
  void record({bool cleaned = false}) => journal.writeAsStringSync(
    jsonEncode({
      'run_id': runId,
      'local_api': '${api.scheme}://${api.host}:${api.port}',
      'users': users,
      'posts': posts,
      'threads': threads,
      'messages': messages,
      'objects': objects.keys.toList(),
      'admin_memberships': adminMemberships,
      'cleanup_complete': cleaned,
    }),
  );
  record();
  SupabaseClient client() {
    final value = SupabaseClient(
      api.toString(),
      config['ANON_KEY'] as String,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    clients.add(value);
    return value;
  }

  Future<SupabaseClient> account(String label) async {
    final email = 'dde1-chat-$label-${const Uuid().v4()}@example.test';
    final password = 'TestA1-${const Uuid().v4()}';
    final result = await service.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {
          'display_name': 'Chat QA $label',
          'terms_accepted': true,
          'terms_version': 'development-2026-09-13',
        },
      ),
    );
    users.add(result.user!.id);
    record();
    final value = client();
    await value.auth.signInWithPassword(email: email, password: password);
    return value;
  }

  Future<void> membership(String id, {required bool grant}) async {
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(id) || !users.contains(id)) {
      throw StateError('Only this run\'s synthetic account can be granted.');
    }
    final sql = grant
        ? "insert into private.admin_memberships(user_id) values('$id');"
        : "delete from private.admin_memberships where user_id='$id';";
    final result = await Process.run('docker', [
      'exec',
      databaseContainer,
      'psql',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-c',
      sql,
    ]);
    // No credentials, tokens or server output are printed in diagnostics.
    if (result.exitCode != 0) {
      throw StateError('Isolated QA membership operation failed.');
    }
  }

  Future<void> signedHttpPhoto(
    SupabaseChatPhotoRepository repo,
    String path,
  ) async {
    final signed = Uri.parse(await repo.photoUrl(path));
    if (signed.scheme != api.scheme ||
        signed.host != api.host ||
        signed.port != api.port) {
      throw StateError('Storage returned a nonlocal photo URL.');
    }
    final http = HttpClient();
    try {
      final response = await (await http.getUrl(signed)).close();
      expect(response.statusCode, 200);
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      expect(img.decodeJpg(Uint8List.fromList(bytes)), isNotNull);
    } finally {
      http.close(force: true);
    }
  }

  Future<String> upload(
    SupabaseClient author,
    String thread,
    String message,
    Uint8List jpeg,
  ) async {
    final path = '${author.auth.currentUser!.id}/$thread/$message.jpg';
    objects[path] = author;
    record();
    return SupabaseChatPhotoRepository(author).upload(thread, message, jpeg);
  }

  tearDownAll(() async {
    final failures = <String>[];
    Future<void> cleanup(String label, Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        failures.add(label);
      }
    }

    // Remove only this run's relational references. Published Storage blobs are
    // deliberately retained until these exact messages have been removed.
    if (messages.isNotEmpty) {
      await cleanup('notifications', () async {
        await service
            .from('dopmi_notifications')
            .delete()
            .inFilter('source_id', messages);
      });
      await cleanup('messages', () async {
        await service.from('dopmi_messages').delete().inFilter('id', messages);
      });
    }
    for (final entry in objects.entries) {
      await cleanup('own object', () async {
        await entry.value.storage.from(MediaPurpose.chatPhoto.bucket).remove([
          entry.key,
        ]);
        await expectLater(
          entry.value.storage
              .from(MediaPurpose.chatPhoto.bucket)
              .download(entry.key),
          throwsA(isA<StorageException>()),
        );
      });
    }
    if (threads.isNotEmpty) {
      await cleanup('threads', () async {
        await service.from('dopmi_threads').delete().inFilter('id', threads);
      });
    }
    if (posts.isNotEmpty) {
      await cleanup('post notices', () async {
        await service
            .from('dopmi_notifications')
            .delete()
            .inFilter('post_id', posts);
      });
      await cleanup('posts', () async {
        await service.from('dopmi_adoptions').delete().inFilter('id', posts);
      });
    }
    for (final id in adminMemberships) {
      await cleanup('membership', () => membership(id, grant: false));
    }
    for (final id in users) {
      await cleanup('user', () => service.auth.admin.deleteUser(id));
    }
    for (final value in clients) {
      await cleanup('client', value.dispose);
    }
    await cleanup('service', service.dispose);
    record(cleaned: failures.isEmpty);
    expect(
      failures,
      isEmpty,
      reason: 'Local cleanup failed; retain the private journal for exact recovery.',
    );
  });

  test('local Auth Storage HTTP RPC: private pending/published chat photos, retries, closure and cross-thread boundaries', () async {
    final author = await account('author');
    final participant = await account('participant');
    final outsider = await account('outsider');
    final moderator = await account('moderator');
    final anonymous = client();
    final authorId = author.auth.currentUser!.id;
    final participantId = participant.auth.currentUser!.id;
    final outsiderId = outsider.auth.currentUser!.id;
    final moderatorId = moderator.auth.currentUser!.id;
    adminMemberships.add(moderatorId);
    record();
    await membership(moderatorId, grant: true);
    final post = const Uuid().v4();
    posts.add(post);
    record();
    await service.from('dopmi_adoptions').insert({
      'id': post,
      'owner_id': authorId,
      'pet_name': 'Luna QA chat',
      'status': 'published',
      'species': 'dog',
      'sex': 'female',
      'age_months': 24,
      'size': 'medium',
      'city': 'Monterrey',
      'region': 'Nuevo León',
      'story': 'Datos sintéticos de QA local.',
    });
    final thread = const Uuid().v4();
    final otherThread = const Uuid().v4();
    threads.addAll([thread, otherThread]);
    record();
    await service.from('dopmi_threads').insert([
      {
        'id': thread,
        'post_id': post,
        'owner_id': authorId,
        'adopter_id': participantId,
        'pet_name': 'Luna QA chat',
      },
      {
        'id': otherThread,
        'post_id': post,
        'owner_id': authorId,
        'adopter_id': outsiderId,
        'pet_name': 'Luna QA chat',
      },
    ]);
    final image = img.Image(width: 32, height: 24, numChannels: 3)
      ..clear(img.ColorRgb8(247, 203, 45));
    final jpeg = Uint8List.fromList(img.encodeJpg(image));
    final writer = SupabaseChatPhotoRepository(author);
    final reader = SupabaseChatPhotoRepository(participant);
    final strangers = [
      SupabaseChatPhotoRepository(outsider),
      SupabaseChatPhotoRepository(moderator),
      SupabaseChatPhotoRepository(anonymous),
    ];
    final message = const Uuid().v4();
    messages.add(message);
    record();
    final path = await upload(author, thread, message, jpeg);
    await signedHttpPhoto(writer, path);
    final beforeRetry = await author.storage
        .from(MediaPurpose.chatPhoto.bucket)
        .download(path);
    final replacement = Uint8List.fromList(
      img.encodeJpg(
        img.Image(width: 32, height: 24, numChannels: 3)
          ..clear(img.ColorRgb8(0, 0, 255)),
      ),
    );
    expect(await writer.upload(thread, message, replacement), path);
    final afterRetry = await author.storage
        .from(MediaPurpose.chatPhoto.bucket)
        .download(path);
    expect(
      afterRetry,
      orderedEquals(beforeRetry),
      reason: 'Stable upload retry never overwrites the pending JPEG.',
    );
    await expectLater(reader.photoUrl(path), throwsA(isA<StorageException>()));
    for (final stranger in strangers) {
      await expectLater(
        stranger.photoUrl(path),
        throwsA(isA<StorageException>()),
      );
    }
    // A participant cannot delete another participant's unpublished object.
    try {
      await reader.discard(path);
    } on StorageException {
      /* denied delete is expected */
    }
    await signedHttpPhoto(writer, path);
    final unusedId = const Uuid().v4();
    final unused = await upload(author, thread, unusedId, jpeg);
    await writer.discard(unused);
    await expectLater(
      writer.photoUrl(unused),
      throwsA(isA<StorageException>()),
    );
    // The author belongs to both conversations; path binding still rejects reuse.
    final attackId = const Uuid().v4();
    messages.add(attackId);
    record();
    await expectLater(
      writer.send(otherThread, attackId, '', path),
      throwsA(isA<PostgrestException>()),
    );
    final sends = await Future.wait([
      writer.send(thread, message, '', path),
      writer.send(thread, message, '', path),
    ]);
    expect(sends[0]['id'], message);
    expect(sends[1]['id'], message);
    expect(sends[0]['body'], '');
    expect(sends[0]['attachment_path'], path);
    expect(
      (await author.from('dopmi_messages').select('id').eq('id', message))
          .length,
      1,
    );
    await signedHttpPhoto(reader, path);
    for (final stranger in strangers) {
      await expectLater(
        stranger.photoUrl(path),
        throwsA(isA<StorageException>()),
      );
    }
    expect(
      await moderator.from('dopmi_messages').select('id').eq('id', message),
      isEmpty,
    );
    await expectLater(
      author.storage
          .from(MediaPurpose.chatPhoto.bucket)
          .updateBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          ),
      throwsA(isA<StorageException>()),
    );
    try {
      await writer.discard(path);
    } on StorageException {
      /* published deletion is denied */
    }
    await signedHttpPhoto(reader, path);
    await expectLater(
      writer.send(thread, message, 'Cambio', path),
      throwsA(isA<PostgrestException>()),
    );
    await author.rpc('dopmi_close_thread', params: {'thread_id': thread});
    await signedHttpPhoto(writer, path);
    await signedHttpPhoto(reader, path);
    expect((await writer.send(thread, message, '', path))['id'], message);
    final closedId = const Uuid().v4();
    messages.add(closedId);
    record();
    await expectLater(
      writer.send(thread, closedId, 'No permitido', ''),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      upload(author, thread, closedId, jpeg),
      throwsA(isA<StorageException>()),
    );
    for (final stranger in strangers) {
      await expectLater(
        stranger.send(thread, const Uuid().v4(), 'No permitido', ''),
        throwsA(isA<PostgrestException>()),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
