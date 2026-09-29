import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../../core/measurement.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_repository.dart';
import 'payment_repository.dart';
import 'guardian_repository.dart';

class ContributeScreen extends ConsumerStatefulWidget {
  const ContributeScreen(this.expense, {super.key, this.attempt});
  final String expense;
  final Json? attempt;
  @override
  ConsumerState<ContributeScreen> createState() => _ContributeState();
}

class _ContributeState extends ConsumerState<ContributeScreen>
    with WidgetsBindingObserver {
  final amount = TextEditingController(text: '50');
  bool busy = true, locked = false, reviewing = false;
  String? error, attemptKey;
  Json? outcome;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && attemptKey != null && !busy) {
      checkOutcome();
    }
  }

  String get storageKey =>
      'dopmi-payment:${ref.read(identityControllerProvider).identity?.id}:${widget.expense}';
  Future<void> trackOnce(String name) async {
    if (attemptKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$storageKey:measurement:$name:$attemptKey';
    if (prefs.getBool(key) == true) return;
    await ref.read(measurementControllerProvider)?.event(name);
    await prefs.setBool(key, true);
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          widget.attempt?['idempotency_key'] as String? ??
          prefs.getString('$storageKey:key');
      final cents =
          widget.attempt?['gross_cents'] as int? ??
          prefs.getInt('$storageKey:cents');
      if (mounted && key != null && cents != null) {
        setState(() {
          attemptKey = key;
          amount.text = (cents / 100).toStringAsFixed(2);
          locked = true;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = paymentError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    amount.dispose();
    super.dispose();
  }

  Future<void> checkOutcome() async {
    if (attemptKey == null) return;
    setState(() => busy = true);
    try {
      final page = await ref.read(paymentRepositoryProvider).history(1);
      final matches = page.items.where(
        (item) => item['idempotency_key'] == attemptKey,
      );
      if (!mounted || matches.isEmpty) return;
      outcome = matches.first;
      if (outcome!['payment_status'] == 'confirmed') {
        await trackOnce('contribution_confirmed');
      }
      final terminal = [
        'confirmed',
        'canceled',
        'refunded',
      ].contains(outcome!['payment_status']);
      if (terminal) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$storageKey:key');
        await prefs.remove('$storageKey:cents');
      }
    } catch (cause) {
      if (mounted) setState(() => error = paymentError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void review() {
    final cents = parsePesos(amount.text);
    if (cents == null || cents < 1000 || cents > 1000000) {
      setState(
        () => error = 'Escribe un importe de \$10 a \$10,000 MXN, con hasta dos decimales.',
      );
      return;
    }
    setState(() {
      reviewing = true;
      error = null;
    });
  }

  Future<void> pay() async {
    final cents = parsePesos(amount.text);
    if (cents == null || cents < 1000 || cents > 1000000) {
      setState(
        () => error = 'Escribe un importe de \$10 a \$10,000 MXN, con hasta dos decimales.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      attemptKey ??= const Uuid().v4();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$storageKey:key', attemptKey!);
      await prefs.setInt('$storageKey:cents', cents);
      if (!mounted) return;
      setState(() => locked = true);
      final repo = ref.read(paymentRepositoryProvider);
      final result = await repo.checkout(widget.expense, cents, attemptKey!);
      await trackOnce('contribution_started');
      if (!mounted) return;
      if (result['url'] is String) {
        await repo.openStripe(result['url'] as String);
        if (mounted) await checkOutcome();
      } else {
        await prefs.remove('$storageKey:key');
        await prefs.remove('$storageKey:cents');
        if (mounted) context.go('/payments');
      }
    } catch (cause) {
      if (mounted) setState(() => error = paymentError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      const Heading(
        'Ayuda con un gasto.',
        'Tu aportación se dirige al gasto aprobado que elegiste.',
        eyebrow: 'APORTACIÓN DE PRUEBA',
      ),
      LiveSection<Json>(
        errorMessage: paymentError,
        load: () => ref.read(paymentRepositoryProvider).funding(widget.expense),
        builder: (data, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              data['title'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Reembolso aprobado: ${pesos(data['reimbursable_cents'] as int)}',
            ),
            Text('Neto asignado: ${pesos(data['funded_cents'] as int)}'),
            Text(
              'Transferido a Stripe: ${pesos(data['transferred_cents'] as int? ?? 0)}',
            ),
            Text(
              'Disponible para aportaciones: ${pesos(data['available_cents'] as int)}',
            ),
            const SizedBox(height: 16),
            if (!reviewing && outcome == null) ...[
              Text(
                '¿Cuánto quieres aportar?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in [50, 150, 300])
                    ChoiceChip(
                      label: Text('\$$value'),
                      selected: parsePesos(amount.text) == value * 100,
                      onSelected: busy || locked
                          ? null
                          : (_) => setState(() => amount.text = '$value'),
                    ),
                ],
              ),
              TextField(
                controller: amount,
                enabled: !busy && !locked,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tu aportación en MXN',
                  prefixText: '\$ ',
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Notice(
              'Dopmi descuenta el 2% del importe cobrado y los costos de Stripe. El neto destinado al rescatista cuenta para el reembolso. El importe que no pueda asignarse se devuelve.',
            ),
            const Notice(
              'Solo pagos de prueba. Stripe mostrará el importe antes de confirmar. Al regresar, revisa tu historial para conocer el resultado.',
            ),
            if (reviewing && outcome == null)
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Resumen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Gasto'),
                        trailing: SizedBox(
                          width: 150,
                          child: Text(
                            data['title'] as String,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Importe'),
                        trailing: Text(pesos(parsePesos(amount.text) ?? 0)),
                      ),
                      const Text(
                        'El método de pago se captura de forma segura en Stripe.',
                      ),
                    ],
                  ),
                ),
              ),
            if (locked && outcome == null)
              const Notice(
                'Conservamos tu intento de pago. Continuar abre la misma aportación.',
              ),
            if (outcome != null) _PaymentOutcome(outcome!),
            if (error != null) Notice(error!, isError: true),
            if (outcome == null)
              ActionButton(
                reviewing || locked
                    ? (locked
                          ? 'Continuar mi aportación'
                          : 'Confirmar en Stripe')
                    : 'Revisar aportación',
                busy: busy,
                onPressed: locked
                    ? pay
                    : data['payable'] == true &&
                          (data['available_cents'] as int) > 0
                    ? (reviewing ? pay : review)
                    : null,
              ),
            if (reviewing && !locked && outcome == null)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() => reviewing = false),
                child: const Text('Cambiar monto'),
              ),
            if (locked && outcome == null)
              TextButton(
                onPressed: busy ? null : checkOutcome,
                child: const Text('Consultar resultado'),
              ),
            TextButton(
              onPressed: refresh,
              child: const Text('Actualizar disponibilidad'),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.push('/payments'),
        child: const Text('Ver mi historial'),
      ),
    ],
  );
}

class _PaymentOutcome extends StatelessWidget {
  const _PaymentOutcome(this.value);
  final Json value;
  @override
  Widget build(BuildContext context) {
    final status = value['payment_status'] as String? ?? 'pending';
    final confirmed = status == 'confirmed';
    return Card(
      color: confirmed
          ? const Color(0xffeef9f0)
          : status == 'pending'
          ? const Color(0xfffff8dc)
          : const Color(0xffffeeee),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              confirmed
                  ? Icons.check_circle
                  : status == 'pending'
                  ? Icons.hourglass_top
                  : Icons.credit_card_off,
              size: 44,
              color: confirmed ? Colors.green : ink,
            ),
            const SizedBox(height: 8),
            Text(
              switch (status) {
                'confirmed' => 'Pago confirmado',
                'canceled' => 'Pago cancelado',
                'refunded' => 'Pago devuelto',
                _ => 'Pago en procesamiento',
              },
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(switch (status) {
              'confirmed' => 'Stripe confirmó el pago. Consulta abajo su asignación y transferencia.',
              'canceled' => 'Stripe no confirmó un cobro para este intento.',
              'refunded' => 'El servidor confirmó la devolución del pago.',
              _ => 'Aún esperamos evidencia del procesador. No inicies otra aportación.',
            }, textAlign: TextAlign.center),
            if (confirmed)
              Text(
                'Asignado: ${pesos(value['allocated_cents'] as int? ?? 0)}',
                textAlign: TextAlign.center,
              ),
            if (confirmed)
              Text(
                transferLabels[value['transfer_status']] ??
                    'Transferencia en revisión',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});
  @override
  ConsumerState<PaymentHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<PaymentHistoryScreen> {
  int page = 1;
  bool received = false;
  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      const Heading(
        'Cada aportación, clara.',
        'Consulta pagos y transferencias confirmados.',
        eyebrow: 'HISTORIAL DE PRUEBA',
      ),
      if (ref.watch(guardianEnabledProvider))
        TextButton(
          onPressed: () => context.push('/guardian'),
          child: const Text('Mi plan Guardián'),
        ),
      const Notice(
        'Una transferencia llega a la cuenta Stripe del rescatista. El depósito bancario es un paso posterior y sus tiempos dependen de Stripe.',
      ),
      SwitchListTile(
        title: const Text('Ver aportaciones recibidas'),
        value: received,
        onChanged: (value) => setState(() {
          received = value;
          page = 1;
        }),
      ),
      LiveSection<DataPage<Json>>(
        key: ValueKey('$received:$page'),
        errorMessage: paymentError,
        tables: const ['dopmi_donations'],
        load: () => ref
            .read(paymentRepositoryProvider)
            .history(page, received: received),
        builder: (data, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.items.isEmpty)
              const Notice('Todavía no hay aportaciones en este historial.'),
            for (final d in data.items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['expense_title'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('Importe: ${pesos(d['gross_cents'] as int)}'),
                      Text(
                        paymentLabels[d['payment_status']] ??
                            'Estado en revisión',
                      ),
                      Text(
                        transferLabels[d['transfer_status']] ??
                            'Transferencia en revisión',
                      ),
                      if (d['processed_at'] != null) ...[
                        Text(
                          'Comisión Dopmi: ${pesos(d['platform_fee_cents'] as int)}',
                        ),
                        Text(
                          'Costos de Stripe: ${pesos(d['stripe_fee_cents'] as int)}',
                        ),
                        Text(
                          'Neto para el rescatista: ${pesos(d['allocated_cents'] as int)}',
                        ),
                        if ((d['refund_cents'] as int) > 0)
                          Text(
                            '${d['refund_status'] == 'refunded' ? 'Devuelto' : 'Devolución en proceso'}: ${pesos(d['refund_cents'] as int)}',
                          ),
                      ],
                      if (!received && d['payment_status'] == 'pending')
                        TextButton(
                          onPressed: () => context.push(
                            '/contribute/${d['expense_id']}',
                            extra: d,
                          ),
                          child: const Text('Continuar aportación'),
                        ),
                      Text(
                        'Referencia: ${d['id']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            TextButton(
              onPressed: refresh,
              child: const Text('Actualizar historial'),
            ),
            PageControls(
              page: page,
              total: data.total,
              size: 20,
              change: (p) => setState(() => page = p),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.push('/connect'),
        child: const Text('Mi cuenta de cobro y depósitos'),
      ),
    ],
  );
}

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});
  @override
  ConsumerState<ConnectScreen> createState() => _ConnectState();
}

class _ConnectState extends ConsumerState<ConnectScreen> {
  bool busy = false;
  String? error;
  Future<void> onboard() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final result = await repo.action('connect_onboard');
      if (mounted) await repo.openStripe(result['url'] as String);
    } catch (cause) {
      if (mounted) setState(() => error = paymentError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      const Heading(
        'Tu cuenta de cobro.',
        'Configura tus datos bancarios directamente en Stripe.',
        eyebrow: 'STRIPE CONNECT · PRUEBA',
      ),
      const Notice(
        'Primero necesitas la verificación de rescatista aprobada por Dopmi. Completar el formulario de Stripe no garantiza que tu cuenta ya pueda recibir transferencias.',
      ),
      LiveSection<Json>(
        errorMessage: paymentError,
        load: () =>
            ref.read(paymentRepositoryProvider).action('connect_status'),
        builder: (data, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data['verified'] == false)
              const Notice(
                'Tu verificación de rescatista está pendiente. Puedes consultar tu historial, pero no iniciar nuevos cobros.',
              ),
            Text(
              data['ready'] == true
                  ? 'Cuenta habilitada para recibir aportaciones de prueba'
                  : 'Tu cuenta todavía necesita completar su configuración',
            ),
            Text(
              'Transferencias: ${data['transfers_enabled'] == true ? 'habilitadas' : 'pendientes'}',
            ),
            Text(
              'Depósitos: ${data['payouts_enabled'] == true ? 'habilitados' : 'pendientes'}',
            ),
            TextButton(
              onPressed: refresh,
              child: const Text('Actualizar estado'),
            ),
            const Text('Últimos depósitos de tu cuenta Stripe'),
            const Text(
              'Pueden agrupar varias transferencias. No corresponden necesariamente a una sola aportación.',
            ),
            for (final p in data['payouts'] as List? ?? [])
              ListTile(
                title: Text(
                  '${pesos(p['amount'] as int)} ${p['currency'].toString().toUpperCase()}',
                ),
                subtitle: Text(switch (p['status']) {
                  'paid' => 'Depositado según Stripe',
                  'failed' => 'Depósito fallido',
                  'canceled' => 'Depósito cancelado',
                  _ => 'Depósito en proceso',
                }),
              ),
          ],
        ),
      ),
      if (error != null) Notice(error!, isError: true),
      ActionButton('Completar datos en Stripe', busy: busy, onPressed: onboard),
    ],
  );
}
