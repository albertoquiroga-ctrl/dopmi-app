import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../identity/identity_controller.dart';
import 'guardian_registration.dart';
import 'guardian_repository.dart';

/// Access retained while a legal update is awaiting explicit acceptance.
/// Never mounts enrollment, wallet recovery, or processor setup controls.
class GuardianLegalAccessScreen extends ConsumerWidget {
  const GuardianLegalAccessScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityControllerProvider);
    if (!ref.watch(guardianEnabledProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consultar o cancelar Guardián')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Notice(
              'Guardián todavía no está disponible. Te avisaremos cuando puedas activar tu plan.',
            ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: identity,
      builder: (_, _) {
        final owner = identity.identity?.id;
        return owner == null
            ? const SizedBox.shrink()
            : _LegalGuardian(key: ValueKey(owner), owner: owner);
      },
    );
  }
}

class _LegalGuardian extends ConsumerStatefulWidget {
  const _LegalGuardian({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<_LegalGuardian> createState() => _LegalGuardianState();
}

class _LegalGuardianState extends ConsumerState<_LegalGuardian> {
  Json? data, request;
  GuardianRegistration? registration;
  bool busy = false, fresh = false, confirming = false;
  bool registrationCancellationAllowed = false;
  String? error, registrationError;
  int generation = 0;
  String get storageKey => 'dopmi-legal-guardian-cancel:${widget.owner}';
  bool get current =>
      mounted &&
      ref.read(guardianEnabledProvider) &&
      ref.read(identityControllerProvider).identity?.id == widget.owner;
  Json? get plan => data?['plan'] is Map ? Json.from(data!['plan']) : null;
  Json? get activation =>
      data?['activation'] is Map ? Json.from(data!['activation']) : null;
  bool get planStopped =>
      ['canceled', 'cancel_requested'].contains(plan?['status']) ||
      plan?['cancellation_requested_at'] != null ||
      (plan?['pending_request'] is Map &&
          plan?['pending_request']['kind'] == 'cancel');
  bool get activationStopped =>
      activation?['cancellation_requested_at'] != null ||
      activation?['cancellation_status'] == 'stopped' ||
      ['canceled', 'expired'].contains(activation?['status']);
  Json? get cancelTarget {
    if (registration != null &&
        registration!.status != 'canceled' &&
        registrationCancellationAllowed &&
        ref.read(identityControllerProvider).identity?.verified == true) {
      return {'kind': 'registration_cancel', 'key': registration!.id};
    }
    if (plan != null) {
      if (plan?['status'] == 'active' && !planStopped) {
        return {'kind': 'cancel', 'revision': plan!['revision']};
      }
      return null;
    }
    if (activation != null && !activationStopped) {
      return {'kind': 'cancel_activation', 'key': activation!['key']};
    }
    return null;
  }

  bool get canCancel {
    final target = cancelTarget;
    if (!fresh || target == null) return false;
    if (request == null) return true;
    return request!['kind'] == target['kind'] &&
        (target['kind'] == 'cancel' || request!['key'] == target['key']);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> load() async {
    if (!current || busy) return;
    final ticket = ++generation;
    setState(() {
      busy = true;
      fresh = false;
      error = null;
      registrationError = null;
    });
    try {
      final repo = ref.read(guardianRepositoryProvider);
      final state = await repo.state();
      if (!current || ticket != generation) return;
      GuardianRegistration? snapshot;
      String? snapshotError;
      try {
        snapshot = await repo.registrationSnapshot();
      } catch (_) {
        snapshotError = 'No pudimos consultar el registro actual. El estado del plan anterior y su cancelación siguen disponibles; consulta de nuevo para revisar el registro.';
      }
      if (!current || ticket != generation) return;
      var canCancelRegistration = false;
      if (snapshot != null && snapshot.status != 'canceled') {
        try {
          final profile = await ref
              .read(identityRepositoryProvider)
              .loadProfile();
          if (!current || ticket != generation) return;
          canCancelRegistration =
              profile.id == widget.owner &&
              profile.status == 'active' &&
              ref.read(identityControllerProvider).identity?.verified == true;
        } catch (_) {
          // Fail closed only for the modern registration. Legacy cancellation
          // keeps its existing server contract, including suspended owners.
        }
      }
      if (!current || ticket != generation) return;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      Json? pending;
      if (saved != null) {
        final value = jsonDecode(saved);
        if (value is! Map ||
            ![
              'cancel',
              'cancel_activation',
              'registration_cancel',
            ].contains(value['kind']) ||
            value['key'] is! String ||
            !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value['key']) ||
            (value['kind'] == 'cancel' && value['revision'] is! int)) {
          throw const FormatException(
            'Referencia de cancelación no disponible',
          );
        }
        pending = Json.from(value);
      }
      if (!current || ticket != generation) return;
      setState(() {
        data = state;
        registration = snapshot;
        registrationCancellationAllowed = canCancelRegistration;
        registrationError = snapshotError;
        request = pending;
        fresh = true;
      });
      final stopped =
          pending?['kind'] == 'cancel' && planStopped ||
          pending?['kind'] == 'cancel_activation' &&
              activationStopped &&
              pending?['key'] == activation?['key'] ||
          pending?['kind'] == 'registration_cancel' &&
              snapshot?.status == 'canceled' &&
              pending?['key'] == snapshot?.id;
      if (stopped) {
        await prefs.remove(storageKey);
        if (current && ticket == generation) setState(() => request = null);
      }
    } catch (_) {
      if (current && ticket == generation) {
        setState(
          () => error = 'No pudimos confirmar el estado. Consulta de nuevo; no iniciamos otra operación.',
        );
      }
    } finally {
      if (current && ticket == generation) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    if (!current || busy || confirming || !canCancel) return;
    setState(() => confirming = true);
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          request?['rejected'] == true
              ? '¿Enviar una nueva cancelación?'
              : '¿Cancelar Guardián?',
        ),
        content: const Text(
          'Detendremos los ciclos futuros. Un pago ya iniciado puede terminar de procesarse. Los pagos anteriores conservan su historial y no se devuelven automáticamente. Esta acción no acepta los documentos actualizados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );
    if (!current) return;
    setState(() => confirming = false);
    if (agreed != true || !canCancel) return;
    setState(() {
      busy = true;
      fresh = false;
      error = null;
    });
    try {
      final target = cancelTarget!;
      final next =
          (request?['rejected'] == true ? null : request) ??
          {...target, if (target['kind'] == 'cancel') 'key': const Uuid().v4()};
      final prefs = await SharedPreferences.getInstance();
      if (!current) return;
      if (!await prefs.setString(storageKey, jsonEncode(next))) {
        throw const FormatException();
      }
      if (!current) return;
      request = next;
      final repo = ref.read(guardianRepositoryProvider);
      if (next['kind'] == 'registration_cancel') {
        await repo.cancelRegistration(next['key'] as String);
      } else {
        await repo.submit(next);
      }
      // The write response is not proof of completion. Read the owned projection.
    } on PostgrestException catch (cause) {
      if (current && cause.code == '40001' && request?['kind'] == 'cancel') {
        // SQL rejected this transaction because the management revision changed.
        // This is not a transport timeout: a new request still needs a new confirmation.
        final rejected = {...request!, 'rejected': true};
        final prefs = await SharedPreferences.getInstance();
        if (current &&
            await prefs.setString(storageKey, jsonEncode(rejected))) {
          request = rejected;
        }
      }
      if (current) {
        setState(
          () => error = cause.code == '40001'
              ? 'Tu plan cambió y esta solicitud fue rechazada sin aplicarse. Consulta el estado y confirma una nueva cancelación si deseas detenerlo.'
              : 'Cancelación sin confirmar. Conservamos la misma referencia. Consulta el estado antes de reintentar.',
        );
      }
    } catch (_) {
      if (current) {
        setState(
          () => error = 'Cancelación sin confirmar. Conservamos la misma referencia. Consulta el estado antes de reintentar.',
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
    if (current) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Consultar o cancelar Guardián'),
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/consent'),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Notice(
          'Puedes consultar tus movimientos y detener ciclos futuros sin aceptar la actualización de términos y privacidad.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Notice(error!, isError: true),
        if (registration != null &&
            registration!.status != 'canceled' &&
            !registrationCancellationAllowed) ...[
          const Notice(
            'Para cancelar este registro desde la app necesitas una cuenta activa y el correo confirmado. Si no puedes recuperar el acceso o tu cuenta está restringida, solicita ayuda en soporte@dopmi.org. Consultar el registro no confirma una cancelación.',
          ),
          TextButton(
            onPressed: () => context.push('/account-privacy'),
            child: const Text('Cuenta y privacidad'),
          ),
        ],
        if (registrationError != null)
          Notice(registrationError!, isError: true),
        if (request?['rejected'] == true)
          const Notice(
            'La solicitud anterior fue rechazada por un cambio del plan. Preparar una nueva cancelación requiere otra confirmación; no la enviaremos automáticamente.',
          ),
        if (fresh) ...[
          if (plan != null)
            Text(
              planStopped
                  ? 'Plan cancelado o con cancelación solicitada'
                  : plan?['status'] == 'active'
                  ? 'Plan activo'
                  : 'Plan en revisión',
            ),
          if (plan == null && activation != null)
            Text(
              activationStopped
                  ? 'Alta detenida o con cancelación solicitada'
                  : 'Alta en proceso; consulta su estado',
            ),
          if (registration != null) ...[
            Text(switch (registration!.status) {
              'registered' => 'Registro vigente',
              'method_pending' => 'Registro pendiente',
              _ => 'Registro cancelado',
            }),
            Text(registration!.summary),
          ],
          if (plan == null &&
              activation == null &&
              registration == null &&
              registrationError == null)
            const Text('No hay un registro Guardián en esta cuenta.'),
          if (plan?['payment_in_flight'] == true ||
              registration?.attemptId != null)
            const Notice(
              'Un pago iniciado conserva su estado. Cancelar no confirma una devolución.',
            ),
        ],
        if (canCancel)
          FilledButton(
            onPressed: busy || confirming ? null : cancel,
            child: Text(
              request?['rejected'] == true
                  ? 'Preparar nueva cancelación'
                  : request == null
                  ? 'Cancelar Guardián'
                  : 'Reintentar misma cancelación',
            ),
          ),
        TextButton(
          onPressed: busy || confirming ? null : load,
          child: const Text('Consultar estado'),
        ),
        TextButton(
          onPressed: () => context.push('/guardian/history'),
          child: const Text('Ver historial de ciclos'),
        ),
        TextButton(
          onPressed: () => context.push('/payments'),
          child: const Text('Ver mis comprobantes'),
        ),
      ],
    ),
  );
}
