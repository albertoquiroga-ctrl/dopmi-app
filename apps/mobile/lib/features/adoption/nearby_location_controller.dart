import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../identity/experience_controller.dart';
import '../identity/identity_controller.dart';
import 'location_selection.dart';
import 'location_service.dart';

final nearbyLocationControllerProvider = Provider<NearbyLocationController>((
  ref,
) {
  final config = ref.watch(configProvider);
  final controller = NearbyLocationController(
    identity: ref.watch(identityControllerProvider),
    experience: ref.watch(experienceProvider),
    service: ref.watch(locationServiceProvider),
    isForeground: () => !const {
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    }.contains(WidgetsBinding.instance.lifecycleState),
    environment:
        '${config.environment}:${Uri.tryParse(config.url)?.host ?? ''}',
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// The adopter's device position stays in RAM. Pet publication has a separate map.
class NearbyLocationController extends ChangeNotifier {
  NearbyLocationController({
    required this.identity,
    required this.experience,
    required this.service,
    required this.environment,
    Future<SharedPreferences> Function()? preferences,
    bool Function()? isForeground,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _isForeground = isForeground ?? (() => true),
       ownerId = identity.identity?.id {
    _adopter = _adopterMode;
    identity.addListener(_identityChanged);
    experience.addListener(_experienceChanged);
    unawaited(_restore());
  }

  final IdentityController identity;
  final ExperienceController experience;
  final LocationService service;
  final String environment;
  final Future<SharedPreferences> Function() _preferences;
  final bool Function() _isForeground;
  String? ownerId;
  SelectedLocation? _selection;
  SelectedLocation? get selection => isAdopter ? _selection : null;
  int get radiusKm => nearbyDefaultRadiusKm;
  bool ready = false, promptSeen = false, busy = false, explaining = false;
  String? error;
  LocationSettingsTarget? _settingsTarget;
  bool _disposed = false, _automatic = false, _adopter = false;
  int _revision = 0, _ownerRevision = 0, _choiceRevision = 0;

  bool get _adopterMode =>
      ownerId != null &&
      identity.identity?.verified == true &&
      !identity.recovering &&
      !experience.loading &&
      experience.profile?.id == ownerId &&
      experience.value == AccountExperience.donor;
  bool get isAdopter => !_disposed && _adopter && _adopterMode;
  String get scope => '$environment:${ownerId ?? 'guest'}';
  // The previous v1 offer allowed a manual origin and was not this consent.
  String get _promptKey => 'dopmi.nearby.prompt.v2:$scope';
  String get _followKey => 'dopmi.nearby.follow-device.v2:$scope';
  Map<String, dynamic> get discoveryFilters => selection == null
      ? {}
      : {
          'latitude': selection!.latitude,
          'longitude': selection!.longitude,
          'radius_km': nearbyDefaultRadiusKm,
        };

  bool _sameRequest(int revision, String? actor) =>
      !_disposed &&
      revision == _revision &&
      ownerId == actor &&
      identity.identity?.id == actor;
  bool _current(int revision, String? actor) =>
      _sameRequest(revision, actor) && isAdopter && _isForeground();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _experienceChanged() {
    final next = _adopterMode;
    if (_disposed || _adopter == next) return;
    _adopter = next;
    cancelForegroundRefresh();
    _selection = null;
    error = null;
    _settingsTarget = null;
    _notify();
    if (next) unawaited(refreshIfAllowed());
  }

  void _identityChanged() {
    final actor = identity.identity?.id;
    if (actor == ownerId || _disposed) return;
    _revision++;
    _ownerRevision++;
    _choiceRevision++;
    ownerId = actor;
    _selection = null;
    ready = false;
    promptSeen = false;
    busy = false;
    _automatic = false;
    _adopter = _adopterMode;
    error = null;
    _settingsTarget = null;
    _notify();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final ownerRevision = _ownerRevision, actor = ownerId;
    final promptKey = _promptKey, followKey = _followKey;
    var seen = false, follow = false;
    try {
      final preferences = await _preferences();
      seen = preferences.getBool(promptKey) ?? false;
      follow = preferences.getBool(followKey) ?? false;
    } catch (_) {
      // In-memory consent still works when local preferences are unavailable.
    }
    if (_disposed || ownerRevision != _ownerRevision || ownerId != actor) {
      return;
    }
    promptSeen = seen;
    _automatic = seen && follow;
    ready = true;
    _notify();
    await refreshIfAllowed();
  }

  bool beginExplanation() {
    if (!ready || !isAdopter || !_isForeground() || explaining || busy) {
      return false;
    }
    explaining = true;
    return true;
  }

  void endExplanation() {
    explaining = false;
    _notify();
  }

  Future<bool> markPromptSeen({required String? expectedOwner}) async {
    if (!isAdopter || ownerId != expectedOwner) return false;
    final revision = _revision, key = _promptKey;
    promptSeen = true;
    _notify();
    try {
      await (await _preferences()).setBool(key, true);
    } catch (_) {
      // Do not repeatedly interrupt the current session if storage fails.
    }
    return _current(revision, expectedOwner);
  }

  Future<void> _rememberFollowChoice() async {
    final key = _followKey, choice = ++_choiceRevision;
    try {
      final preferences = await _preferences();
      if (_disposed || choice != _choiceRevision || key != _followKey) return;
      await preferences.setBool(key, _automatic);
    } catch (_) {
      // No coordinate is persisted, even when storage is unavailable.
    }
  }

  Future<void> requestCurrentLocation({required String? expectedOwner}) async {
    if (!isAdopter ||
        !_isForeground() ||
        !ready ||
        !promptSeen ||
        busy ||
        ownerId != expectedOwner) {
      return;
    }
    _automatic = true;
    unawaited(_rememberFollowChoice());
    if (_settingsTarget != null) {
      try {
        if (!await service.openSettings(_settingsTarget!)) {
          if (isAdopter && ownerId == expectedOwner) {
            error = 'Abre los ajustes del dispositivo y activa la ubicación para Dopmi.';
            _notify();
          }
        }
      } catch (_) {
        if (isAdopter && ownerId == expectedOwner) {
          error = 'Abre los ajustes del dispositivo y activa la ubicación para Dopmi.';
          _notify();
        }
      }
      return;
    }
    await _locate(requestPermission: true);
  }

  void cancelForegroundRefresh() {
    _revision++;
    busy = false;
  }

  /// A foreground refresh never opens an OS prompt, and never runs in Rescatista.
  Future<void> refreshIfAllowed() async {
    if (!isAdopter ||
        !_isForeground() ||
        !ready ||
        !promptSeen ||
        !_automatic ||
        busy) {
      return;
    }
    await _locate(requestPermission: false);
  }

  Future<void> _locate({required bool requestPermission}) async {
    final revision = ++_revision, actor = ownerId;
    busy = true;
    error = null;
    _selection = null;
    _notify();
    try {
      final result = await service.current(
        requestPermission: requestPermission,
      );
      if (!_current(revision, actor)) return;
      _selection = SelectedLocation(
        latitude: result.roundedLatitude,
        longitude: result.roundedLongitude,
        followDevice: true,
      );
      _settingsTarget = null;
    } catch (cause) {
      if (!_current(revision, actor)) return;
      error = cause is LocationException
          ? cause.message
          : 'No pudimos obtener tu ubicación. Inténtalo de nuevo.';
      _settingsTarget = cause is LocationException
          ? cause.settingsTarget
          : null;
    } finally {
      if (_sameRequest(revision, actor)) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    identity.removeListener(_identityChanged);
    experience.removeListener(_experienceChanged);
    _selection = null;
    super.dispose();
  }
}
