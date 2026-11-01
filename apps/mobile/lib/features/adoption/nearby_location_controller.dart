import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../identity/identity_controller.dart';
import 'location_selection.dart';
import 'location_service.dart';

final nearbyLocationControllerProvider = Provider<NearbyLocationController>((
  ref,
) {
  final config = ref.watch(configProvider);
  final controller = NearbyLocationController(
    identity: ref.watch(identityControllerProvider),
    service: ref.watch(locationServiceProvider),
    environment:
        '${config.environment}:${Uri.tryParse(config.url)?.host ?? ''}',
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Coordinates live only in RAM. Only scoped presentation/GPS choices persist.
class NearbyLocationController extends ChangeNotifier {
  NearbyLocationController({
    required this.identity,
    required this.service,
    required this.environment,
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       ownerId = identity.identity?.id {
    identity.addListener(_identityChanged);
    unawaited(_restore());
  }

  final IdentityController identity;
  final LocationService service;
  final String environment;
  final Future<SharedPreferences> Function() _preferences;
  String? ownerId;
  SelectedLocation? selection;
  int radiusKm = nearbyDefaultRadiusKm;
  bool ready = false, promptSeen = false;
  bool _disposed = false, _automatic = false;
  int _revision = 0;
  int _choiceRevision = 0;

  String get scope => '$environment:${ownerId ?? 'guest'}';
  String get _promptKey => 'dopmi.nearby.prompt.v1:$scope';
  String get _followKey => 'dopmi.nearby.follow-device.v1:$scope';
  Map<String, dynamic> get discoveryFilters => selection == null
      ? {}
      : {
          'latitude': selection!.latitude,
          'longitude': selection!.longitude,
          'radius_km': radiusKm,
        };

  bool _current(int revision, String? actor) =>
      !_disposed &&
      revision == _revision &&
      ownerId == actor &&
      identity.identity?.id == actor;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _identityChanged() {
    final actor = identity.identity?.id;
    if (actor == ownerId || _disposed) return;
    _revision++;
    _choiceRevision++;
    ownerId = actor;
    selection = null;
    radiusKm = nearbyDefaultRadiusKm;
    ready = false;
    promptSeen = false;
    _automatic = false;
    _notify();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final revision = _revision, actor = ownerId;
    final promptKey = _promptKey, followKey = _followKey;
    var seen = false, follow = false;
    try {
      final preferences = await _preferences();
      seen = preferences.getBool(promptKey) ?? false;
      follow = preferences.getBool(followKey) ?? false;
    } catch (_) {
      /* Storage failure never blocks exploration. */
    }
    if (!_current(revision, actor)) return;
    promptSeen = seen;
    _automatic = seen && follow;
    ready = true;
    _notify();
    if (seen) await refreshIfAllowed();
  }

  Future<bool> markPromptSeen({required String? expectedOwner}) async {
    if (_disposed ||
        ownerId != expectedOwner ||
        identity.identity?.id != expectedOwner) {
      return false;
    }
    final revision = _revision, key = _promptKey;
    promptSeen = true;
    _notify();
    try {
      await (await _preferences()).setBool(key, true);
    } catch (_) {
      /* The in-memory flag still prevents a repeated prompt. */
    }
    return _current(revision, expectedOwner);
  }

  bool replace(
    SelectedLocation? value, {
    required String? expectedOwner,
    int? radius,
  }) {
    if (_disposed ||
        ownerId != expectedOwner ||
        identity.identity?.id != expectedOwner) {
      return false;
    }
    _revision++;
    selection = value;
    radiusKm = (radius ?? radiusKm).clamp(1, 30).toInt();
    _automatic = value?.followDevice ?? false;
    unawaited(_rememberFollowChoice(_followKey, _automatic, ++_choiceRevision));
    _notify();
    return true;
  }

  Future<void> _rememberFollowChoice(
    String key,
    bool follow,
    int choice,
  ) async {
    try {
      final preferences = await _preferences();
      if (_disposed || choice != _choiceRevision || key != _followKey) return;
      await preferences.setBool(key, follow);
    } catch (_) {
      // Keep the current-session choice. Persistence can be unavailable; a
      // previous stored preference may remain for the next app start.
    }
  }

  void cancelForegroundRefresh() {
    _revision++;
  }

  /// Foreground refresh never opens an OS permission prompt. A denied permission
  /// leaves manual browsing available and never restores another actor's zone.
  Future<void> refreshIfAllowed() async {
    if (_disposed || !ready || !promptSeen || !_automatic) return;
    final revision = ++_revision, actor = ownerId;
    try {
      final result = await service.current(requestPermission: false);
      if (!_current(revision, actor)) return;
      selection = SelectedLocation(
        latitude: result.roundedLatitude,
        longitude: result.roundedLongitude,
        followDevice: true,
      );
      _notify();
    } catch (_) {
      /* Manual map selection and city search remain available. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    identity.removeListener(_identityChanged);
    selection = null;
    super.dispose();
  }
}
