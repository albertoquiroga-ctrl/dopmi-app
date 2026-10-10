import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adoption/community_repository.dart';

final paymentActivityRepositoryProvider = Provider<PaymentActivityRepository>(
  (ref) => PaymentActivityRepository(Supabase.instance.client),
);

class PaymentActivityRepository {
  PaymentActivityRepository(this.client);
  final SupabaseClient client;
  Future<Json> page({required bool received, Json? cursor}) async => Json.from(
    await client.rpc(
      'dopmi_payment_activity',
      params: {
        'received': received,
        'before_created_at': cursor?['created_at'],
        'before_kind': cursor?['kind'],
        'before_id': cursor?['id'],
        'page_size': 20,
      },
    ),
  );
  Future<Json> allocations(
    String cycle, {
    required bool received,
    String? afterExpense,
  }) async => Json.from(
    await client.rpc(
      'dopmi_payment_activity_allocations',
      params: {
        'target_cycle': cycle,
        'received': received,
        'after_expense': afterExpense,
        'page_size': 20,
      },
    ),
  );
}
