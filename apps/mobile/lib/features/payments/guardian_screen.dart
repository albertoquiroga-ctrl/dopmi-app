import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_repository.dart';
import 'guardian_repository.dart';

class GuardianScreen extends ConsumerStatefulWidget {
  const GuardianScreen({super.key});
  @override
  ConsumerState<GuardianScreen> createState() => _GuardianState();
}

class _GuardianState extends ConsumerState<GuardianScreen>
    with WidgetsBindingObserver {
  final amount = TextEditingController(text: '50');
  Json? data, intent;
  bool busy = true, consent = false, fresh = false;
  String? error, message;
  late final String owner;
  String get storageKey => 'dopmi-guardian:$owner:intent';
  bool get current =>
      mounted && ref.read(identityControllerProvider).identity?.id == owner;
  Json? get plan => data?['plan'] is Map ? Json.from(data!['plan']) : null;
  Json? get activation =>
      data?['activation'] is Map ? Json.from(data!['activation']) : null;

  @override
  void initState() {
    super.initState();
    owner = ref.read(identityControllerProvider).identity!.id;
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(guardianEnabledProvider)) {
      load(restore: true);
    } else {
      busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !busy &&
        ref.read(guardianEnabledProvider))
      load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    amount.dispose();
    super.dispose();
  }

  Future<void> load({bool restore = false}) async {
    if (!current) return;
    setState(() {
      busy = true;
      error = null;
      fresh = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (restore) {
        final saved = prefs.getString(storageKey);
        if (saved != null) {
          try {
            final value = Json.from(jsonDecode(saved));
            if (!['checkout', 'amount', 'cancel'].contains(value['kind']) ||
                value['key'] is! String ||
                (value['kind'] != 'cancel' &&
                    (value['cents'] is! int ||
                        value['consent_version'] != guardianConsent)) ||
                (value['kind'] != 'checkout' && value['revision'] is! int)) {
              throw const FormatException('Intento incompleto');
            }
            intent = value;
          } catch (_) {
            message =
                'Consultamos el estado del servidor para recuperar tu plan.';
          }
        }
      }
      if (!current) return;
      final result = await ref.read(guardianRepositoryProvider).state();
      if (!current) return;
      data = result;
      // Only authoritative terminal state releases an initial payment attempt.
      if (intent?['kind'] == 'checkout' &&
          (plan != null ||
              (activation?['key'] == intent?['key'] &&
                  [
                    'no_capacity',
                    'expired',
                    'failed',
                    'refunded',
                  ].contains(activation?['status'])))) {
        await prefs.remove(storageKey);
        intent = null;
      }
      if (plan == null &&
          intent == null &&
          activation?['status'] == 'pending' &&
          activation?['consent_version'] == guardianConsent) {
        intent = {
          'kind': 'checkout',
          'key': activation!['key'],
          'cents': activation!['gross_cents'],
          'consent_version': guardianConsent,
        };
        if (!await prefs.setString(storageKey, jsonEncode(intent))) {
          throw const FormatException('No se pudo conservar el intento.');
        }
      }
      if (!current) return;
      if (restore || intent != null) {
        final cents = intent?['cents'] ?? plan?['gross_cents'] ?? 5000;
        amount.text = ((cents as int) / 100).toStringAsFixed(2);
      }
      fresh = true;
    } catch (cause) {
      if (current) error = guardianError(cause);
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> submit({bool cancel = false}) async {
    if (busy || !fresh || !current) return;
    if (cancel) {
      setState(() => busy = true);
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Cancelar tu plan Guardián?'),
          content: const Text(
            'Detendremos los ciclos futuros. Un pago ya iniciado puede terminar de procesarse. Los pagos anteriores conservan su historial y no se devuelven automáticamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conservar plan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar cancelación'),
            ),
          ],
        ),
      );
      if (!current) return;
      setState(() => busy = false);
      if (agreed != true) return;
    }
    final cents = parsePesos(amount.text);
    if (!cancel &&
        intent == null &&
        (!consent || cents == null || cents < 1000 || cents > 1000000)) {
      setState(
        () => error = 'Elige un importe de \$10 a \$10,000 MXN, con hasta dos decimales, y confirma la autorización.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final repo = ref.read(guardianRepositoryProvider);
      if (intent == null &&
          !cancel &&
          plan == null &&
          !await repo.capacity(cents!)) {
        if (current)
          setState(
            () => message = 'Por ahora no hay gastos aprobados suficientes para asignar tu aportación completa. No se abrió un pago ni se activó un plan.',
          );
        return;
      }
      if (!current) return;
      final next = cancel
          ? <String, dynamic>{
              'kind': 'cancel',
              'key': const Uuid().v4(),
              'revision': plan!['revision'],
            }
          : intent ??
                <String, dynamic>{
                  'kind': plan == null ? 'checkout' : 'amount',
                  'key': const Uuid().v4(),
                  'cents': cents,
                  'revision': plan?['revision'],
                };
      if (intent == null && !cancel) next['consent_version'] = guardianConsent;
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, jsonEncode(next))) {
        throw const FormatException('No se pudo conservar el intento.');
      }
      if (!current) return;
      setState(() => intent = next);
      final result = await repo.submit(next);
      if (!current) return;
      if (next['kind'] != 'checkout') {
        await prefs.remove(storageKey);
        if (!current) return;
        intent = null;
        consent = false;
        message = 'Solicitud recibida. Consulta el estado para confirmar su aplicación.';
      } else if (result['checkout_url'] is String) {
        await repo.openCheckout(result['checkout_url'] as String);
      } else {
        message =
            guardianActivationLabels[result['status']] ??
            'El alta sigue en revisión. No vuelvas a pagar.';
      }
      if (current) await load();
    } catch (cause) {
      if (current && intent?['kind'] != 'checkout' && guardianRejected(cause)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(storageKey);
        if (!current) return;
        intent = null;
        consent = false;
        await load();
      }
      if (current) setState(() => error = guardianError(cause));
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  String date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'por confirmar';
    final local = parsed.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(guardianEnabledProvider);
    final p = plan;
    final pending = p?['pending_request'];
    final status = p?['status'];
    final canStart =
        p == null &&
        (activation == null ||
            [
              'no_capacity',
              'expired',
              'failed',
              'refunded',
            ].contains(activation?['status']));
    final canChange = status == 'active' && pending == null;
    final canCancel = status == 'active';
    final verified =
        ref.watch(identityControllerProvider).identity?.verified == true;
    final canSubmit =
        !busy &&
        fresh &&
        (intent != null || (verified && consent && (canStart || canChange)));
    return CommunityFrame(
      children: [
        const Heading(
          'Tu ayuda, mes a mes.',
          'Aporta a gastos aprobados de rescatistas con tu plan Guardián.',
          eyebrow: 'GUARDIÁN · PRUEBA',
        ),
        if (!enabled)
          const Notice(
            'Guardián todavía no está disponible. Te avisaremos cuando puedas activar tu plan.',
          ),
        if (enabled) ...[
          const Notice(
            'Solo modo de prueba. No uses datos de una tarjeta real.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (p != null) ...[
            Text(switch (status) {
              'active' => 'Plan activo',
              'cancel_requested' =>
                'Cancelación solicitada: futuros cobros detenidos',
              'canceled' => 'Plan cancelado',
              _ => 'Estado por confirmar',
            }, style: Theme.of(context).textTheme.titleLarge),
            Text('Monto autorizado: ${pesos(p['gross_cents'] as int)} al mes'),
            if (pending is Map)
              Notice(
                pending['kind'] == 'cancel'
                    ? 'Estamos confirmando la cancelación con Stripe.'
                    : 'Cambio a ${pesos(pending['new_gross_cents'] as int)} solicitado. El importe anterior se conserva hasta confirmar la aplicación.',
              ),
            if (p['payment_in_flight'] == true)
              const Notice(
                'Hay un pago previamente iniciado en conciliación. Cancelar no confirma su devolución.',
              ),
            for (final r in p['requests'] as List? ?? [])
              ListTile(
                title: Text(
                  r['kind'] == 'cancel'
                      ? 'Cancelación'
                      : 'Cambio a ${pesos(r['new_gross_cents'] as int)}',
                ),
                subtitle: Text(switch (r['status']) {
                  'applied' =>
                    r['kind'] == 'amount'
                        ? 'Confirmado. Aplica desde ${date(r['effective_at'])}.'
                        : 'Cancelación confirmada.',
                  'superseded' => 'Sustituido por cancelación.',
                  _ => 'Pendiente de confirmación.',
                }),
              ),
          ] else if (activation != null)
            Notice(
              guardianActivationLabels[activation!['status']] ??
                  'Estado del alta en revisión. No vuelvas a pagar.',
            ),
          if (canStart || canChange || intent != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final value in [50, 200, 500])
                  ChoiceChip(
                    label: Text('\$$value MXN'),
                    selected: parsePesos(amount.text) == value * 100,
                    onSelected: busy || intent != null
                        ? null
                        : (_) => setState(() {
                            amount.text = '$value';
                            consent = false;
                          }),
                  ),
              ],
            ),
            TextField(
              controller: amount,
              enabled: !busy && intent == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => consent = false),
              decoration: const InputDecoration(
                labelText: 'Importe mensual en MXN',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            Notice(
              p == null
                  ? 'Primer intento de cobro: hoy, ${date(DateTime.now().toIso8601String())}, al activar. Próxima fecha aproximada: ${date(guardianNextBilling(DateTime.now()).toIso8601String())}. Después, cada aniversario mensual; si el mes no tiene ese día, se usa su último día. Stripe te mostrará el importe antes de confirmar.'
                  : 'El nuevo importe aplica desde el siguiente ciclo. No se prorratea ni cambia el importe de un ciclo ya preparado.',
            ),
            const Notice(
              'Solo se cobra si el neto completo puede asignarse a gastos aprobados. Si no hay capacidad, ese mes se omite sin cargo ni deuda. Dopmi descuenta el 2% y los costos de Stripe; el neto se asigna por prioridad. Puedes cancelar los ciclos futuros.',
            ),
            if (intent == null)
              CheckboxListTile(
                value: consent,
                onChanged: busy
                    ? null
                    : (value) => setState(() => consent = value ?? false),
                title: Text(
                  p == null
                      ? 'Autorizo el primer pago y los cobros mensuales condicionados por el importe elegido, y guardar mi medio de pago en Stripe.'
                      : 'Autorizo el nuevo importe mensual desde el siguiente ciclo.',
                ),
              ),
            if (intent != null)
              const Notice(
                'Conservamos tu solicitud. Reintentar usa la misma referencia y el mismo importe.',
              ),
            ActionButton(
              intent == null
                  ? (p == null
                        ? 'Activar en Stripe'
                        : 'Solicitar cambio de monto')
                  : 'Reintentar mi solicitud',
              busy: busy,
              onPressed: canSubmit ? () => submit() : null,
            ),
          ],
          if (canCancel)
            TextButton(
              onPressed: busy || !fresh ? null : () => submit(cancel: true),
              child: const Text('Cancelar mi plan'),
            ),
          if (error != null) Notice(error!, isError: true),
          if (message != null) Notice(message!),
          TextButton(
            onPressed: busy ? null : () => load(),
            child: const Text('Actualizar estado'),
          ),
        ],
      ],
    );
  }
}
