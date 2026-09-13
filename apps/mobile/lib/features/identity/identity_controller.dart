import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import 'identity_repository.dart';

final configProvider = Provider<AppConfig>((ref) => AppConfig.environment());
final identityRepositoryProvider = Provider<IdentityRepository>(
  (ref) => throw StateError('Repository not configured'),
);
final identityControllerProvider = Provider<IdentityController>((ref) {
  final controller = IdentityController(ref.watch(identityRepositoryProvider));
  ref.onDispose(controller.dispose);
  unawaited(controller.initialize());
  return controller;
});

class IdentityController extends ChangeNotifier {
  IdentityController(this.repository);
  final IdentityRepository repository;
  StreamSubscription<IdentityEvent>? _subscription;
  Identity? identity;
  bool loading = true, recovering = false;
  Object? error;
  bool _disposed = false;
  int _revision = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    _notify();
    try {
      recovering = await repository.recoveryPending();
      if (_disposed) return;
      _subscription ??= repository.events.listen(
        (event) {
          _revision++;
          identity = event.identity;
          if (event.recovery) recovering = true;
          if (event.signedOut) recovering = false;
          if (event.recovery || event.signedOut) {
            unawaited(
              repository.rememberRecovery(recovering).catchError((
                Object failure,
              ) {
                error = failure;
                _notify();
              }),
            );
          }
          error = null;
          _notify();
        },
        onError: (Object failure) {
          error = failure;
          loading = false;
          _notify();
        },
      );
      final revision = _revision;
      final restored = await repository.restore();
      if (_revision == revision) identity = restored;
      if (identity == null) recovering = false;
    } catch (failure) {
      error = failure;
    }
    loading = false;
    _notify();
  }

  Future<void> completeRecovery(String password) async {
    if (!recovering || identity == null) {
      throw StateError('recovery_session_required');
    }
    await repository.updatePassword(password);
    // Keep recovery mode until sign-out succeeds. Never fall through to the profile.
    await logout();
  }

  Future<void> logout() async {
    await repository.logout();
    await repository.rememberRecovery(false);
    recovering = false;
    identity = null;
    error = null;
    _notify();
  }

  String? redirect(String path) {
    if (loading) return path == '/loading' ? null : '/loading';
    if (error != null) return path == '/auth-error' ? null : '/auth-error';
    if (identity != null && recovering) {
      return path == '/reset-password' ? null : '/reset-password';
    }
    if (identity?.verified == true) {
      return path == '/profile' || path == '/terms' ? null : '/profile';
    }
    if (path == '/profile' ||
        path == '/reset-password' ||
        path == '/loading' ||
        path == '/auth-error') {
      return '/welcome';
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
