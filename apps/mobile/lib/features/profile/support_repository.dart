import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/media/media_store.dart';

typedef SupportRpc = Future<dynamic> Function(String, Map<String, dynamic>);

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository.supabase(),
);

class SupportRepository {
  SupportRepository(this.rpc, {this.upload});
  factory SupportRepository.supabase() {
    final client = Supabase.instance.client;
    return SupportRepository(
      (name, params) => client.rpc(name, params: params),
      upload: (requestId, bytes) =>
          MediaStore(client)
              .upload(requestId, bytes, MediaPurpose.supportAttachment),
    );
  }
  final SupportRpc rpc;
  final Future<String> Function(String, Uint8List)? upload;

  Future<String> uploadAttachment(String requestId, Uint8List bytes) {
    final uploader = upload;
    if (uploader == null) throw StateError('support_upload_unavailable');
    return uploader(requestId, bytes);
  }

  bool isReceipt(dynamic value, String requestId) =>
      value is Map &&
      value['request_id'] == requestId &&
      value['status'] == 'received';

  Future<void> submit({
    required String requestId,
    required String topic,
    required String message,
    String caseName = '',
    String? attachmentPath,
  }) async {
    final payload = {
      'topic': topic,
      'case_name': caseName.trim(),
      'message': message.trim(),
      if (attachmentPath != null && attachmentPath.isNotEmpty)
        'attachment_path': attachmentPath,
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
