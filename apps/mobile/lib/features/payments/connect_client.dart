import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe_connect/flutter_stripe_connect.dart';

import 'payment_repository.dart';
import 'guardian_repository.dart';
import 'payment_environment.dart';

typedef _ConnectSession = ({String secret, int expiresAt});

final connectClientProvider = Provider<ConnectClient>(
  (ref) => ConnectClient(
    key: ref.watch(paymentEnvironmentProvider).publishableKey,
    paymentEnvironment: ref.watch(paymentEnvironmentProvider),
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
    this.paymentEnvironment = const PaymentEnvironment(),
    bool? web,
    TargetPlatform? platform,
    Future<void> Function(String, Future<String> Function())? initialize,
    Future<void> Function()? present,
    Future<void> Function()? logout,
    DateTime Function()? now,
  }) : web = web ?? kIsWeb,
       platform = platform ?? defaultTargetPlatform,
       initialize = initialize ?? _initialize,
       present = present ?? _present,
       logout = logout ?? _logout,
       _now = now ?? DateTime.now;
  final String key;
  final PaymentEnvironment paymentEnvironment;
  final bool enabled, web;
  final TargetPlatform platform;
  final Future<Map<String, dynamic>> Function() session;
  final Future<void> Function(String, Future<String> Function()) initialize;
  final Future<void> Function() present, logout;
  final DateTime Function() _now;
  Future<void>? _pending;
  bool get available =>
      enabled &&
      !web &&
      [TargetPlatform.android, TargetPlatform.iOS].contains(platform) &&
      paymentEnvironment.acceptsPublishableKey(key);
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
    var active = true;
    bool validActor() => active && current();
    _ConnectSession? initial;
    try {
      try {
        // Resolve backend failures in Dopmi before the native SDK can turn a
        // rejected callback into a misleading Stripe authentication screen.
        initial = await _loadSession(validActor);
        var expiresAt = initial.expiresAt;
        await initialize(key, () async {
          if (!validActor()) {
            throw const FormatException('La cuenta cambió.');
          }
          final cached = initial;
          initial = null;
          final value = cached ?? await _loadSession(validActor);
          _requireCurrent(value.expiresAt, validActor);
          expiresAt = value.expiresAt;
          return value.secret;
        });
        _requireCurrent(expiresAt, validActor);
        await present();
      } finally {
        active = false;
        initial = null;
        await logout();
      }
    } catch (_) {
      throw const FormatException(
        'Tu alta en Stripe no está disponible por el momento. Intenta más tarde o contacta a soporte.',
      );
    }
  }

  Future<_ConnectSession> _loadSession(bool Function() current) async {
    if (!current()) throw const FormatException('La cuenta cambió.');
    final value = await session();
    final expires = value['expires_at'];
    final secret = value['client_secret'];
    if (secret is! String ||
        secret.length < 16 ||
        secret.trim() != secret ||
        expires is! int) {
      throw const FormatException('No pudimos confirmar la sesión de Stripe.');
    }
    _requireCurrent(expires, current);
    return (secret: secret, expiresAt: expires);
  }

  void _requireCurrent(int expiresAt, bool Function() current) {
    if (!current() || expiresAt <= _now().millisecondsSinceEpoch ~/ 1000) {
      throw const FormatException('No pudimos confirmar la sesión de Stripe.');
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
