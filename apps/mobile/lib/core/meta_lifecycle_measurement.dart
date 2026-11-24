import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const metaLifecycleNoticeVersion = 'meta-lifecycle-2026-11-24';
const _appId = '1156849688851390';
const _packageName = 'com.mycompany.dopmi';
final _endpoint = Uri.https('graph.facebook.com', '/v27.0/$_appId/activities');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _version = RegExp(r'^[0-9]+(\.[0-9]+){1,3}([+-][0-9A-Za-z.-]+)?$');
final _osVersion = RegExp(r'^[0-9][0-9A-Za-z._+-]{0,23}$');
const _zeroId = '00000000-0000-0000-0000-000000000000';

/// Only approved wire fields survive the platform boundary. IDs stay in RAM.
class MetaLifecycleContext {
  const MetaLifecycleContext._(
    this.platform,
    this.advertisingId,
    this.version,
    this.build,
    this.osVersion,
    this.installEligible,
  );

  final String platform, advertisingId, version, osVersion;
  final int build;
  final bool installEligible;

  static MetaLifecycleContext? fromMap(Map<Object?, Object?>? fields) {
    if (fields == null) return null;
    final platform = fields['platform'];
    final id = fields['advertising_id'];
    final version = fields['app_version'];
    final build = fields['app_build'];
    final os = fields['os_version'];
    final eligible = fields['install_eligible'];
    if ((platform != 'android' && platform != 'ios') ||
        fields['package_name'] != _packageName ||
        fields['tracking_authorized'] != true ||
        id is! String ||
        !_uuid.hasMatch(id) ||
        id == _zeroId ||
        version is! String ||
        version.length > 24 ||
        !_version.hasMatch(version) ||
        build is! int ||
        build <= 0 ||
        build > 2100000000 ||
        os is! String ||
        !_osVersion.hasMatch(os) ||
        eligible is! bool) {
      return null;
    }
    return MetaLifecycleContext._(
      platform as String,
      id.toLowerCase(),
      version,
      build,
      os,
      eligible,
    );
  }

  List<String> get extinfo => [
    platform == 'android' ? 'a2' : 'i2',
    _packageName,
    '$build',
    version,
    osVersion,
    ...List.filled(11, ''),
  ];
}

abstract interface class MetaLifecycleNative {
  bool get available;
  Future<MetaLifecycleContext?> readContext();
  void cancel();
}

class MethodChannelMetaLifecycleNative implements MetaLifecycleNative {
  static const _channel = MethodChannel(
    'io.dopmi.app/meta_lifecycle_measurement',
  );

  @override
  bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<MetaLifecycleContext?> readContext() async {
    if (!available) return null;
    final fields = await _channel.invokeMapMethod<Object?, Object?>(
      'readContext',
    );
    return MetaLifecycleContext.fromMap(fields);
  }

  @override
  void cancel() {
    if (!available) return;
    unawaited(_channel.invokeMethod<void>('cancel').catchError((Object _) {}));
  }
}

abstract interface class MetaLifecycleTransport {
  Future<bool> post(Uri uri, Map<String, String> fields);
  void cancel();
  void dispose();
}

/// Dedicated clients let withdrawal cancel Meta without touching other traffic.
class MetaLifecycleHttpTransport implements MetaLifecycleTransport {
  MetaLifecycleHttpTransport({
    http.Client Function()? createClient,
    this.timeout = const Duration(seconds: 5),
  }) : _createClient = createClient ?? http.Client.new;

  final http.Client Function() _createClient;
  final Duration timeout;
  final _active = <http.Client>{};
  bool _disposed = false;

  @override
  Future<bool> post(Uri uri, Map<String, String> fields) async {
    if (_disposed || uri != _endpoint) return false;
    final client = _createClient();
    _active.add(client);
    try {
      return await (() async {
        final request = http.Request('POST', uri)
          ..followRedirects = false
          ..maxRedirects = 0
          ..bodyFields = fields;
        final response = await client.send(request);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return false;
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 32768) return false;
          bytes.addAll(chunk);
        }
        final result = jsonDecode(utf8.decode(bytes));
        return result is Map &&
            result['success'] == true &&
            result['error'] == null &&
            !result.containsKey('drop_reason');
      })().timeout(timeout);
    } catch (_) {
      // A timeout is ambiguous. This transport never retries or logs a payload.
      return false;
    } finally {
      _active.remove(client);
      client.close();
    }
  }

  @override
  void cancel() {
    final clients = _active.toList();
    _active.clear();
    for (final client in clients) {
      client.close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
  }
}

