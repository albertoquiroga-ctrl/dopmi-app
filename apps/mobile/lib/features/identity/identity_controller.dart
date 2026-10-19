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
  IdentityController(this.repository) : identity = repository.current;
  final IdentityRepository repository;
  StreamSubscription<IdentityEvent>? _subscription;
  Identity? identity;
  bool loading = true, recovering = false;
  String recoveryIntent = 'adopt';
  String? recoveryEmail;
  String? _recoveryActor;
  Object? error;
  bool _disposed = false;
  int _revision = 0;
  int _recoveryPresentationRevision = 0;

  Future<void> prepareRecoveryPresentation(String intent, String email) async {
    _recoveryPresentationRevision++;
    recoveryIntent = safeRecoveryIntent(intent);
    recoveryEmail = email.trim();
    await repository.rememberRecoveryIntent(recoveryIntent);
  }

  Future<void> clearRecoveryPresentation() async {
    _recoveryPresentationRevision++;
    recoveryIntent = 'adopt';
    recoveryEmail = null;
    await repository.rememberRecoveryIntent(null);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    _notify();
    try {
      recovering = await repository.recoveryPending();
      if (recovering) _recoveryActor = identity?.id;
      if (_disposed) return;
      _subscription ??= repository.events.listen(
        (event) {
          _revision++;
          final previousActor = identity?.id ?? _recoveryActor;
          final ownerChanged =
              !event.recovery &&
              event.identity != null &&
              previousActor != null &&
              event.identity!.id != previousActor;
          identity = event.identity;
          if (event.recovery) {
            recovering = true;
            _recoveryActor = event.identity?.id;
            final email = event.identity?.email;
            if (email != null && email.isNotEmpty) recoveryEmail = email;
          }
          // A transient null identity can precede passwordRecovery. Clear only
          // an explicit sign-out, not that intermediate restoration event.
          if (event.signedOut || ownerChanged) {
            recovering = false;
            _recoveryActor = null;
            unawaited(
              clearRecoveryPresentation().catchError((Object failure) {
                error = failure;
                _notify();
              }),
            );
          }
          if (event.recovery || event.signedOut || ownerChanged) {
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
      final presentationRevision = _recoveryPresentationRevision;
      final storedIntent = await repository.recoveryIntent();
      if (_recoveryPresentationRevision == presentationRevision) {
        recoveryIntent = safeRecoveryIntent(storedIntent);
      }
      final restored = await repository.restore();
      if (_revision == revision) identity = restored;
      if (identity == null) recovering = false;
      if (recovering) _recoveryActor ??= identity?.id;
    } catch (failure) {
      error = failure;
    }
    loading = false;
    _notify();
  }

  Future<void> completeRecovery(String password) async {
    if (!recovering ||
        identity == null ||
        repository.current?.id != identity!.id ||
        _recoveryActor != identity!.id) {
      throw StateError('recovery_session_required');
    }
    final actor = identity!.id;
    await repository.updatePassword(password);
    if (!recovering ||
        identity?.id != actor ||
        repository.current?.id != actor) {
      throw StateError('recovery_session_required');
    }
    // Keep recovery mode until sign-out succeeds. Never fall through to the profile.
    await logout();
  }

  Future<void> logout() async {
    await repository.logout();
    await repository.rememberRecovery(false);
    await clearRecoveryPresentation();
    recovering = false;
    _recoveryActor = null;
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
    // Existing owners retain cancellation access if email confirmation lapses.
    // PostgreSQL still rejects activation/amount increases without confirmation.
    if (identity != null &&
        (path == '/guardian' || path == '/guardian/history')) {
      return null;
    }
    if (identity?.verified == true) {
      const accountRoutes = [
        '/home',
        '/profile',
        '/basic-info',
        '/settings',
        '/account-privacy',
        '/consent',
        '/help',
        '/about',
        '/transparency',
        '/publish',
        '/terms',
        '/privacy-notice',
        '/saved',
        '/store',
        '/saved-rescuers',
        '/impact',
        '/my-adoptions',
        '/messages',
        '/my-conversations',
        '/notifications',
        '/rescuer',
        '/my-cases',
        '/rescue',
        '/rescue-file',
        '/rescue-cases',
        '/contribute',
        '/contribute-case',
        '/payments',
        '/connect',
      ];
      final allowed =
          accountRoutes.any(
            (route) => path == route || path.startsWith('$route/'),
          ) ||
          path == '/adoptions' ||
          path.startsWith('/adoptions/') ||
          path.startsWith('/people/');
      return allowed ? null : '/adoptions';
    }
    if (path == '/home' ||
        path == '/profile' ||
        path.startsWith('/profile/') ||
        path == '/basic-info' ||
        path == '/settings' ||
        path.startsWith('/settings/') ||
        path == '/account-privacy' ||
        path == '/consent' ||
        path == '/help' ||
        path == '/publish' ||
        path == '/guardian' ||
        path == '/guardian/history' ||
        path == '/payments' ||
        path == '/connect' ||
        path.startsWith('/contribute/') ||
        path.startsWith('/contribute-case/') ||
        path == '/rescuer' ||
        path == '/my-cases' ||
        path == '/rescue-file' ||
        path.startsWith('/rescue/') ||
        path == '/saved' ||
        path == '/saved-rescuers' ||
        path == '/impact' ||
        path.startsWith('/my-adoptions') ||
        path.startsWith('/messages') ||
        path.startsWith('/my-conversations') ||
        path == '/notifications' ||
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
