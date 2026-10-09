import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../identity/identity_controller.dart';
import 'social_verification_repository.dart';

class SocialVerificationScreen extends ConsumerStatefulWidget {
  const SocialVerificationScreen({super.key, this.openAuthorization});
  final Future<bool> Function(Uri)? openAuthorization;
  @override
  ConsumerState<SocialVerificationScreen> createState() =>
      _SocialVerificationScreenState();
}

class _SocialVerificationScreenState
    extends ConsumerState<SocialVerificationScreen> {
  late final SocialVerificationRepository repository;
  String? actor, attempt, provider, message;
  bool busy = true;
  List<Map<String, dynamic>> accounts = [];
  Set<String> available = {};

  @override
  void initState() {
    super.initState();
    repository = ref.read(socialVerificationRepositoryProvider);
    actor = repository.owner;
    _load();
  }

  bool get sameActor => actor != null && repository.owner == actor;

  Future<void> _load() async {
    try {
      final data = await repository.call({'operation': 'list'});
      if (!mounted || !sameActor) return;
      final rows = data['accounts'];
      final enabled = data['available_providers'];
      if (rows is! List || enabled is! List) {
        throw const FormatException('invalid_response');
      }
      setState(() {
        accounts = rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where((row) => ['facebook', 'instagram'].contains(row['provider']))
            .toList();
        available = enabled.whereType<String>().toSet();
      });
    } catch (_) {
      if (mounted && sameActor) {
        setState(
          () => message = 'No pudimos consultar tus redes. Vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _start(String network) async {
    if (busy || !sameActor || !available.contains(network)) return;
    setState(() {
      busy = true;
      message = null;
      attempt = provider = null;
    });
    try {
      final data = await repository.call({
        'operation': 'start',
        'provider': network,
      });
      if (!mounted || !sameActor) return;
      final id = data['attempt_id'];
      if (id is! String ||
          !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}$').hasMatch(id)) {
        throw const FormatException('invalid_attempt');
      }
      setState(() {
        attempt = id;
        provider = network;
      });
      final uri = socialAuthorizationUri(network, data['authorization_url']);
      final opened =
          await (widget.openAuthorization?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!mounted || !sameActor) return;
      if (!opened) throw StateError('browser_unavailable');
      setState(() {
        attempt = id;
        provider = network;
        message = 'Autoriza en la red social y regresa aquí para comprobar.';
      });
    } catch (_) {
      final pending = attempt;
      if (pending != null && sameActor) {
        try {
          await repository.call({'operation': 'cancel', 'attempt_id': pending});
          if (mounted && sameActor) setState(() => attempt = provider = null);
        } catch (_) {
          // Keep explicit cancellation available when the server is unreachable.
        }
      }
      if (mounted && sameActor) {
        setState(
          () =>
              message = 'No pudimos abrir la verificación. Vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _check() async {
    final id = attempt;
    if (busy || !sameActor || id == null) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final data = await repository.call({
        'operation': 'status',
        'attempt_id': id,
      });
      if (!mounted || !sameActor) return;
      if (data['provider'] != provider) {
        throw const FormatException('provider_mismatch');
      }
      final status = data['status'];
      setState(() {
        message = switch (status) {
          'verified' => 'Cuenta social conectada. Tu perfil público sigue sujeto a revisión.',
          'pending' => 'La autorización sigue pendiente. Puedes comprobar de nuevo al terminar.',
          'denied' =>
            'No autorizaste la conexión. Tu cuenta Dopmi se conserva.',
          'expired' => 'La solicitud venció. Inicia una nueva conexión.',
          _ => 'No se completó la conexión. Puedes volver a intentar.',
        };
        if (status != 'pending') attempt = provider = null;
      });
      if (status == 'verified') await _load();
    } catch (_) {
      if (mounted && sameActor) {
        setState(
          () =>
              message = 'No pudimos comprobar la conexión. Vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancel() async {
    final id = attempt;
    if (busy || !sameActor || id == null) return;
    setState(() => busy = true);
    try {
      await repository.call({'operation': 'cancel', 'attempt_id': id});
      if (mounted && sameActor) {
        setState(() {
          attempt = provider = null;
          message = 'Cancelaste este intento de conexión.';
        });
      }
    } catch (_) {
      if (mounted && sameActor) {
        setState(
          () => message = 'No pudimos cancelar el intento. Vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disconnect(String network) async {
    if (busy || !sameActor) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar cuenta social'),
        content: const Text(
          'Se retirará esta comprobación de Dopmi. '
          'Tu cuenta y tus publicaciones se conservan. '
          'Puedes volver a conectar la red cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || !sameActor || busy) return;
    setState(() => busy = true);
    try {
      await repository.call({'operation': 'disconnect', 'provider': network});
      if (!mounted || !sameActor) return;
      setState(() {
        attempt = provider = null;
        message = 'Retiramos la conexión de Dopmi.';
      });
      await _load();
    } catch (_) {
      if (mounted && sameActor) {
        setState(
          () => message =
              'No pudimos desconectar la cuenta social. Vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ref.watch(identityControllerProvider),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Redes sociales')),
      body: !sameActor
          ? const Center(
              child: Text('La sesión cambió. Vuelve a abrir esta pantalla.'),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Conecta una cuenta para confirmar que la controlas. '
                  'Esto no cambia tu acceso a Dopmi ni sustituye la revisión de identidad.',
                ),
                const SizedBox(height: 20),
                for (final network in ['facebook', 'instagram']) ...[
                  Text(
                    network == 'facebook'
                        ? 'Facebook'
                        : 'Instagram profesional',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final account in accounts.where(
                    (row) => row['provider'] == network,
                  )) ...[
                    Text('Cuenta conectada: ${account['label'] ?? ''}'),
                    TextButton(
                      onPressed: busy ? null : () => _disconnect(network),
                      child: Text(
                        network == 'facebook'
                            ? 'Desconectar Facebook'
                            : 'Desconectar Instagram',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed:
                        busy || attempt != null || !available.contains(network)
                        ? null
                        : () => _start(network),
                    child: Text(
                      network == 'facebook'
                          ? 'Conectar Facebook'
                          : 'Conectar Instagram profesional',
                    ),
                  ),
                  if (!busy && !available.contains(network))
                    const Text('La conexión todavía no está disponible.'),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Si tu Instagram es personal, conserva el enlace en tu perfil. '
                  'Se revisa manualmente y no aparece como conectado por Instagram.',
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(message!, semanticsLabel: message),
                  ),
                if (busy) const Center(child: CircularProgressIndicator()),
                if (attempt != null) ...[
                  FilledButton(
                    onPressed: busy ? null : _check,
                    child: const Text('Ya autoricé, comprobar'),
                  ),
                  TextButton(
                    onPressed: busy ? null : _cancel,
                    child: const Text('Cancelar este intento'),
                  ),
                ] else if (!busy)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        busy = true;
                        message = null;
                      });
                      _load();
                    },
                    child: const Text('Actualizar estado'),
                  ),
              ],
            ),
    ),
  );
}
