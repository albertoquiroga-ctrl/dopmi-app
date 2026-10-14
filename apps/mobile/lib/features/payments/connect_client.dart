import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe_connect/flutter_stripe_connect.dart';

import 'payment_repository.dart';
import 'guardian_repository.dart';

final connectClientProvider = Provider<ConnectClient>(
  (ref) => ConnectClient(
    key: const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY_TEST'),
    enabled: ref.watch(guardianEnabledProvider),
    session: () =>
        ref.read(paymentRepositoryProvider).action('connect_session'),
  ),
);

class ConnectClient {
  ConnectClient({
    required this.key,
    required this.session,
    this.enabled = false,
    bool? web,
    TargetPlatform? platform,
    Future<void> Function(String, Future<String> Function())? initialize,
    Future<void> Function()? present,
    Future<void> Function()? logout,
  }) : web = web ?? kIsWeb,
       platform = platform ?? defaultTargetPlatform,
       initialize = initialize ?? _initialize,
       present = present ?? _present,
       logout = logout ?? _logout;
  final String key;
  final bool enabled, web;
  final TargetPlatform platform;
  final Future<Map<String, dynamic>> Function() session;
  final Future<void> Function(String, Future<String> Function()) initialize;
  final Future<void> Function() present, logout;
  Future<void>? _pending;
  bool get available =>
      enabled &&
      !web &&
      [TargetPlatform.android, TargetPlatform.iOS].contains(platform) &&
      RegExp(r'^pk_test_[A-Za-z0-9]+$').hasMatch(key);
  Future<void> run(bool Function() current) {
    if (_pending != null) return _pending!;
    final task = _run(current);
    _pending = task;
    return task.whenComplete(() {
      _pending = null;
    });
  }

  Future<void> _run(bool Function() current) async {
    if (!available || !current()) {
      throw const FormatException('Onboarding integrado no disponible.');
    }
    try {
      await initialize(key, () async {
        if (!current()) throw const FormatException('La cuenta cambió.');
        final value = await session();
        final expires = value['expires_at'];
        final secret = value['client_secret'];
        if (!current() ||
            secret is! String ||
            secret.length < 16 ||
            expires is! int ||
            expires <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
          throw const FormatException(
            'No pudimos confirmar la sesión de Stripe.',
          );
        }
        return secret;
      });
      if (!current()) throw const FormatException('La cuenta cambió.');
      await present();
    } catch (_) {
      throw const FormatException(
        'No se confirmó la configuración. Consulta el estado de tu cuenta.',
      );
    } finally {
      await logout();
    }
  }
}

Future<void> _initialize(String key, Future<String> Function() session) =>
    StripeConnect.instance.initialize(
      publishableKey: key,
      clientSecretProvider: session,
    );
Future<void> _logout() => StripeConnect.instance.logout();
Future<void> _present() async {
  final done = Completer<void>();
  bool failed = false;
  await StripeConnect.presentAccountOnboarding(
    onExit: () {
      if (!done.isCompleted) done.complete();
    },
    onLoadError: (_) {
      failed = true;
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future;
  if (failed) throw const FormatException('Stripe no confirmó la carga.');
}
