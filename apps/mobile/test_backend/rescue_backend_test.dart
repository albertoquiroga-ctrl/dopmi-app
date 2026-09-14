import 'dart:convert';
import 'dart:io';

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

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
  final databaseContainer =
      Platform.environment['DOPMI_LOCAL_DB_CONTAINER'] ?? 'supabase_db_dopmi';
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
    final email = 'h3-$label-${const Uuid().v4()}@example.test',
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

  Future<void> eventually(
    Future<bool> Function() ready, {
    String Function()? diagnostics,
  }) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (!await ready()) {
      if (DateTime.now().isAfter(end)) {
        fail(
          'Expected persisted/realtime state did not arrive. ${diagnostics?.call() ?? ''}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  tearDownAll(() async {
    for (final value in clients) {
      await value.dispose();
    }
    if (photos.isNotEmpty) {
      await service.storage.from(rescueBucket).remove(photos);
    }
    for (final id in users) {
      await service.auth.admin.deleteUser(id);
    }
    await service.dispose();
  });

  test('real rescuer review, private evidence, paid expenses, independent food rounds and closure', () async {
    final owner = await account('owner'),
        outsider = await account('outsider'),
        moderator = await account('moderator');
    final staffId = moderator.auth.currentUser!.id;
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(staffId), true);
    final grant = await Process.run('docker', [
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
      "insert into private.admin_memberships(user_id) values('$staffId');",
    ]);
    expect(grant.exitCode, 0);
    final repo = RescueRepository(owner),
        stranger = RescueRepository(outsider),
        anonymous = RescueRepository(client());
    final photo = img.encodePng(img.Image(width: 32, height: 32));
    Future<RescueRecord> files(RescueRecord record, List<String> roles) async {
      final attachments = <Json>[];
      for (final role in roles) {
        final path = await repo.upload(record.id, photo, pdf: false);
        photos.add(path);
        attachments.add({'path': path, 'role': role});
      }
      return repo.save(
        record.kind,
        record.publicData,
        record.privateData,
        attachments,
        record: record,
      );
    }

    Future<Json> review(
      RescueRecord r, {
      String decision = 'approved',
      int cents = 0,
      bool urgent = false,
    }) async => Json.from(
      await moderator.rpc(
        'dopmi_review_rescue',
        params: {
          'record_id': r.id,
          'expected_version': r.version,
          'decision': decision,
          'note': 'Evidencia comprobada en aceptación',
          'amount_cents': cents,
          'is_urgent': urgent,
          'urgency_note': urgent ? 'Atención prioritaria comprobada' : '',
          'publish_content': true,
        },
      ),
    );
    var identity = await repo.save(
      'verification',
      {
        'public_name': 'Refugio aceptación',
        'bio': 'Rescatamos con seguimiento público',
        'city': 'Monterrey',
        'state': 'Nuevo León',
      },
      {
        'legal_name': 'Identidad privada de aceptación',
        'phone': '8188888888',
        'experience': 'Tres años de rescate',
        'social_url': 'https://instagram.com/example',
        'identity_type': 'ine',
      },
      [],
    );
    await expectLater(
      stranger.detail(identity.id),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      repo.transition(identity, 'submit'),
      throwsA(isA<PostgrestException>()),
    );
    identity = await files(identity, ['identity', 'address']);
    final privatePath = identity.files.first['path'] as String;
    await expectLater(
      anonymous.fileUrl(privatePath),
      throwsA(isA<StorageException>()),
    );
    await expectLater(
      stranger.fileUrl(privatePath),
      throwsA(isA<StorageException>()),
    );
    identity = await repo.transition(identity, 'submit');
    await expectLater(
      owner.storage.from(rescueBucket).updateBinary(privatePath, photo),
      throwsA(isA<StorageException>()),
    );
    final identityDetails = await moderator.rpc(
      'dopmi_rescue_detail',
      params: {'record_id': identity.id},
    );
    expect(
      identityDetails['record']['private_data']['legal_name'],
      'Identidad privada de aceptación',
    );
    expect(
      await moderator.storage.from(rescueBucket).download(privatePath),
      isNotEmpty,
    );
    identity = RescueRecord(
      await review(identity, decision: 'changes_requested'),
    );
    expect(identity.files.length, 2);
    expect(identity.privateData['phone'], '8188888888');
    final notification = SupabaseCommunityRepository(owner);
    await eventually(
      () async =>
          (await notification.notifications(1)).items
              .any((n) => n['rescue_id'] == identity.id),
    );
    identity = await repo.transition(identity, 'submit');
    identity = RescueRecord(await review(identity));

    var rescue = await repo.save(
      'case',
      {
        'pet_name': 'Luna aceptación H3',
        'species': 'dog',
        'sex': 'female',
        'age': '2 meses',
        'story': 'Rescatada con lesión. Sigue su recuperación.',
        'city': 'Monterrey',
        'state': 'Nuevo León',
        'need': 'Alimento y consulta',
      },
      {},
      [],
    );
    rescue = await files(rescue, ['public']);
    expect((await anonymous.catalog(1)).total, 0);
    rescue = await repo.transition(rescue, 'submit');
    rescue = RescueRecord(await review(rescue));
    expect(
      (await anonymous.catalog(1)).items.single.title,
      'Luna aceptación H3',
    );
    final publicPath = rescue.files.single['path'] as String;
    expect(
      await anonymous.client.storage.from(rescueBucket).download(publicPath),
      isNotEmpty,
    );
    await expectLater(
      anonymous.client.storage.from(rescueBucket).download(privatePath),
      throwsA(isA<StorageException>()),
    );

    var expense = await repo.save(
      'expense',
      {
        'title': 'Alimento primera ronda',
        'description': 'Compra realizada para Luna',
        'category': 'food',
        'round_label': 'Ronda 1',
      },
      {
        'paid_on': '2026-09-01',
        'vendor': 'Veterinaria de prueba',
        'amount_cents': '25050',
        'receipt_reference': 'H3-F001',
        'urgency_reason': 'Cuidados continuos',
      },
      [],
      parent: rescue.id,
    );
    expense = await files(expense, ['receipt', 'proof']);
    expense = await repo.transition(expense, 'submit');
    await expectLater(
      repo.transition(rescue, 'close'),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      review(expense, cents: 25051),
      throwsA(isA<PostgrestException>()),
    );
    final concurrent = await Future.wait([
      for (var i = 0; i < 2; i++)
        review(
          expense,
          cents: 24000,
          urgent: true,
        ).then<Object>((v) => v).catchError((Object e) => e),
    ]);
    expect(concurrent.whereType<Json>().length, 1);
    expect(concurrent.whereType<PostgrestException>().single.code, '40001');
    expense = RescueRecord(concurrent.whereType<Json>().single);
    expect(expense.data['reimbursable_cents'], 24000);
    expect(expense.data['urgent'], true);
    final publicData = await anonymous.catalog(1, caseId: rescue.id);
    expect(publicData.total, 2);
    final json = jsonEncode(publicData.items.map((r) => r.data).toList());
    for (final secret in [
      'legal_name',
      '8188888888',
      'H3-F001',
      'private_data',
      expense.files.first['path'] as String,
    ]) {
      expect(json.contains(secret), false);
    }
    await expectLater(
      stranger.fileUrl(expense.files.first['path'] as String),
      throwsA(isA<StorageException>()),
    );

    var round2 = await repo.save(
      'expense',
      expense.publicData,
      expense.privateData,
      [],
      parent: rescue.id,
    );
    round2 = await files(round2, ['receipt', 'proof']);
    await expectLater(
      repo.transition(round2, 'submit'),
      throwsA(isA<PostgrestException>()),
    );
    round2 = await repo.save(
      'expense',
      {...round2.publicData, 'round_label': 'Ronda 2'},
      {...round2.privateData, 'receipt_reference': 'H3-F002'},
      round2.files,
      record: round2,
    );
    round2 = await repo.transition(round2, 'submit');
    expect(round2.data['reimbursable_cents'], 0);
    expect(round2.data['approved_at'], null);
    round2 = await repo.transition(round2, 'withdraw');
    rescue = await repo.transition(rescue, 'close');
    expect(rescue.status, 'closed');
    await expectLater(
      repo.transition(round2, 'submit'),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      repo.save('expense', {}, {}, [], parent: rescue.id),
      throwsA(isA<PostgrestException>()),
    );
    identity = RescueRecord(
      await review(identity, decision: 'changes_requested'),
    );
    expect((await anonymous.catalog(1)).total, 0);
    await expectLater(
      anonymous.fileUrl(publicPath),
      throwsA(isA<StorageException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}
