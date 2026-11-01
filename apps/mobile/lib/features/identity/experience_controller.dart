import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'identity_controller.dart';
import 'identity_repository.dart';

enum AccountExperience { donor, rescuer }

/// Only an explicit choice in the current authentication attempt can change mode.
String? authenticationExperienceIntent(String? intent) =>
    const ['adopt', 'donate', 'rescue'].contains(intent) ? intent : null;

class _AuthenticationExperience {
  _AuthenticationExperience(this.revision, this.mode, this.owner);
  final int revision;
  final String mode;
  String? owner;
}

final navigationSessionProvider = NotifierProvider<NavigationSession, int>(
  NavigationSession.new,
);

/// Recreate all branch navigators when an existing owner changes.
/// Initial session restoration keeps the incoming authentication/payment link.
class NavigationSession extends Notifier<int> {
  String location = '/welcome';
  void rememberLocation(String value) => location = value;
  @override
  int build() {
    final identity = ref.watch(identityControllerProvider);
    String? owner = identity.identity?.id;
    void changed() {
      final next = identity.identity?.id;
      if (owner != null && next != null && next != owner) state++;
      if (next != null) owner = next;
    }

    identity.addListener(changed);
    ref.onDispose(() => identity.removeListener(changed));
    return 0;
  }
}

final experienceProvider = Provider<ExperienceController>((ref) {
  final controller = ExperienceController(
    ref.watch(identityControllerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Presentation preference only; it never grants rescuer/admin privileges.
class ExperienceController extends ChangeNotifier {
  ExperienceController(this.identity) {
    identity.addListener(_identityChanged);
    _identityChanged();
  }
  final IdentityController identity;
  AccountExperience value = AccountExperience.donor;
  Profile? profile;
  bool loading = false;
  Object? authenticationError;
  String? _owner;
  int _revision = 0;
  int _authenticationRevision = 0;
  _AuthenticationExperience? _authenticationExperience;
  bool _disposed = false;

  /// Kept in memory until the authenticating account is known; never permissions.
  int prepareAuthentication(String? intent) {
    final revision = ++_authenticationRevision;
    _authenticationExperience = authenticationExperienceIntent(intent) == null
        ? null
        : _AuthenticationExperience(
            revision,
            intent == 'rescue' ? 'rescuer' : 'donor',
            identity.identity?.id,
          );
    authenticationError = null;
    return revision;
  }

  void cancelAuthentication(int revision, {bool onlyUnbound = false}) {
    final pending = _authenticationExperience;
    if (pending?.revision != revision ||
        (onlyUnbound && pending?.owner != null)) {
      return;
    }
    _authenticationExperience = null;
    authenticationError = null;
    if (_owner != null) {
      final revision = ++_revision;
      loading = profile == null;
      notifyListeners();
      if (loading) unawaited(_load(_owner!, revision));
    }
  }

  Future<void> retryAuthenticationExperience() async {
    final owner = _owner;
    if (owner == null || loading || _authenticationExperience == null) return;
    authenticationError = null;
    loading = true;
    notifyListeners();
    await _load(owner, ++_revision);
  }

  void _identityChanged() {
    final account = identity.identity?.id;
    final pending = _authenticationExperience;
    if (identity.recovering ||
        (pending != null &&
            pending.owner != null &&
            pending.owner != account)) {
      _authenticationExperience = null;
      authenticationError = null;
    } else if (pending != null && account != null) {
      pending.owner ??= account;
    }
    final owner =
        identity.loading ||
            identity.recovering ||
            identity.identity?.verified != true
        ? null
        : identity.identity?.id;
    if (_owner == owner) return;
    _owner = owner;
    final revision = ++_revision;
    value = AccountExperience.donor;
    profile = null;
    authenticationError = null;
    loading = owner != null;
    notifyListeners();
    if (owner != null) unawaited(_load(owner, revision));
  }

  Future<void> _load(String owner, int revision) async {
    try {
      final profile = await identity.repository.loadProfile().timeout(
        const Duration(seconds: 10),
      );
      if (!_disposed && _owner == owner && revision == _revision) {
        if (profile.id != owner) throw StateError('profile_owner_changed');
        applyProfile(profile);
      }
    } catch (cause) {
      // The profile page presents recoverable errors. Navigation stays usable.
      if (!_disposed && _owner == owner && revision == _revision) {
        if (_authenticationExperience?.owner == owner) {
          authenticationError = cause;
        }
        loading = false;
        notifyListeners();
      }
    }
  }

  void applyProfile(Profile profile) {
    if (_disposed || profile.id != _owner) return;
    final revision = ++_revision;
    this.profile = profile;
    value = profile.mode == 'rescuer'
        ? AccountExperience.rescuer
        : AccountExperience.donor;
    final pending = _authenticationExperience;
    loading = pending?.owner == _owner;
    authenticationError = null;
    if (loading) {
      unawaited(_applyAuthenticationExperience(profile, pending!, revision));
    }
    notifyListeners();
  }

  Future<void> _applyAuthenticationExperience(
    Profile profile,
    _AuthenticationExperience pending,
    int revision,
  ) async {
    bool current() =>
        !_disposed &&
        _owner == profile.id &&
        identity.repository.current?.id == profile.id &&
        identity.identity?.verified == true &&
        !identity.recovering &&
        revision == _revision &&
        identical(_authenticationExperience, pending);
    try {
      if (!current()) return;
      final confirmed = profile.mode == pending.mode
          ? profile
          : await identity.repository
                .setExperience(pending.mode)
                .timeout(const Duration(seconds: 10));
      if (!current()) return;
      if (confirmed.id != profile.id || confirmed.mode != pending.mode) {
        throw StateError('experience_not_acknowledged');
      }
      _authenticationExperience = null;
      applyProfile(confirmed);
    } catch (cause) {
      if (!current()) return;
      authenticationError = cause;
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    identity.removeListener(_identityChanged);
    super.dispose();
  }
}
