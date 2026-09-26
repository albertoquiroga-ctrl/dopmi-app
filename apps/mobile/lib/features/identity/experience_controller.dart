import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'identity_controller.dart';
import 'identity_repository.dart';

enum AccountExperience { donor, rescuer }

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
  bool loading = false;
  String? _owner;
  int _revision = 0;
  bool _disposed = false;

  void _identityChanged() {
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
    } catch (_) {
      // The profile page presents recoverable errors. Navigation stays usable.
      if (!_disposed && _owner == owner && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void applyProfile(Profile profile) {
    if (_disposed || profile.id != _owner) return;
    _revision++;
    loading = false;
    value = profile.mode == 'rescuer'
        ? AccountExperience.rescuer
        : AccountExperience.donor;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    identity.removeListener(_identityChanged);
    super.dispose();
  }
}
