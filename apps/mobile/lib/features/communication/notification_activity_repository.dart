import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adoption/community_repository.dart';

final notificationActivityRepositoryProvider =
    Provider<NotificationActivityRepository>(
      (ref) => NotificationActivityRepository(Supabase.instance.client),
    );

class NotificationActivityRepository {
  NotificationActivityRepository(this.client);
  final SupabaseClient client;
  Future<DataPage<Json>> page(int page) async {
    final data = Json.from(
      await client.rpc(
        'dopmi_notification_activity',
        params: {'page_number': page, 'page_size': 20},
      ),
    );
    return DataPage(
      (data['items'] as List).map((v) => Json.from(v as Map)).toList(),
      (data['total'] as num).toInt(),
    );
  }

  Future<Json> open(String id) async => Json.from(
    await client.rpc(
      'dopmi_notification_open',
      params: {'notification_id': id},
    ),
  );
}

String? notificationActivityRoute(Json item) {
  if (item['available'] != true) return null;
  final id = item['target_id'];
  return switch (item['target_kind']) {
    'thread' when id is String => '/messages/$id',
    'post' when id is String => '/my-adoptions/$id',
    'rescue' when id is String => '/rescue/$id',
    'profile' => '/rescuer/profile/edit',
    'history' => '/payments',
    'received_history' => '/rescuer/received-payments',
    _ => null,
  };
}
