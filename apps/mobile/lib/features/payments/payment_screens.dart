import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../../core/reference_switch.dart';
import '../../core/measurement.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_repository.dart';
import 'payment_repository.dart';
import 'guardian_repository.dart';
import 'contribution_layout.dart';
import 'payment_result_page.dart';
import 'payment_history_row.dart';
import 'guardian_history_screen.dart';

class ContributeScreen extends ConsumerStatefulWidget {
  const ContributeScreen(
    this.expense, {
    super.key,
    this.attempt,
    this.initialCents,
    this.caseId,
  });
  final String expense;
  final String? caseId;
  final int? initialCents;
  final Json? attempt;
  @override
  ConsumerState<ContributeScreen> createState() => _ContributeState();
}

class _ContributeState extends ConsumerState<ContributeScreen>
    with WidgetsBindingObserver {
  final amount = TextEditingController(text: '50');
  bool busy = true, locked = false, reviewing = false;
  String? error, attemptKey;
  String? checkoutLabel;
  Json? outcome;
  String? publicCaseId, publicCaseName;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final seed = widget.initialCents;
    if (seed != null && seed >= 1000 && seed <= 1000000) {
      amount.text = (seed / 100).toStringAsFixed(2);
      reviewing = true;
    }
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
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .outcome(widget.expense, attemptKey!);
      if (!mounted) return;
      if (result == null) {
        outcome = null;
        error = 'Aún no encontramos evidencia de este intento. Vuelve a consultar; no inicies otra aportación.';
        return;
      }
      outcome = result;
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
    if (busy) return;
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
      checkoutLabel = locked
          ? 'Continuar mi aportación'
          : 'Confirmar en Stripe';
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
      if (mounted) {
        setState(() {
          busy = false;
          checkoutLabel = null;
        });
      }
    }
  }

  Future<Json> loadFunding() async {
    publicCaseId = null;
    publicCaseName = null;
    final data = await ref
        .read(paymentRepositoryProvider)
        .funding(widget.expense);
    final caseId = widget.caseId;
    if (caseId == null) return data;
    try {
      final catalog = await ref
          .read(rescueRepositoryProvider)
          .completeCaseCatalog(caseId);
      final matchingExpense = catalog.items.any(
        (record) =>
            record.id == widget.expense &&
            record.kind == 'expense' &&
            record.parent == caseId,
      );
      final cases = catalog.items.where(
        (record) => record.id == caseId && record.kind == 'case',
      );
      if (matchingExpense && cases.isNotEmpty) {
        publicCaseId = cases.first.id;
        publicCaseName = cases.first.title;
        return {...data, 'public_case': cases.first};
      }
    } catch (_) {
      // Funding stays authoritative; a failed public photo/context read cannot
      // replace it with a guessed case, method or amount.
    }
    return data;
  }

  void back() {
    if (reviewing && !locked && outcome == null) {
      setState(() => reviewing = false);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        widget.caseId == null ? '/payments' : '/rescue-cases/${widget.caseId}',
      );
    }
  }

  void retryCanceled() {
    if (busy || outcome?['payment_status'] != 'canceled') return;
    // A new route creates a fresh attempt only after explicit confirmation.
    // The terminal attempt was cleared by the authoritative history check.
    context.push(
      Uri(
        path: '/contribute/${widget.expense}',
        queryParameters: {
          'case': ?publicCaseId,
          if (parsePesos(amount.text) case final int cents)
            'amount_cents': '$cents',
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = outcome;
    if (result != null) {
      return PaymentResultPage(
        value: result,
        refresh: checkOutcome,
        back: back,
        retry: result['payment_status'] == 'canceled' ? retryCanceled : null,
        caseId: publicCaseId,
        caseName: publicCaseName,
        busy: busy,
        error: error,
      );
    }
    return PopScope(
      canPop: !reviewing || locked || outcome != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) back();
      },
      child: ContributionFrame(
        title: outcome != null
            ? 'Tu aportación'
            : reviewing || locked
            ? 'Revisa tu donación'
            : 'Elige tu aportación',
        back: busy ? null : back,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: LiveSection<Json>(
            errorMessage: paymentError,
            load: loadFunding,
            builder: (data, refresh) {
              final record = data['public_case'] as RescueRecord?;
              final title = data['title'] as String;
              final payable =
                  data['payable'] == true &&
                  (data['available_cents'] as int) > 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContributionCaseHeader(expenseTitle: title, record: record),
                  const SizedBox(height: 18),
                  if (!reviewing && !locked && outcome == null) ...[
                    const Text(
                      '¿Cuánto quieres donar?',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final cents in {
                            5000,
                            15000,
                            30000,
                            if ((data['available_cents'] as int) > 0)
                              data['available_cents'] as int,
                          })
                            SizedBox(
                              width:
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      22
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 10) / 2,
                              child: OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => amount.text = (cents / 100)
                                            .toStringAsFixed(2),
                                      ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      parsePesos(amount.text) == cents
                                      ? const Color(0xfffff8d7)
                                      : Colors.white,
                                  foregroundColor: ink,
                                  padding: const EdgeInsets.all(16),
                                  side: BorderSide(
                                    color: parsePesos(amount.text) == cents
                                        ? yellow
                                        : const Color(0xffe6e2dd),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  pesos(cents),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 18),
                  ],
                  if ((reviewing || locked) && outcome == null) ...[
                    const Text(
                      'Resumen',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 33.77),
                    ContributionSummary(
                      rows: [
                        if (record != null) ('Caso', record.title),
                        ('Necesidad', title),
                        (
                          'Monto',
                          contributionMoney(parsePesos(amount.text) ?? 0),
                        ),
                        ('Método', 'En Stripe'),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (locked && outcome == null) ...[
                    const Notice(
                      'Conservamos tu intento de pago. Continuar abre la misma aportación.',
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (error != null) Notice(error!, isError: true),
                  if (outcome == null)
                    ContributionButton(
                      checkoutLabel ??
                          (reviewing || locked
                              ? (locked
                                    ? 'Continuar mi aportación'
                                    : 'Confirmar en Stripe')
                              : 'Revisar aportación'),
                      busy: busy,
                      onPressed: locked
                          ? pay
                          : payable
                          ? (reviewing ? pay : review)
                          : null,
                    ),
                  if (reviewing && !locked && outcome == null) ...[
                    const SizedBox(height: 18),
                    ContributionButton(
                      'Cambiar monto',
                      secondary: true,
                      onPressed: busy
                          ? null
                          : () => setState(() => reviewing = false),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Solo pagos de prueba. El método de pago se captura de forma segura en Stripe. Stripe mostrará el importe antes de confirmar.',
                    style: TextStyle(fontSize: 13, height: 1.55, color: muted),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dopmi descuenta el 2% del importe cobrado y los costos de Stripe. El neto destinado al rescatista cuenta para el reembolso. El importe que no pueda asignarse se devuelve.',
                    style: TextStyle(fontSize: 13, height: 1.55, color: muted),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Reembolso aprobado: ${pesos(data['reimbursable_cents'] as int)}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  Text(
                    'Neto asignado: ${pesos(data['funded_cents'] as int)}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  Text(
                    'Transferido a Stripe: ${pesos(data['transferred_cents'] as int? ?? 0)}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  Text(
                    'Disponible para aportaciones: ${pesos(data['available_cents'] as int)}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  if (locked && outcome == null)
                    TextButton(
                      onPressed: busy ? null : checkOutcome,
                      child: const Text('Consultar resultado'),
                    ),
                  TextButton(
                    onPressed: busy ? null : refresh,
                    child: const Text('Actualizar disponibilidad'),
                  ),
                  TextButton(
                    onPressed: () => context.push('/payments'),
                    child: const Text('Ver mi historial'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class PaymentHistoryData {
  const PaymentHistoryData(
    this.donations,
    this.guardian, [
    this.caseNames = const {},
  ]);
  final Map<String, String> caseNames;
  final DataPage<Json> donations;
  final Json? guardian;
  List<Json> get cycles => (guardian?['items'] as List? ?? [])
      .map((item) => Json.from(item))
      .toList();
}

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});
  @override
  ConsumerState<PaymentHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<PaymentHistoryScreen> {
  int page = 1;
  bool received = false;
  bool openingCase = false;

  Future<void> openCase(String expenseId) async {
    if (openingCase) return;
    final owner = ref.read(identityControllerProvider).identity?.id;
    openingCase = true;
    try {
      final caseId = await ref
          .read(rescueRepositoryProvider)
          .publicCaseForExpense(expenseId);
      if (!mounted ||
          ref.read(identityControllerProvider).identity?.id != owner) {
        return;
      }
      if (caseId != null) {
        context.push('/rescue-cases/$caseId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este caso ya no está disponible.')),
        );
      }
    } catch (_) {
      if (mounted &&
          ref.read(identityControllerProvider).identity?.id == owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos abrir el caso. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      openingCase = false;
    }
  }

  Future<PaymentHistoryData> loadHistory() async {
    final includeGuardian =
        ref.read(guardianEnabledProvider) && !received && page == 1;
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final guardianRepo = includeGuardian
        ? ref.read(guardianRepositoryProvider)
        : null;
    final results = await Future.wait<Object?>([
      paymentRepo.history(page, received: received),
      if (guardianRepo != null) guardianRepo.history(),
    ]);
    final donations = results.first as DataPage<Json>;
    final caseNames = <String, String>{};
    final expenses = donations.items
        .map((d) => d['expense_id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    await Future.wait(
      expenses.map((expenseId) async {
        try {
          final record = await ref
              .read(rescueRepositoryProvider)
              .publicCaseRecordForExpense(expenseId);
          final name = record?.publicData['pet_name'] as String?;
          if (name != null && name.trim().isNotEmpty) {
            caseNames[expenseId] = name;
          }
        } catch (_) {
          // Public catalog availability never hides private financial evidence.
        }
      }),
    );
    return PaymentHistoryData(
      donations,
      results.length > 1 ? results[1] as Json : null,
      caseNames,
    );
  }

  @override
  Widget build(BuildContext context) => ContributionFrame(
    title: 'Mi historial',
    back: () => context.canPop() ? context.pop() : context.go('/profile'),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Consulta todo tu historial de pagos.',
            style: TextStyle(fontSize: 14, height: 1.55, color: muted),
          ),
          const SizedBox(height: 26),
          LiveSection<PaymentHistoryData>(
            key: ValueKey(
              '$received:$page:${ref.watch(guardianEnabledProvider)}',
            ),
            errorMessage: paymentError,
            // Guardian cycles are private; their authorized RPC refreshes with this section.
            tables: const ['dopmi_donations'],
            load: loadHistory,
            builder: (data, refresh) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data.donations.items.isEmpty && data.cycles.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xfff7f5f1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'Aún no hay movimientos en tu historial.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: muted,
                      ),
                    ),
                  )
                else
                  Material(
                    clipBehavior: Clip.antiAlias,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xffe6e2dd)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < data.cycles.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xffe6e2dd)),
                          GuardianHistoryEntry(
                            key: ValueKey('guardian:${data.cycles[i]['id']}'),
                            item: data.cycles[i],
                            owner: ref
                                .read(identityControllerProvider)
                                .identity!
                                .id,
                          ),
                        ],
                        if (data.cycles.isNotEmpty &&
                            data.donations.items.isNotEmpty)
                          const Divider(height: 1, color: Color(0xffe6e2dd)),
                        for (
                          var i = 0;
                          i < data.donations.items.length;
                          i++
                        ) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xffe6e2dd)),
                          for (final d in [data.donations.items[i]])
                            PaymentHistoryRow(
                              key: ValueKey(d['id']),
                              payment: d,
                              caseName: data.caseNames[d['expense_id']],
                              onOpenCase:
                                  d['expense_id'] is String &&
                                      (d['expense_id'] as String).isNotEmpty
                                  ? () => openCase(d['expense_id'] as String)
                                  : null,
                              details: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['expense_title'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  Text(
                                    'Importe: ${pesos(d['gross_cents'] as int)}',
                                  ),
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
                                  if (!received &&
                                      d['payment_status'] == 'pending')
                                    TextButton(
                                      onPressed: () => context.push(
                                        '/contribute/${d['expense_id']}',
                                        extra: d,
                                      ),
                                      child: const Text('Continuar aportación'),
                                    ),
                                  Text(
                                    'Referencia: ${d['id']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                if (data.guardian?['next_cursor'] != null)
                  TextButton(
                    onPressed: () => context.push('/guardian/history'),
                    child: const Text('Ver ciclos anteriores de Guardián'),
                  ),
                TextButton(
                  onPressed: refresh,
                  child: const Text('Actualizar historial'),
                ),
                PageControls(
                  page: page,
                  total: data.donations.total,
                  size: 20,
                  change: (p) => setState(() => page = p),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Text('Ver aportaciones recibidas')),
                const SizedBox(width: 12),
                ReferenceSwitch(
                  value: received,
                  label: 'Ver aportaciones recibidas',
                  onChanged: (value) => setState(() {
                    received = value;
                    page = 1;
                  }),
                ),
              ],
            ),
          ),
          if (ref.watch(guardianEnabledProvider))
            TextButton(
              onPressed: () => context.push('/guardian'),
              child: const Text('Mi plan Guardián'),
            ),
          const Notice(
            'Una transferencia llega a la cuenta Stripe del rescatista. El depósito bancario es un paso posterior y sus tiempos dependen de Stripe.',
          ),
          TextButton(
            onPressed: () => context.push('/connect'),
            child: const Text('Mi cuenta de cobro y depósitos'),
          ),
        ],
      ),
    ),
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
  Widget build(BuildContext context) => ContributionFrame(
    title: 'Tu cuenta de cobro',
    rescuer: true,
    back: () =>
        context.canPop() ? context.pop() : context.go('/settings/account'),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          'STRIPE CONNECT · PRUEBA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: purple,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configura tus datos bancarios directamente en Stripe.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xff4f4e5c),
          ),
        ),
        const SizedBox(height: 20),
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
                    '${pesos(p['amount'] as int).replaceFirst(' MXN', '')} ${p['currency'].toString().toUpperCase()}',
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
        ActionButton(
          'Completar datos en Stripe',
          busy: busy,
          onPressed: onboard,
        ),
      ],
    ),
  );
}
