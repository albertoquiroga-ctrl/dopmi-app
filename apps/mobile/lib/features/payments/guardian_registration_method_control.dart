import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:uuid/uuid.dart';

import '../../core/ui.dart';

import '../adoption/community_repository.dart';

import '../identity/identity_controller.dart';

import 'guardian_registration.dart';

import 'guardian_payment_card.dart';

import 'guardian_repository.dart';

import 'guardian_method_setup.dart';

import 'payment_repository.dart';

class GuardianRegistrationMethodControl extends ConsumerStatefulWidget {
  const GuardianRegistrationMethodControl({
    super.key,

    required this.owner,

    required this.registration,

    required this.onUpdated,

    this.currentCard,
  });

  final String owner;

  final GuardianPaymentCard? currentCard;

  final GuardianRegistration registration;

  final Future<void> Function() onUpdated;

  @override
  ConsumerState<GuardianRegistrationMethodControl> createState() =>
      _MethodControlState();
}

class _MethodControlState
    extends ConsumerState<GuardianRegistrationMethodControl>
    with WidgetsBindingObserver {
  Json? operation;

  String? error, message, sessionToken;

  bool busy = true, presenting = false, ready = false;

  int? settledRevision;

  String get storageKey =>
      'dopmi-guardian-method:${widget.owner}:${widget.registration.id}';

  bool get current =>
      mounted &&
      ref.read(identityControllerProvider).identity?.id == widget.owner &&
      ref
              .read(guardianRepositoryProvider)
              .client
              .auth
              .currentSession
              ?.accessToken ==
          sessionToken;

  @override
  void initState() {
    super.initState();

    sessionToken = ref
        .read(guardianRepositoryProvider)
        .client
        .auth
        .currentSession
        ?.accessToken;

    WidgetsBinding.instance.addObserver(this);

    restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        operation != null &&
        !busy &&
        current) {
      consult();
    }
  }

  Json validateDraft(dynamic value) {
    if (value is! Map ||
        value['id'] != widget.registration.id ||
        value['key'] is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value['key']) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        value['consent'] != true ||
        value['consent_version'] != savedCardConsent ||
        value.keys.any(
          (key) => ![
            'id',

            'key',

            'revision',

            'consent',

            'consent_version',
          ].contains(key),
        )) {
      throw const FormatException(
        'No pudimos validar la solicitud conservada. Consulta su estado desde tu cuenta.',
      );
    }

    return Json.from(value);
  }

  Future<void> restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);

      if (!current) return;

      if (raw != null) operation = validateDraft(jsonDecode(raw));

      final pending = widget.registration.methodChange;

      if (operation == null && pending?.status == 'pending') {
        operation = {
          'id': widget.registration.id,

          'key': pending!.key,

          'revision': pending.revision,

          'consent': true,

          'consent_version': savedCardConsent,
        };

        await persist();
      }

      ready = true;
    } catch (cause) {
      if (current) error = paymentError(cause);
    } finally {
      if (current) setState(() => busy = false);
    }

    if (current && ready && operation != null) await consult();
  }

  Future<void> persist() async {
    if (!current || operation == null) {
      throw const FormatException('La sesión cambió.');
    }

    final saved = await (await SharedPreferences.getInstance()).setString(
      storageKey,

      jsonEncode(operation),
    );

    if (!saved) {
      throw const FormatException(
        'No se pudo conservar el cambio. No se abrió Stripe.',
      );
    }
  }

  Future<void> reconcile(Json receipt) async {
    final draft = operation;

    if (!current ||
        draft == null ||
        receipt['id'] != draft['id'] ||
        receipt['key'] != draft['key'] ||
        ![
          'pending',

          'applied',

          'expired',

          'canceled',
        ].contains(receipt['status']) ||
        receipt['registration_revision'] !=
            (draft['revision'] as int) +
                (receipt['status'] == 'applied' ? 1 : 0)) {
      throw const FormatException('No se confirmó el mismo cambio de tarjeta.');
    }

    if (receipt['status'] == 'pending') {
      message = 'Cambio de tarjeta pendiente. Guardar una tarjeta no realiza una aportación.';

      return;
    }

    if (receipt['status'] == 'applied') {
      final projected = await ref
          .read(guardianRepositoryProvider)
          .registrationState();

      if (!current) return;

      if (projected?.id != draft['id'] ||
          projected?.methodStatus != 'saved' ||
          projected?.methodChange?.key != draft['key'] ||
          projected?.methodChange?.status != 'applied' ||
          projected!.revision < (receipt['registration_revision'] as int)) {
        throw const FormatException(
          'El cambio sigue en conciliación. Consulta la misma solicitud.',
        );
      }

      settledRevision = receipt['registration_revision'] as int;

      message = 'Tarjeta de Guardián actualizada. No se realizó un cargo.';
    } else {
      message = receipt['status'] == 'expired'
          ? 'El cambio de tarjeta expiró. Tu registro conserva el método anterior.'
          : 'El cambio de tarjeta terminó sin aplicarse. Consulta tu registro.';
    }

    await (await SharedPreferences.getInstance()).remove(storageKey);

    if (!current) return;

    operation = null;

    await widget.onUpdated();
  }

  Future<void> consult() async {
    if (!current || busy || operation == null) return;

    setState(() {
      busy = true;

      error = null;
    });

    try {
      final result = await ref
          .read(guardianRepositoryProvider)
          .registrationMethodStatus(operation!);

      if (current) await reconcile(result);
    } catch (cause) {
      if (current) error = paymentError(cause);
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> change() async {
    if (!current ||
        busy ||
        !ready ||
        widget.registration.status != 'registered' ||
        ref.read(identityControllerProvider).identity?.verified != true) {
      return;
    }

    if (operation == null) {
      final approved = await showDialog<bool>(
        context: context,

        builder: (context) => AlertDialog(
          title: const Text('Cambiar tarjeta'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          scrollable: true,

          content: const Text(
            'Autorizo guardar y usar la nueva tarjeta en Stripe para los próximos ciclos de este registro Guardián. No cambia el monto ni cobra ahora; tampoco cambia la tarjeta predeterminada de otras aportaciones.',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),

              child: const Text('Volver'),
            ),

            FilledButton(
              onPressed: () => Navigator.pop(context, true),

              child: const Text('Autorizar y continuar'),
            ),
          ],
        ),
      );

      if (!current || approved != true) return;

      operation = {
        'id': widget.registration.id,

        'key': const Uuid().v4(),

        'revision': widget.registration.revision,

        'consent': true,

        'consent_version': savedCardConsent,
      };
    }

    setState(() {
      busy = true;

      error = null;
    });

    try {
      await persist();

      if (!current) return;

      final draft = operation!;

      final result = await ref
          .read(guardianRepositoryProvider)
          .submitRegistrationMethod(draft);

      if (!current) return;

      await reconcile(result);

      if (!current || operation == null) return;

      final secret = result['setup_client_secret'];

      if (secret is String) {
        final sdk = ref.read(guardianMethodSetupProvider);

        if (!sdk.available) {
          message = 'Stripe no está disponible en este dispositivo. Conservamos el mismo cambio de tarjeta.';
        } else {
          setState(() => presenting = true);

          try {
            await sdk.present(
              secret,

              current: () =>
                  current &&
                  operation?['key'] == draft['key'] &&
                  (ModalRoute.of(context)?.isCurrent ?? false),
            );
          } catch (_) {
            if (current) message = 'La captura no se completó. Consulta o continúa el mismo cambio.';
          } finally {
            if (current) setState(() => presenting = false);
          }

          if (!current) return;

          final state = await ref
              .read(guardianRepositoryProvider)
              .registrationMethodStatus(draft);

          if (current) await reconcile(state);
        }
      }
    } catch (cause) {
      if (current) error = paymentError(cause);
    } finally {
      if (current) {
        setState(() {
          busy = false;

          presenting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !current || (!busy && !presenting),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        if (!current)
          const Notice(
            'La sesión cambió. Abre nuevamente Métodos de pago para consultar el mismo cambio.',
          ),

        Text(
          widget.registration.methodStatus == 'saved'
              ? 'Método del registro Guardián confirmado.'
              : 'El método del registro Guardián requiere confirmación.',
        ),

        if (widget.currentCard?.guardianCurrent == true) ...[
          const SizedBox(height: 6),

          Text(
            '${widget.currentCard!.brandLabel} •••• ${widget.currentCard!.last4}',
          ),

          if (widget.currentCard!.expiryLabel != null)
            Text('Vence ${widget.currentCard!.expiryLabel}'),
        ],

        const SizedBox(height: 8),

        if (message != null) Notice(message!),

        if (error != null) Notice(error!, isError: true),

        OutlinedButton.icon(
          icon: const Icon(Icons.credit_card),

          onPressed:
              !current ||
                  !ready ||
                  busy ||
                  presenting ||
                  ref.watch(identityControllerProvider).identity?.verified !=
                      true ||
                  (settledRevision != null &&
                      widget.registration.revision < settledRevision!)
              ? null
              : change,

          label: Text(
            operation == null ? 'Cambiar tarjeta' : 'Continuar el mismo cambio',
          ),
        ),

        if (operation != null)
          TextButton(
            onPressed: busy || presenting ? null : consult,

            child: const Text('Consultar cambio de tarjeta'),
          ),

        if (busy)
          const LinearProgressIndicator(
            semanticsLabel: 'Consultando cambio de tarjeta',
          ),
      ],
    ),
  );
}
