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

/// Role-scoped device positions stay in RAM; pet selections remain editable.
class NearbyLocationController extends ChangeNotifier {
  NearbyLocationController({
    required this.identity,
    required this.experience,
    required this.service,
    required this.environment,
    Future<SharedPreferences> Function()? preferences,
    bool Function()? isForeground,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _isForeground = isForeground ?? (() => true),
       _now = now ?? DateTime.now,
       ownerId = identity.identity?.id {
    _role = _currentRole;
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
  final DateTime Function() _now;
  String? ownerId;
  SelectedLocation? _selection;
  DateTime? _selectionObtainedAt;
  SelectedLocation? get selection =>
      isAdopter && _isForeground() ? _selection : null;
  SelectedLocation? get publicationDefault =>
      isRescuer && _isForeground() && _hasFreshPublicationFix
      ? _selection
      : null;
  bool get _hasFreshPublicationFix {
    final obtained = _selectionObtainedAt;
    if (obtained == null) return false;
    final age = _now().difference(obtained);
    return age >= Duration.zero && age <= const Duration(seconds: 30);
  }

  int get radiusKm => nearbyDefaultRadiusKm;
  bool ready = false, promptSeen = false, busy = false, explaining = false;
  String? error;
  LocationSettingsTarget? _settingsTarget;
  bool _disposed = false, _automatic = false;
  AccountExperience? _role;
  int _revision = 0, _scopeRevision = 0, _choiceRevision = 0;

  AccountExperience? get _currentRole =>
      ownerId != null &&
          identity.identity?.verified == true &&
          !identity.recovering &&
          !experience.loading &&
          experience.profile?.id == ownerId
      ? experience.value
      : null;
  AccountExperience? get locationRole =>
      !_disposed && _role == _currentRole ? _role : null;
  bool get canUseLocation => locationRole != null;
  bool get isAdopter => locationRole == AccountExperience.donor;
  bool get isRescuer => locationRole == AccountExperience.rescuer;
  String get scope => '$environment:${ownerId ?? 'guest'}';
  // Preserve the adopter consent; the rescuer purpose has its own first offer.
  String get _promptKey => isRescuer
      ? 'dopmi.rescuer-location.prompt.v1:$scope'
      : 'dopmi.nearby.prompt.v2:$scope';
  String get _followKey => isRescuer
      ? 'dopmi.rescuer-location.follow-device.v1:$scope'
      : 'dopmi.nearby.follow-device.v2:$scope';
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
      _sameRequest(revision, actor) && canUseLocation && _isForeground();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _resetScope() {
    _revision++;
    _scopeRevision++;
    _choiceRevision++;
    _selection = null;
    _selectionObtainedAt = null;
    ready = false;
    promptSeen = false;
    busy = false;
    _automatic = false;
    error = null;
    _settingsTarget = null;
    _notify();
    unawaited(_restore());
  }

  void _experienceChanged() {
    final next = _currentRole;
    if (_disposed || _role == next) return;
    _role = next;
    _resetScope();
  }

  void _identityChanged() {
    if (_disposed) return;
    final actor = identity.identity?.id;
    if (actor == ownerId) {
      _experienceChanged();
      return;
    }
    ownerId = actor;
    _role = _currentRole;
    _resetScope();
  }

  Future<void> _restore() async {
    final scopeRevision = _scopeRevision, actor = ownerId, role = locationRole;
    if (role == null) return;
    final promptKey = _promptKey, followKey = _followKey;
    var seen = false, follow = false;
    try {
      final preferences = await _preferences();
      seen = preferences.getBool(promptKey) ?? false;
      follow = preferences.getBool(followKey) ?? false;
    } catch (_) {
      // In-memory consent still works when local preferences are unavailable.
    }
    if (_disposed ||
        scopeRevision != _scopeRevision ||
        ownerId != actor ||
        locationRole != role) {
      return;
    }
    promptSeen = seen;
    _automatic = seen && follow;
    ready = true;
    _notify();
    await refreshIfAllowed();
  }

  bool beginExplanation() {
    if (!ready || !canUseLocation || !_isForeground() || explaining || busy) {
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
    if (!canUseLocation || ownerId != expectedOwner) return false;
    final scopeRevision = _scopeRevision, role = locationRole, key = _promptKey;
    promptSeen = true;
    _notify();
    try {
      await (await _preferences()).setBool(key, true);
    } catch (_) {
      // Do not repeatedly interrupt the current session if storage fails.
    }
    return !_disposed &&
        scopeRevision == _scopeRevision &&
        ownerId == expectedOwner &&
        locationRole == role;
  }

  Future<void> _rememberFollowChoice() async {
    final key = _followKey, choice = ++_choiceRevision, follow = _automatic;
    try {
      final preferences = await _preferences();
      if (_disposed || choice != _choiceRevision || key != _followKey) return;
      await preferences.setBool(key, follow);
    } catch (_) {
      // No coordinate is persisted, even when storage is unavailable.
    }
  }

  Future<void> requestCurrentLocation({required String? expectedOwner}) async {
    if (!canUseLocation ||
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
      final scopeRevision = _scopeRevision;
      try {
        if (!await service.openSettings(_settingsTarget!)) {
          if (canUseLocation &&
              ownerId == expectedOwner &&
              scopeRevision == _scopeRevision) {
            error = 'Abre los ajustes del dispositivo y activa la ubicación para Dopmi.';
            _notify();
          }
        }
      } catch (_) {
        if (canUseLocation &&
            ownerId == expectedOwner &&
            scopeRevision == _scopeRevision) {
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
    _selection = null;
    _selectionObtainedAt = null;
    _notify();
  }

  /// Refresh only after this role opted in; never open an OS permission prompt.
  Future<void> refreshIfAllowed() async {
    if (!canUseLocation ||
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
    _selectionObtainedAt = null;
    _notify();
    try {
      final result = await service.current(
        requestPermission: requestPermission,
      );
      if (!_current(revision, actor)) return;
      _selection = SelectedLocation(
        latitude: result.latitude,
        longitude: result.longitude,
        followDevice: true,
      );
      _selectionObtainedAt = _now();
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
    _selectionObtainedAt = null;
    super.dispose();
  }
}
