import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SupportRpc = Future<dynamic> Function(String, Map<String, dynamic>);

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final client = Supabase.instance.client;
  return SupportRepository((name, params) => client.rpc(name, params: params));
});

class SupportRepository {
  SupportRepository(this.rpc);
  final SupportRpc rpc;

  bool isReceipt(dynamic value, String requestId) =>
      value is Map &&
      value['request_id'] == requestId &&
      value['status'] == 'received';

  Future<void> submit({
    required String requestId,
    required String topic,
    required String message,
    String caseName = '',
  }) async {
    final payload = {
      'topic': topic,
      'case_name': caseName.trim(),
      'message': message.trim(),
    };
    try {
      final receipt = await rpc('dopmi_submit_support_request', {
        'target_request': requestId,
        'payload': payload,
      });
      if (!isReceipt(receipt, requestId)) {
        throw StateError('support_receipt_mismatch');
      }
    } catch (cause, stack) {
      // Only transport uncertainty can be reconciled by an existing receipt.
      // A SQL rejection (including changed content) must remain a rejection.
      if (cause is PostgrestException) rethrow;
      if (cause is StateError) rethrow;
      try {
        final receipt = await rpc('dopmi_my_support_request', {
          'target_request': requestId,
          'expected_payload': payload,
        });
        if (isReceipt(receipt, requestId)) return;
      } catch (_) {
        // Retain the original failure; the UI keeps this request ID for retry.
      }
      Error.throwWithStackTrace(cause, stack);
    }
  }
}
