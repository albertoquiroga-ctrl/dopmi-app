import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool busy = true, consent = false, fresh = false, confirming = false;
  String? error, message;
  late final String owner;
  String get storageKey => 'dopmi-guardian:$owner:intent';
  bool get current =>
      mounted && ref.read(identityControllerProvider).identity?.id == owner;
  Json? get plan => data?['plan'] is Map ? Json.from(data!['plan']) : null;
  Json? get activation =>
      data?['activation'] is Map ? Json.from(data!['activation']) : null;
  Json? get methodSetup =>
      data?['method_setup'] is Map ? Json.from(data!['method_setup']) : null;

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
        !confirming &&
        ref.read(guardianEnabledProvider)) {
      load();
    }
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
            if (![
                  'checkout',
                  'amount',
                  'cancel',
                  'cancel_activation',
                  'method',
                  'withdraw_amount',
                ].contains(value['kind']) ||
                value['key'] is! String ||
                (['checkout', 'amount'].contains(value['kind']) &&
                    (value['cents'] is! int ||
                        value['consent_version'] != guardianConsent)) ||
                (value['kind'] == 'method' &&
                    value['consent_version'] != guardianConsent) ||
                ([
                      'amount',
                      'cancel',
                      'method',
                      'withdraw_amount',
                    ].contains(value['kind']) &&
                    value['revision'] is! int)) {
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
      if (plan?['status'] == 'canceled' ||
          activation?['cancellation_status'] == 'stopped') {
        message = null;
      }
      if (intent?['kind'] == 'method' &&
          (['canceled', 'cancel_requested'].contains(plan?['status']) ||
              (methodSetup?['key'] == intent?['key'] &&
                  [
                    'applied',
                    'expired',
                    'superseded',
                  ].contains(methodSetup?['status'])))) {
        await prefs.remove(storageKey);
        intent = null;
      }
      if (intent == null &&
          plan?['status'] == 'active' &&
          ['pending', 'attention'].contains(methodSetup?['status'])) {
        intent = {
          'kind': 'method',
          'key': methodSetup!['key'],
          'revision': methodSetup!['revision'],
          'consent_version': guardianConsent,
        };
        if (!await prefs.setString(storageKey, jsonEncode(intent))) {
          throw const FormatException('No se pudo conservar el intento.');
        }
      }
      if (intent?['kind'] == 'withdraw_amount' &&
          (plan?['requests'] as List? ?? []).any(
            (request) =>
                request['id'] == intent?['key'] &&
                [
                  'withdrawn',
                  'superseded',
                  'applied',
                ].contains(request['status']),
          )) {
        await prefs.remove(storageKey);
        intent = null;
      }
      // Only authoritative terminal state releases an initial payment attempt.
      if (intent?['kind'] == 'checkout' &&
          (plan != null ||
              activation?['cancellation_requested_at'] != null ||
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
          activation?['cancellation_requested_at'] == null &&
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

  Future<void> submit({
    bool cancel = false,
    bool method = false,
    bool withdraw = false,
  }) async {
    if (busy || confirming || !fresh || !current) return;
    if (cancel || method || withdraw) {
      setState(() => confirming = true);
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            withdraw
                ? '¿Retirar el cambio de monto?'
                : method
                ? '¿Actualizar tu medio de pago?'
                : '¿Cancelar tu plan Guardián?',
          ),
          content: Text(
            withdraw
                ? 'Mantendrás el importe anterior de tu plan: ${pesos(plan!['gross_cents'] as int)} al mes. Lo retiraremos si aún no comenzó a aplicarse; los próximos ciclos podrán continuar con el importe anterior. Esta acción no cancela tu plan.'
                : method
                ? 'Autorizo guardar y usar el nuevo medio en Stripe para los próximos ciclos de Guardián, con el monto y las condiciones vigentes. Stripe puede solicitar autenticación bancaria. Este cambio no cobra ni recupera ciclos omitidos.'
                : 'Detendremos los ciclos futuros. Un pago ya iniciado puede terminar de procesarse. Los pagos anteriores conservan su historial y no se devuelven automáticamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(method || withdraw ? 'Volver' : 'Conservar plan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                withdraw
                    ? 'Retirar y conservar monto'
                    : method
                    ? 'Autorizar y continuar'
                    : 'Confirmar cancelación',
              ),
            ),
          ],
        ),
      );
      if (!current) return;
      setState(() => confirming = false);
      if (agreed != true) return;
    }
    final cents = parsePesos(amount.text);
    if (!cancel &&
        !method &&
        !withdraw &&
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
        if (current) {
          setState(
            () => message = 'Por ahora no hay gastos aprobados suficientes para asignar tu aportación completa. No se abrió un pago ni se activó un plan.',
          );
        }
        return;
      }
      if (!current) return;
      final next = withdraw
          ? <String, dynamic>{
              'kind': 'withdraw_amount',
              'key': plan!['pending_request']['id'],
              'revision': plan!['revision'],
            }
          : cancel
          ? <String, dynamic>{
              'kind': plan == null ? 'cancel_activation' : 'cancel',
              'key': plan == null ? activation!['key'] : const Uuid().v4(),
              'revision': plan?['revision'],
            }
          : intent ??
                <String, dynamic>{
                  'kind': method
                      ? 'method'
                      : (plan == null ? 'checkout' : 'amount'),
                  'key': const Uuid().v4(),
                  'cents': cents,
                  'revision': plan?['revision'],
                };
      if (intent == null && !cancel && !withdraw) {
        next['consent_version'] = guardianConsent;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, jsonEncode(next))) {
        throw const FormatException('No se pudo conservar el intento.');
      }
      if (!current) return;
      setState(() => intent = next);
      final result = await repo.submit(next);
      if (!current) return;
      if (!['checkout', 'method'].contains(next['kind'])) {
        await prefs.remove(storageKey);
        if (!current) return;
        intent = null;
        consent = false;
        // load() displays the authoritative request status, including withdrawal.
        message = null;
      } else if (result['checkout_url'] is String) {
        await repo.openCheckout(result['checkout_url'] as String);
      } else {
        message = next['kind'] == 'method'
            ? guardianMethodLabels[result['status']] ??
                  'Actualización en revisión.'
            : guardianActivationLabels[result['status']] ??
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
        activation?['cancellation_requested_at'] == null &&
        (activation == null ||
            [
              'no_capacity',
              'expired',
              'failed',
              'refunded',
            ].contains(activation?['status']));
    final canChange =
        status == 'active' &&
        pending == null &&
        !['pending', 'attention'].contains(methodSetup?['status']);
    final canCancel =
        status == 'active' ||
        (p == null &&
            activation != null &&
            activation?['cancellation_requested_at'] == null &&
            [
              'pending',
              'funded_pending_schedule',
              'attention',
            ].contains(activation?['status']));
    final verified =
        ref.watch(identityControllerProvider).identity?.verified == true;
    final canSubmit =
        !busy &&
        !confirming &&
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
          TextButton(
            onPressed: () => context.push('/guardian/history'),
            child: const Text('Ver historial de ciclos'),
          ),
          if (methodSetup != null && status == 'active')
            Notice(
              guardianMethodLabels[methodSetup!['status']] ??
                  'Medio de pago en revisión.',
            ),
          if (data?['payment_issue'] is Map &&
              [
                'authentication_required',
                'payment_failed',
              ].contains(data!['payment_issue']['reason']))
            Notice(
              data!['payment_issue']['status'] == 'skipped'
                  ? 'El último ciclo se omitió por rechazo o autenticación bancaria pendiente. No se volverá a cobrar ese ciclo. Puedes actualizar y autenticar tu medio para los próximos.'
                  : 'Un pago necesita revisión bancaria y sigue en conciliación. Espera su resultado antes de cambiar el medio de pago.',
            ),
          if (verified &&
              status == 'active' &&
              data?['method_change_available'] == true &&
              intent == null)
            TextButton(
              onPressed: busy || confirming || !fresh
                  ? null
                  : () => submit(method: true),
              child: const Text('Actualizar medio de pago'),
            ),
          if (pending is Map && pending['review_reason'] != null)
            Notice(
              guardianReviewLabels[pending['review_reason']] ??
                  'El cambio está en revisión.',
            ),
          if (pending is Map &&
              pending['can_withdraw'] == true &&
              intent == null)
            TextButton(
              onPressed: busy || confirming || !fresh
                  ? null
                  : () => submit(withdraw: true),
              child: const Text('Retirar cambio de monto'),
            ),
          if (intent?['kind'] == 'withdraw_amount')
            ActionButton(
              'Reintentar retiro del cambio',
              busy: busy,
              onPressed: canSubmit ? () => submit() : null,
            ),
          if (intent?['kind'] == 'method')
            ActionButton(
              'Continuar actualización en Stripe',
              busy: busy,
              onPressed: canSubmit ? () => submit() : null,
            ),
          if (activation?['cancellation_requested_at'] != null)
            Notice(switch (activation?['cancellation_status']) {
              'stopped' => 'Alta detenida. Consulta abajo el estado del primer pago; detener el alta no confirma una devolución.',
              'attention' =>
                'Cancelación del alta en revisión. No inicies otro pago.',
              _ => 'Cancelación del alta solicitada. Estamos confirmando el cierre con Stripe; un pago ya iniciado sigue en conciliación.',
            }),
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
                  'withdrawn' =>
                    'Solicitud retirada; se conservó el monto anterior.',
                  _ => 'Pendiente de confirmación.',
                }),
              ),
          ] else if (activation != null)
            Notice(
              guardianActivationLabels[activation!['status']] ??
                  'Estado del alta en revisión. No vuelvas a pagar.',
            ),
          if (!['method', 'withdraw_amount'].contains(intent?['kind']) &&
              (canStart || canChange || intent != null)) ...[
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
              onPressed: busy || confirming || !fresh
                  ? null
                  : () => submit(cancel: true),
              child: const Text('Cancelar mi plan'),
            ),
          if (error != null) Notice(error!, isError: true),
          if (message != null) Notice(message!),
          TextButton(
            onPressed: busy || confirming ? null : () => load(),
            child: const Text('Actualizar estado'),
          ),
        ],
      ],
    );
  }
}
