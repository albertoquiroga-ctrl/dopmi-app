import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final socialVerificationRepositoryProvider =
    Provider<SocialVerificationRepository>(
      (ref) => SupabaseSocialVerificationRepository(Supabase.instance.client),
    );

abstract class SocialVerificationRepository {
  String? get owner;
  Future<Map<String, dynamic>> call(Map<String, dynamic> input);
}

class SupabaseSocialVerificationRepository
    implements SocialVerificationRepository {
  SupabaseSocialVerificationRepository(this.client);
  final SupabaseClient client;
  @override
  String? get owner => client.auth.currentUser?.id;

  String? get _sessionId {
    final token = client.auth.currentSession?.accessToken;
    if (token == null) return null;
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map<String, dynamic>;
      return claims['session_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    final actor = owner;
    final session = _sessionId;
    if (actor == null || session == null) throw StateError('sign_in_required');
    final response = await client.functions.invoke(
      'social-verification',
      body: input,
    );
    if (owner != actor || _sessionId != session) {
      throw StateError('session_changed');
    }
    if (response.status != 200 || response.data is! Map) {
      throw StateError('invalid_response');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}

/// Never open a URL supplied by a callback, profile field or another provider.
Uri socialAuthorizationUri(String provider, Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.fragment.isNotEmpty) {
    throw const FormatException('invalid_authorization_url');
  }
  final valid = switch (provider) {
    'facebook' =>
      uri.host == 'www.facebook.com' &&
          RegExp(r'^/v[0-9]+\.[0-9]+/dialog/oauth/?$').hasMatch(uri.path),
    'instagram' =>
      uri.host == 'www.instagram.com' &&
          RegExp(r'^/oauth/authorize/?$').hasMatch(uri.path),
    _ => false,
  };
  if (!valid ||
      (uri.queryParameters['state'] ?? '').isEmpty ||
      uri.queryParameters['response_type'] != 'code') {
    throw const FormatException('invalid_authorization_url');
  }
  return uri;
}