/// Device-scoped lifecycle permission is independent of GA and account CAPI.
class MetaLifecycleController extends ChangeNotifier {
  MetaLifecycleController(
    this.preferences,
    this.namespace, {
    required this.configured,
    required this.appId,
    required this.clientToken,
    required this.readGate,
    MetaLifecycleNative? native,
    MetaLifecycleTransport? transport,
    DateTime Function()? clock,
  }) : _native = native ?? MethodChannelMetaLifecycleNative(),
       _transport = transport ?? MetaLifecycleHttpTransport(),
       _clock = clock ?? DateTime.now;

  final SharedPreferences preferences;
  final String namespace, appId, clientToken;
  final bool configured;
  final Future<bool> Function() readGate;
  final MetaLifecycleNative _native;
  final MetaLifecycleTransport _transport;
  final DateTime Function() _clock;
  bool loading = true;
  bool _consent = false, _hasChoice = false, _storageReady = false;
  bool _seenSaved = false;
  bool _disposed = false, _foreground = false;
  bool _queuedForeground = false;
  bool _firstSession = false, _installClosed = false, _installAttempted = false;
  int _generation = 0, _choiceGeneration = 0;
  ({String event, bool accepted})? _lastDelivery;
  int? _activationAttempt;
  Future<void>? _initialization, _activeRun;
  Future<void> _writes = Future.value();

  bool get consent => _consent;
  ({String event, bool accepted})? get lastDelivery => _lastDelivery;
  bool get available =>
      !_disposed &&
      _storageReady &&
      configured &&
      namespace.trim().isNotEmpty &&
      appId == _appId &&
      RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(clientToken) &&
      _native.available;
  bool get needsChoice => available && !loading && !_hasChoice;

