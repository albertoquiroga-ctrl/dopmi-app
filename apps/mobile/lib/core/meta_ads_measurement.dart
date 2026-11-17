import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/identity/identity_controller.dart';
import '../features/identity/identity_repository.dart';

const _channel = MethodChannel('io.dopmi.app/meta_ads_measurement');
const _lookupTimeout = Duration(milliseconds: 1500);
const _zeroId = '00000000-0000-0000-0000-000000000000';
final _advertisingIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _osVersionPattern = RegExp(r'^[0-9][0-9A-Za-z._+-]{0,23}$');
final _appVersionPattern = RegExp(
  r'^[0-9]+(\.[0-9]+){1,3}([+-][0-9A-Za-z.-]+)?$',
);

final metaAdsPreferenceServiceProvider = Provider<MetaAdsMeasurement?>((ref) {
  final repository = ref.watch(identityRepositoryProvider);
  return repository is SupabaseIdentityRepository
      ? MetaAdsMeasurement(repository.client)
      : null;
});

final metaAdsMeasurementProvider = Provider<MetaAdsMeasurement?>((ref) {
  if (!ref.watch(configProvider).metaAdsMeasurementEnabled ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  return ref.watch(metaAdsPreferenceServiceProvider);
});

final metaAdsPreferenceProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, owner) async {
      final measurement = ref.watch(metaAdsPreferenceServiceProvider);
      return measurement == null ? false : measurement.preference(owner);
    });

enum MetaAdsAction {
  adoptionMessage('first_adoption_message'),
  adoptionSubmission('first_adoption_submission');

  const MetaAdsAction(this.kind);
  final String kind;
}

class AndroidAdvertisingContext {
  const AndroidAdvertisingContext._(
    this.advertisingId,
    this.osVersion,
    this.appVersion,
    this.appBuild,
  );

  final String advertisingId;
  final String osVersion;
  final String appVersion;
  final int appBuild;

  static Future<AndroidAdvertisingContext?> read() async {
    final fields = await _channel.invokeMapMethod<String, Object>(
      'getAdvertisingContext',
    );
    if (fields == null) return null;
    final id = fields['advertising_id'];
    final os = fields['os_version'];
    final version = fields['app_version'];
    final build = fields['app_build'];
    if (id is! String ||
        id == _zeroId ||
        !_advertisingIdPattern.hasMatch(id) ||
        os is! String ||
        !_osVersionPattern.hasMatch(os) ||
        version is! String ||
        version.length > 24 ||
        !_appVersionPattern.hasMatch(version) ||
        build is! int ||
        build <= 0 ||
        build > 2100000000) {
      return null;
    }
    return AndroidAdvertisingContext._(id.toLowerCase(), os, version, build);
  }

  Map<String, Object> toRpc() => {
    'advertising_id': advertisingId,
    'os_version': osVersion,
    'app_version': appVersion,
    'app_build': appBuild,
  };
}

class MetaAdsMeasurement {
  MetaAdsMeasurement(this.client);

  final SupabaseClient client;
  int _revision = 0;
  String? _changingOwner;
  final _deniedOwners = <String>{};

  Session? _sessionFor(String owner) {
    final session = client.auth.currentSession;
    return session?.user.id == owner ? session : null;
  }

  Future<bool> preference(String owner) async {
    final session = _sessionFor(owner);
    if (session == null) return false;
    try {
      final allowed = await client
          .rpc('dopmi_meta_ads_preference')
          .setHeader('Authorization', 'Bearer ${session.accessToken}');
      return _sessionFor(owner) != null && allowed == true;
    } on PostgrestException catch (failure) {
      if (failure.code != 'PGRST202') rethrow;
      return false;
    }
  }

  Future<bool> setPreference(String owner, bool enabled) async {
    final session = _sessionFor(owner);
    if (session == null) throw StateError('La sesión cambió.');
    if (_changingOwner != null) {
      throw StateError('Estamos guardando otra preferencia.');
    }
    _changingOwner = owner;
    _revision++;
    if (!enabled) _deniedOwners.add(owner);
    try {
      final allowed = await client
          .rpc('dopmi_set_meta_ads_preference', params: {'enabled': enabled})
          .setHeader('Authorization', 'Bearer ${session.accessToken}');
      if (_sessionFor(owner) == null) throw StateError('La sesión cambió.');
      if (allowed is! bool) {
        throw StateError('No pudimos confirmar tu preferencia.');
      }
      if (allowed == enabled) _deniedOwners.remove(owner);
      return allowed;
    } finally {
      _changingOwner = null;
    }
  }

  Future<AndroidAdvertisingContext?> _contextFor(
    String owner,
    int revision,
    MetaAdsAction action,
    String targetId,
  ) async {
    bool current() =>
        _sessionFor(owner) != null &&
        _revision == revision &&
        _changingOwner != owner &&
        !_deniedOwners.contains(owner);
    try {
      final session = _sessionFor(owner);
      if (session == null || !current()) return null;
      final eligible = await client
          .rpc(
            'dopmi_meta_ads_action_eligible',
            params: {'p_event_kind': action.kind, 'p_target_id': targetId},
          )
          .setHeader('Authorization', 'Bearer ${session.accessToken}')
          .timeout(_lookupTimeout);
      if (eligible != true || !current()) return null;
      final context = await AndroidAdvertisingContext.read().timeout(
        _lookupTimeout,
      );
      return current() ? context : null;
    } catch (_) {
      // Optional attribution must never prevent sending or submitting.
      return null;
    }
  }

  Future<dynamic> runProductRpc({
    required String legacy,
    required String measured,
    required Map<String, Object?> params,
    required MetaAdsAction action,
    required String targetId,
    Map<String, Object?> measuredOnly = const {},
  }) async {
    final initialSession = client.auth.currentSession;
    if (initialSession == null) return client.rpc(legacy, params: params);
    final owner = initialSession.user.id;

    Future<dynamic> runLegacyForOwner() async {
      if (_sessionFor(owner) == null) throw StateError('La sesión cambió.');
      final current = await client.auth.getSession();
      if (current?.user.id != owner || _sessionFor(owner) == null) {
        throw StateError('La sesión cambió.');
      }
      return client
          .rpc(legacy, params: params)
          .setHeader('Authorization', 'Bearer ${current!.accessToken}');
    }

    if (initialSession.isExpired) return runLegacyForOwner();
    final revision = _revision;
    final context = await _contextFor(owner, revision, action, targetId);
    final session = _sessionFor(owner);
    if (session == null) throw StateError('La sesión cambió.');
    if (context == null || _revision != revision || session.isExpired) {
      return runLegacyForOwner();
    }
    try {
      return await client
          .rpc(
            measured,
            params: {
              ...params,
              ...measuredOnly,
              'advertising_context': context.toRpc(),
            },
          )
          .setHeader('Authorization', 'Bearer ${session.accessToken}');
    } on PostgrestException catch (failure) {
      // Missing function means the underlying operation never started.
      if (failure.code != 'PGRST202') rethrow;
      return runLegacyForOwner();
    }
  }
}
