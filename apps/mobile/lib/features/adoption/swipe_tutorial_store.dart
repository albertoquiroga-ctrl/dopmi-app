import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';

const _metadataKey = 'dopmi_swipe_tutorial_v1';

abstract class SwipeTutorialStore {
  Future<bool> completed(String actor);
  Future<void> complete(String actor);
}

final swipeTutorialStoreProvider = Provider<SwipeTutorialStore>((ref) {
  final repository = ref.watch(identityRepositoryProvider);
  if (repository is! SupabaseIdentityRepository) {
    return const _DisabledSwipeTutorialStore();
  }
  final transport = http.Client();
  ref.onDispose(transport.close);
  return SupabaseSwipeTutorialStore(
    config: repository.config,
    preferences: repository.preferences,
    currentActor: () => repository.client.auth.currentUser?.id,
    accessToken: () => repository.client.auth.currentSession?.accessToken,
    transport: transport,
  );
});

/// The deletion flow can remove exactly this account's presentation receipt.
String swipeTutorialPreferenceKey(AppConfig config, String actor) =>
    'dopmi.swipe_tutorial_v1.${config.environment}:${Uri.parse(config.url).host}:$actor';

class _DisabledSwipeTutorialStore implements SwipeTutorialStore {
  const _DisabledSwipeTutorialStore();

  @override
  Future<bool> completed(String actor) async => true;

  @override
  Future<void> complete(String actor) async {}
}

/// This is a UI hint, never an authorization or consent decision. Auth calls use
/// the captured actor's token directly so a late reply cannot mutate SDK session.
class SupabaseSwipeTutorialStore implements SwipeTutorialStore {
  SupabaseSwipeTutorialStore({
    required AppConfig config,
    required this.preferences,
    required this.currentActor,
    required this.accessToken,
    required this.transport,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _config = config,
       _userUri = Uri.parse(config.url).resolve('/auth/v1/user');

  final AppConfig _config;
  final SharedPreferences preferences;
  final Duration requestTimeout;
  final String? Function() currentActor;
  final String? Function() accessToken;
  final http.Client transport;
  final Uri _userUri;

  ({String actor, String? token}) _snapshot(String actor) {
    _assertCurrent(actor);
    final token = accessToken();
    _assertCurrent(actor);
    return (actor: actor, token: token);
  }

  void _assertCurrent(String actor) {
    if (actor.isEmpty || currentActor() != actor) {
      throw StateError('swipe_tutorial_actor_changed');
    }
  }

  ({bool completed, bool pending})? _readReceipt(String actor) {
    final value = preferences.getString(
      swipeTutorialPreferenceKey(_config, actor),
    );
    if (value == null) return null;
    try {
      final receipt = jsonDecode(value);
      if (receipt is Map<String, dynamic> && receipt['completed'] == true) {
        return (completed: true, pending: receipt['pending'] == true);
      }
    } on FormatException {
      // A malformed presentation cache is replaceable by a fresh Auth read.
    }
    return null;
  }

  Future<void> _saveReceipt(String actor, {required bool pending}) async {
    _assertCurrent(actor);
    final saved = await preferences.setString(
      swipeTutorialPreferenceKey(_config, actor),
      jsonEncode({'completed': true, 'pending': pending}),
    );
    _assertCurrent(actor);
    if (!saved) throw StateError('swipe_tutorial_local_write_failed');
  }

  Future<bool> _request(
    ({String actor, String? token}) snapshot, {
    required bool upload,
  }) async {
    _assertCurrent(snapshot.actor);
    final token = snapshot.token;
    if (token == null || token.isEmpty) {
      throw StateError('swipe_tutorial_session_unavailable');
    }
    final headers = {
      'apikey': _config.key,
      'authorization': 'Bearer $token',
      if (upload) 'content-type': 'application/json',
    };
    final http.Response response;
    try {
      response =
          await (upload
                  ? transport.put(
                      _userUri,
                      headers: headers,
                      // Auth merges this one owned hint with existing metadata.
                      body: jsonEncode({
                        'data': {_metadataKey: true},
                      }),
                    )
                  : transport.get(_userUri, headers: headers))
              .timeout(requestTimeout);
    } on TimeoutException {
      _assertCurrent(snapshot.actor);
      rethrow;
    } catch (_) {
      _assertCurrent(snapshot.actor);
      throw const FormatException('swipe_tutorial_request_failed');
    }
    _assertCurrent(snapshot.actor);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('swipe_tutorial_request_failed');
    }
    final Object? user;
    try {
      user = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('swipe_tutorial_invalid_response');
    }
    if (user is! Map<String, dynamic> || user['id'] != snapshot.actor) {
      throw StateError('swipe_tutorial_actor_changed');
    }
    final metadata = user['user_metadata'];
    if (metadata != null && metadata is! Map<String, dynamic>) {
      throw const FormatException('swipe_tutorial_invalid_response');
    }
    return metadata is Map<String, dynamic> && metadata[_metadataKey] == true;
  }

  Future<void> _syncPending(({String actor, String? token}) snapshot) async {
    try {
      final acknowledged = await _request(snapshot, upload: true);
      if (acknowledged) {
        await _saveReceipt(snapshot.actor, pending: false);
      }
    } catch (_) {
      // A failed upload preserves the local close and retries on next access.
      // Stale work still stops here instead of completing for a newer account.
      _assertCurrent(snapshot.actor);
    }
  }

  @override
  Future<bool> completed(String actor) async {
    final snapshot = _snapshot(actor);
    final receipt = _readReceipt(actor);
    if (receipt != null && receipt.completed) {
      if (receipt.pending) await _syncPending(snapshot);
      _assertCurrent(actor);
      return true;
    }
    final remoteCompleted = await _request(snapshot, upload: false);
    if (remoteCompleted) await _saveReceipt(actor, pending: false);
    _assertCurrent(actor);
    return remoteCompleted;
  }

  @override
  Future<void> complete(String actor) async {
    final snapshot = _snapshot(actor);
    await _saveReceipt(actor, pending: true);
    await _syncPending(snapshot);
    _assertCurrent(actor);
  }
}