  String get _prefix => 'dopmi.$namespace.metaLifecycle.$_appId';
  String get _consentKey => '$_prefix.$metaLifecycleNoticeVersion.consent';
  String get _seenKey => '$_prefix.sessionSeen';
  String get _installKey => '$_prefix.installAttempted';
  String get _activationKey => '$_prefix.activationAttempt';

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final choiceGeneration = _choiceGeneration;
    try {
      if (_disposed) return;
      _firstSession = preferences.getBool(_seenKey) != true;
      _installAttempted = preferences.getBool(_installKey) == true;
      _activationAttempt = preferences.getInt(_activationKey);
      bool? saved;
      try {
        final raw = preferences.getString(_consentKey);
        if (raw != null) {
          final choice = jsonDecode(raw);
          if (choice is Map &&
              choice['notice'] == metaLifecycleNoticeVersion &&
              choice['consent'] is bool) {
            saved = choice['consent'] as bool;
          }
        }
      } catch (_) {
        // A malformed or old notice never authorizes collection.
      }
      if (!await preferences.setBool(_seenKey, true)) return;
      if (_disposed) return;
      _seenSaved = true;
      _storageReady = true;
      if (_choiceGeneration == choiceGeneration) {
        _hasChoice = saved != null;
        _consent = saved == true;
        if (saved == false) _installClosed = true;
      }
    } catch (_) {
      _storageReady = false;
      _consent = false;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Withdrawal takes effect in RAM before any storage operation can wait/fail.
  Future<void> setConsent(bool value) {
    if (_disposed) return Future.value();
    ++_generation;
    final choiceGeneration = ++_choiceGeneration;
    _consent = false;
    _lastDelivery = null;
    if (!value) _installClosed = true;
    _cancelPending();
    notifyListeners();
    final pending = _writes.then<void>((_) async {
      await initialize();
      if (_disposed) return;
      if (value && !available) throw StateError('meta_lifecycle_unavailable');
      try {
        final saved = await preferences.setString(
          _consentKey,
          jsonEncode({'notice': metaLifecycleNoticeVersion, 'consent': value}),
        );
        if (!saved) throw StateError('meta_lifecycle_preference_not_saved');
      } catch (_) {
        if (_choiceGeneration == choiceGeneration) {
          _storageReady = false;
          _consent = false;
        }
        rethrow;
      }
      if (_disposed || _choiceGeneration != choiceGeneration) return;
      _storageReady = _seenSaved;
      _hasChoice = true;
      _consent = value;
      notifyListeners();
    });
    _writes = pending.catchError((Object _) {});
    return pending;
  }

  bool _current(int generation) =>
      !_disposed &&
      !loading &&
      available &&
      _consent &&
      _foreground &&
      generation == _generation;

  bool _debounced() {
    final before = _activationAttempt;
    return before != null && _clock().millisecondsSinceEpoch - before < 60000;
  }

  Future<bool> _gate(int generation) async {
    if (!_current(generation)) return false;
    try {
      final enabled = await readGate().timeout(const Duration(seconds: 3));
      return enabled && _current(generation);
    } catch (_) {
      return false;
    }
  }

  Future<void> foreground() async {
    final generation = _generation;
    _foreground = true;
    await initialize();
    if (!_current(generation) || _debounced()) return;
    final active = _activeRun;
    if (active != null) {
      _queuedForeground = true;
      return active;
    }
    _queuedForeground = false;
    final pending = _measureForeground(generation);
    _activeRun = pending;
    return pending.whenComplete(() {
      if (identical(_activeRun, pending)) {
        _activeRun = null;
        _queuedForeground = false;
      }
    });
  }

  Future<void> _measureForeground(int generation) async {
    final before = _activationAttempt;
    await _measure(generation);
    if (_current(generation) &&
        _queuedForeground &&
        !_debounced() &&
        _activationAttempt == before) {
      // One overlapping resume may have arrived before a native read canceled
      // by an inactive transition completed. Re-evaluate once, never loop or
      // replay a persisted/ambiguous activation attempt.
      _queuedForeground = false;
      await _measure(generation);
    }
  }

  Future<void> _measure(int generation) async {
    try {
      if (!await _gate(generation)) return;
      final context = await _native.readContext().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _native.cancel();
          return null;
        },
      );
      if (context == null || !_current(generation)) return;
      final common = {
        'access_token': '$_appId|$clientToken',
        'application_tracking_enabled': '1',
        'advertiser_tracking_enabled': '1',
        'advertiser_id': context.advertisingId,
        'extinfo': jsonEncode(context.extinfo),
      };
      if (_firstSession &&
          !_installClosed &&
          !_installAttempted &&
          context.installEligible) {
        _installAttempted = true;
        if (!await preferences.setBool(_installKey, true)) return;
        if (!await _gate(generation)) return;
        await _post(generation, {...common, 'event': 'MOBILE_APP_INSTALL'});
      }
      if (!_current(generation) || _debounced()) return;
      final at = _clock().millisecondsSinceEpoch;
      _activationAttempt = at;
      if (!await preferences.setInt(_activationKey, at)) return;
      if (!await _gate(generation)) return;
      await _post(generation, {
        ...common,
        'event': 'CUSTOM_APP_EVENTS',
        'custom_events': jsonEncode([
          {'_eventName': 'fb_mobile_activate_app', '_logTime': at ~/ 1000},
        ]),
      });
    } catch (_) {
      // Optional measurement never changes navigation, auth or product writes.
    }
  }

  Future<void> _post(int generation, Map<String, String> fields) async {
    if (!_current(generation)) return;
    var accepted = false;
    try {
      accepted = await _transport
          .post(_endpoint, fields)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              _transport.cancel();
              return false;
            },
          );
    } catch (_) {
      // Attempt markers are retained: an uncertain delivery must not be replayed.
    }
    if (_current(generation)) {
      _lastDelivery = (event: fields['event']!, accepted: accepted);
      notifyListeners();
    }
  }

  void _cancelPending() {
    _activeRun = null;
    _queuedForeground = false;
    _native.cancel();
    _transport.cancel();
  }

  void background() {
    if (_disposed) return;
    _foreground = false;
    _installClosed = true;
    _generation++;
    _cancelPending();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _choiceGeneration++;
    _consent = false;
    _lastDelivery = null;
    _cancelPending();
    _transport.dispose();
    super.dispose();
  }
}
