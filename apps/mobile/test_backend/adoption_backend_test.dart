import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  final configPath = Platform.environment['DOPMI_LOCAL_CONFIG'];
  if (configPath == null) {
    throw StateError('Set DOPMI_LOCAL_CONFIG to local CLI status JSON.');
  }
  final config = jsonDecode(File(configPath).readAsStringSync()) as Map;
  final uri = Uri.parse(config['API_URL'] as String);
  if (uri.scheme != 'http' || !['127.0.0.1', 'localhost'].contains(uri.host)) {
    throw StateError('Only loopback backend tests are allowed.');
  }
  final service = SupabaseClient(
    uri.toString(),
    config['SERVICE_ROLE_KEY'] as String,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final clients = <SupabaseClient>[], users = <String>[], photos = <String>[];
  SupabaseClient client() {
    final value = SupabaseClient(
      uri.toString(),
      config['ANON_KEY'] as String,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    clients.add(value);
    return value;
  }

  Future<SupabaseClient> account(String label) async {
    final email = 'h2-$label-${const Uuid().v4()}@example.test',
        password = 'TestA1-${const Uuid().v4()}';
    final response = await service.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {
          'display_name': 'Privado $label',
          'terms_accepted': true,
          'terms_version': 'development-2026-09-13',
        },
      ),
    );
    users.add(response.user!.id);
    final value = client();
    await value.auth.signInWithPassword(email: email, password: password);
    return value;
  }

  Future<void> eventually(Future<bool> Function() ready) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (!await ready()) {
      if (DateTime.now().isAfter(end)) {
        fail('Expected persisted/realtime state did not arrive.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  tearDownAll(() async {
    for (final value in clients) {
      await value.dispose();
    }
    if (photos.isNotEmpty) {
      await service.storage.from(photoBucket).remove(photos);
    }
    for (final id in users) {
      await service.auth.admin.deleteUser(id);
    }
    await service.dispose();
  });

  test('real adoption review, Storage privacy, catalog, favorites, conversation retries and realtime', () async {
    final owner = await account('owner'),
        adopter = await account('adopter'),
        outsider = await account('outsider'),
        moderator = await account('moderator');
    final staffId = moderator.auth.currentUser!.id;
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(staffId), true);
    final grant = await Process.run('docker', [
      'exec',
      'supabase_db_dopmi',
      'psql',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-c',
      "insert into private.admin_memberships(user_id) values('$staffId');",
    ]);
    expect(
      grant.exitCode,
      0,
      reason: 'Local operator grants the disposable moderator membership.',
    );
    final author = SupabaseCommunityRepository(owner),
        reader = SupabaseCommunityRepository(adopter),
        stranger = SupabaseCommunityRepository(outsider),
        anonymous = SupabaseCommunityRepository(client());
    final payload = <String, dynamic>{
      'pet_name': 'Luna aceptación',
      'species': 'dog',
      'sex': 'female',
      'age_months': 25,
      'size': 'medium',
      'city': 'Monterrey',
      'region': 'Nuevo León',
      'story': 'Luna necesita una familia paciente y tiempo para pasear.',
      'publisher_name': 'Refugio público de prueba',
      'publisher_bio': 'Acompañamos a las familias.',
      'vaccinated': true,
    };
    var post = await author.save(payload);
    expect(await stranger.own(post.id), isNull);
    expect(await anonymous.detail(post.id), isNull);
    final image = img.Image(width: 32, height: 32, numChannels: 3)
      ..clear(img.ColorRgb8(247, 203, 45));
    final path = await author.uploadPhoto(
      post.id,
      Uint8List.fromList(img.encodePng(image)),
    );
    photos.add(path);
    await expectLater(
      anonymous.photoUrl(path),
      throwsA(isA<StorageException>()),
    );
    await expectLater(
      outsider.storage
          .from(photoBucket)
          .uploadBinary(
            '${author.userId}/${post.id}/${const Uuid().v4()}.jpg',
            Uint8List.fromList(img.encodeJpg(image)),
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          ),
      throwsA(isA<StorageException>()),
    );
    post = await author.save(
      {
        ...payload,
        'photos': [path],
      },
      id: post.id,
      version: post.version,
    );
    post = await author.transition(post, 'submit');
    expect(
      (await moderator.rpc('dopmi_admin_adoptions'))['total'],
      greaterThanOrEqualTo(1),
    );
    await expectLater(
      adopter.rpc(
        'dopmi_review_adoption',
        params: {
          'post_id': post.id,
          'expected_version': post.version,
          'decision': 'published',
        },
      ),
      throwsA(isA<PostgrestException>()),
    );
    var reviewed = await moderator.rpc(
      'dopmi_review_adoption',
      params: {
        'post_id': post.id,
        'expected_version': post.version,
        'decision': 'changes_requested',
        'feedback': 'Aclara cómo se lleva con gatos.',
      },
    );
    post = Adoption(Json.from(reviewed));
    expect(post.text('story'), payload['story']);
    expect(
      (await author.notifications(1)).items.any((n) => n['kind'] == 'review'),
      true,
    );
    post = await author.save(
      {
        ...payload,
        'photos': [path],
        'social_cats': false,
      },
      id: post.id,
      version: post.version,
    );
    post = await author.transition(post, 'submit');
    reviewed = await moderator.rpc(
      'dopmi_review_adoption',
      params: {
        'post_id': post.id,
        'expected_version': post.version,
        'decision': 'published',
      },
    );
    post = Adoption(Json.from(reviewed));
    final catalog = await anonymous.catalog({
      'owner_id': author.userId,
      'species': 'dog',
      'city': 'monterrey',
      'min_age': 12,
      'max_age': 95,
    }, 1);
    expect(catalog.items.single.id, post.id);
    expect(
      (await anonymous.catalog({
        'owner_id': author.userId,
        'species': 'cat',
      }, 1)).total,
      0,
    );
    expect(
      (await anonymous.publicProfile(author.userId!))!['name'],
      'Refugio público de prueba',
    );
    expect(
      (await anonymous.detail(post.id))!.data.containsKey('review_feedback'),
      false,
    );
    final signed = await anonymous.photoUrl(path), http = HttpClient();
    try {
      final response = await (await http.getUrl(Uri.parse(signed))).close();
      expect(response.statusCode, 200);
      await response.drain<void>();
    } finally {
      http.close();
    }
    await expectLater(
      owner.storage
          .from(photoBucket)
          .uploadBinary(
            path,
            Uint8List.fromList(img.encodeJpg(image)),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          ),
      throwsA(isA<StorageException>()),
    );
    await reader.favorite(post.id, true);
    await reader.favorite(post.id, true);
    expect((await reader.catalog({'saved': true}, 1)).items.single.id, post.id);
    expect((await stranger.catalog({'saved': true}, 1)).total, 0);
    final thread = await reader.startThread(post.id);
    expect(await reader.startThread(post.id), thread);

    var updates = 0;
    final cancel = author.watch(['dopmi_notifications'], () {
      updates++;
    });
    addTearDown(cancel);
    await eventually(() async => updates > 0);
    final initialUpdates = updates, messageId = const Uuid().v4();
    final attempts = await Future.wait([
      reader.sendMessage(
        thread,
        messageId,
        'Hola, me interesa conocer a Luna.',
      ),
      reader.sendMessage(
        thread,
        messageId,
        'Hola, me interesa conocer a Luna.',
      ),
    ]);
    expect(attempts[0]['id'], attempts[1]['id']);
    await eventually(() async => updates > initialUpdates);
    expect((await author.messages(thread)).length, 1);
    expect(
      (await author.notifications(1)).items
          .where((n) => n['kind'] == 'message')
          .length,
      1,
    );
    await expectLater(
      stranger.messages(thread),
      throwsA(isA<PostgrestException>()),
    );
    expect(await moderator.from('dopmi_messages').select(), isEmpty);
    await author.readThread(thread);
    expect((await author.threads(1)).items.single['unread_count'], 0);
    await author.closeThread(thread);
    await expectLater(
      reader.sendMessage(thread, const Uuid().v4(), 'Mensaje nuevo'),
      throwsA(isA<PostgrestException>()),
    );
    expect(
      (await reader.sendMessage(
        thread,
        messageId,
        'Hola, me interesa conocer a Luna.',
      ))['id'],
      messageId,
    );
    await reader.favorite(post.id, false);
    expect((await reader.catalog({'saved': true}, 1)).total, 0);
    post = await author.save(
      {
        ...payload,
        'pet_name': 'Cambio pendiente',
        'photos': [path],
      },
      id: post.id,
      version: post.version,
    );
    expect(await anonymous.detail(post.id), isNull);
    await expectLater(
      anonymous.photoUrl(path),
      throwsA(isA<StorageException>()),
    );
    expect((await author.own(post.id))!.name, 'Cambio pendiente');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
