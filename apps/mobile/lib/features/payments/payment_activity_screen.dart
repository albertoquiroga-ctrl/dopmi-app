import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_public_photo.dart';
import 'contribution_layout.dart';
import 'payment_activity_repository.dart';

const paymentActivityStatuses = {
  'processing': 'En conciliación',
  'confirmed': 'Pago confirmado',
  'review': 'En revisión',
  'not_paid': 'Sin pago confirmado',
  'skipped': 'Ciclo omitido sin cargo ni deuda',
  'assigned': 'Neto asignado',
  'transferred': 'Neto transferido',
  'refund_pending': 'Devolución en proceso',
  'refund_reconciling': 'Devolución y transferencias en conciliación',
  'refund_review': 'Devolución en revisión',
  'refunded': 'Devuelto',
  'partial_refund': 'Devolución parcial confirmada',
  'partial_reversal': 'Reversión parcial de transferencia',
  'reversed': 'Transferencia revertida',
};

class PaymentActivityScreen extends ConsumerWidget {
  const PaymentActivityScreen({super.key, this.received = false});
  final bool received;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityControllerProvider);
    return ListenableBuilder(
      listenable: identity,
      builder: (_, _) {
        final owner = identity.identity?.id;
        return owner == null
            ? const SizedBox.shrink()
            : _ActivityList(
                key: ValueKey('$owner:$received'),
                owner: owner,
                received: received,
              );
      },
    );
  }
}

class _ActivityList extends ConsumerStatefulWidget {
  const _ActivityList({super.key, required this.owner, required this.received});
  final String owner;
  final bool received;
  @override
  ConsumerState<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends ConsumerState<_ActivityList> {
  final items = <Json>[];
  Json? cursor;
  String? error;
  bool busy = false;
  bool retryMore = false;
  int generation = 0;
  bool get current =>
      mounted &&
      ref.read(identityControllerProvider).identity?.id == widget.owner;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (!current || busy) return;
    final request = ++generation;
    retryMore = more;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await ref
          .read(paymentActivityRepositoryProvider)
          .page(received: widget.received, cursor: more ? cursor : null);
      if (!current || request != generation) return;
      final page = (data['items'] as List)
          .map((v) => Json.from(v as Map))
          .toList();
      setState(() {
        if (!more) items.clear();
        final ids = items.map((v) => '${v['kind']}:${v['id']}').toSet();
        items.addAll(page.where((v) => ids.add('${v['kind']}:${v['id']}')));
        cursor = data['next_cursor'] == null
            ? null
            : Json.from(data['next_cursor'] as Map);
        busy = false;
      });
    } catch (_) {
      if (current && request == generation) {
        setState(() {
          busy = false;
          error = 'No pudimos consultar tu historial. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Mi historial'),
      leading: IconButton(
        tooltip: 'Volver',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: () => load(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Consulta todos los '),
                const TextSpan(
                  text: '+Apoyos',
                  style: TextStyle(
                    color: Color(0xff0b7a5d),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.received)
                  const TextSpan(text: ' que ha recibido tu manada.')
                else ...[
                  const TextSpan(text: ' que recibió la manada '),
                  const TextSpan(
                    text: 'gracias a ti.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
            style: const TextStyle(fontSize: 14, height: 1.45, color: ink),
          ),
          const SizedBox(height: 20),
          if (error != null) Notice(error!, isError: true),
          if (busy && items.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (!busy && error == null && items.isEmpty)
            const Text('Aún no hay movimientos en tu historial.'),
          for (final item in items)
            PaymentActivityCard(
              key: ValueKey('${widget.owner}:${item['kind']}:${item['id']}'),
              item: item,
              received: widget.received,
              owner: widget.owner,
            ),
          if (error != null)
            TextButton(
              onPressed: busy ? null : () => load(more: retryMore),
              child: const Text('Reintentar historial'),
            ),
          if (cursor != null && error == null)
            TextButton(
              onPressed: busy ? null : () => load(more: true),
              child: Text(busy ? 'Cargando…' : 'Ver movimientos anteriores'),
            ),
        ],
      ),
    ),
  );
}

class PaymentActivityCard extends ConsumerStatefulWidget {
  const PaymentActivityCard({
    super.key,
    required this.item,
    required this.received,
    required this.owner,
  });
  final Json item;
  final bool received;
  final String owner;
  @override
  ConsumerState<PaymentActivityCard> createState() =>
      _PaymentActivityCardState();
}

class _PaymentActivityCardState extends ConsumerState<PaymentActivityCard> {
  bool expanded = false, busy = false;
  bool loaded = false;
  int allocationGeneration = 0;
  String? error, cursor;
  final allocations = <Json>[];
  @override
  void didUpdateWidget(covariant PaymentActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['status'] != widget.item['status'] ||
        oldWidget.item['reversed_cents'] != widget.item['reversed_cents'] ||
        oldWidget.item['transferred_cents'] !=
            widget.item['transferred_cents'] ||
        oldWidget.item['allocation_count'] != widget.item['allocation_count']) {
      loaded = false;
      allocationGeneration++;
      busy = false;
      allocations.clear();
      cursor = null;
      if (expanded && widget.item['kind'] == 'guardian') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (current) loadAllocations();
        });
      }
    }
  }

  bool get current =>
      mounted &&
      ref.read(identityControllerProvider).identity?.id == widget.owner;
  Future<void> loadAllocations({bool more = false}) async {
    if (busy || !current) return;
    final request = ++allocationGeneration;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await ref
          .read(paymentActivityRepositoryProvider)
          .allocations(
            widget.item['id'] as String,
            received: widget.received,
            afterExpense: more ? cursor : null,
          );
      if (!current || request != allocationGeneration) return;
      setState(() {
        if (!more) allocations.clear();
        final ids = allocations.map((v) => v['expense_id']).toSet();
        allocations.addAll(
          (data['items'] as List)
              .map((v) => Json.from(v as Map))
              .where((v) => ids.add(v['expense_id'])),
        );
        cursor = data['next_cursor'] as String?;
        loaded = true;
        busy = false;
      });
    } catch (_) {
      if (current && request == allocationGeneration) {
        setState(() {
          busy = false;
          error = 'No pudimos consultar las asignaciones.';
        });
      }
    }
  }

  Widget amount(String label, String key) {
    final value = widget.item[key];
    return value is num
        ? Text(
            '$label: ${contributionMoney(value.toInt())}',
            style: const TextStyle(fontSize: 12, height: 1.5, color: muted),
          )
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.item;
    final guardian = d['kind'] == 'guardian';
    final date = DateTime.tryParse(d['created_at']?.toString() ?? '')
        ?.toLocal();
    final status = paymentActivityStatuses[d['status']] ?? 'En revisión';
    final count = (d['allocation_count'] as num? ?? 0).toInt();
    final title = guardian
        ? '${d['title']} · $count ${count == 1 ? 'asignación' : 'asignaciones'}'
        : [
            d['title'],
            d['case_name'],
          ].whereType<String>().where((s) => s.isNotEmpty).join(' - ');
    final photo = d['photo'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1415110d),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0x0a15110d)),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: expanded,
                child: InkWell(
                  onTap: () {
                    setState(() => expanded = !expanded);
                    if (expanded && guardian && !loaded) loadAllocations();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final photoWidget = SizedBox(
                          width: 52,
                          height: 52,
                          child: photo != null && photo.isNotEmpty
                              ? RescuePublicPhoto(
                                  photo,
                                  height: 52,
                                  radius: 16,
                                  compact: true,
                                )
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xfff7f5f1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.pets, color: ink),
                                ),
                        );
                        final textWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            Text(
                              date == null
                                  ? 'Fecha por confirmar'
                                  : '${date.day}/${date.month}/${date.year}',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: muted,
                              ),
                            ),
                            Text(
                              status,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: muted,
                              ),
                            ),
                          ],
                        );
                        final moneyWidget = ActivityMoney(
                          cents: (d['amount_cents'] as num? ?? 0).toInt(),
                          negative: const [
                            'not_paid',
                            'reversed',
                            'review',
                            'refund_review',
                          ].contains(d['status']),
                        );
                        final scaler = MediaQuery.textScalerOf(context);
                        double textWidth(String value, double size) {
                          final painter = TextPainter(
                            text: TextSpan(
                              text: value,
                              style: TextStyle(
                                fontFamily: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.fontFamily,
                                fontSize: size,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: scaler,
                          )..layout();
                          final width = painter.width;
                          painter.dispose();
                          return width;
                        }

                        var minimumTextWidth = textWidth(
                          date == null
                              ? 'Fecha por confirmar'
                              : '${date.day}/${date.month}/${date.year}',
                          12,
                        );
                        for (final word in title.split(RegExp(r'\s+'))) {
                          final width = textWidth(word, 15);
                          if (width > minimumTextWidth) {
                            minimumTextWidth = width;
                          }
                        }
                        for (final word in status.split(RegExp(r'\s+'))) {
                          final width = textWidth(word, 11);
                          if (width > minimumTextWidth) {
                            minimumTextWidth = width;
                          }
                        }
                        final amountWidth = textWidth(
                          '+${contributionMoney((d['amount_cents'] as num? ?? 0).toInt()).replaceAll(' MXN', '')}',
                          15,
                        );
                        // Keep whole words and the date readable beside the amount.
                        final stack =
                            bounds.maxWidth <
                            74 + minimumTextWidth + amountWidth;
                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              photoWidget,
                              const SizedBox(height: 12),
                              textWidget,
                              const SizedBox(height: 12),
                              moneyWidget,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            photoWidget,
                            const SizedBox(width: 14),
                            Expanded(child: textWidget),
                            const SizedBox(width: 8),
                            moneyWidget,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      amount(
                        widget.received
                            ? 'Neto asignado'
                            : d['payment_status'] == 'confirmed' ||
                                  d['payment_status'] == 'refunded' ||
                                  (guardian && d['processed_at'] != null)
                            ? 'Importe pagado'
                            : 'Importe solicitado',
                        'amount_cents',
                      ),
                      if (guardian && !widget.received)
                        amount('Importe autorizado', 'authorized_cents'),
                      if (d['processed_at'] != null) ...[
                        if (!widget.received) ...[
                          amount('Comisión Dopmi', 'platform_fee_cents'),
                          amount('Costos de Stripe', 'stripe_fee_cents'),
                        ],
                        amount('Neto para el rescatista', 'net_cents'),
                      ],
                      Text(
                        'Referencia: ${d['id']}',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      if (!guardian &&
                          !widget.received &&
                          d['payment_status'] == 'pending' &&
                          d['idempotency_key'] is String &&
                          d['expense_id'] is String)
                        TextButton(
                          onPressed: () {
                            if (!current) return;
                            context.push(
                              '/contribute/${d['expense_id']}',
                              extra: {
                                'id': d['id'],
                                'expense_id': d['expense_id'],
                                'gross_cents': d['gross_cents'],
                                'idempotency_key': d['idempotency_key'],
                              },
                            );
                          },
                          child: const Text('Continuar aportación'),
                        ),
                      amount('Asignado', 'assigned_cents'),
                      amount('Transferido', 'transferred_cents'),
                      amount('Revertido', 'reversed_cents'),
                      if (!widget.received) ...[
                        amount('Devolución pendiente', 'refund_cents'),
                        amount('Devuelto', 'refunded_cents'),
                      ],
                      if (d['case_id'] is String)
                        TextButton(
                          onPressed: () =>
                              context.push('/rescue-cases/${d['case_id']}'),
                          child: const Text('Ver caso'),
                        ),
                      for (final a in allocations)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a['title']} · ${contributionMoney((a['allocated_cents'] as num).toInt())}',
                              ),
                              Text(
                                paymentActivityStatuses[a['status']] ??
                                    'En revisión',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                              if (a['remaining_cents'] is num)
                                Text(
                                  'Neto vigente: ${contributionMoney((a['remaining_cents'] as num).toInt())}',
                                ),
                              if ((a['transferred_cents'] as num? ?? 0) > 0)
                                Text(
                                  'Neto transferido: ${contributionMoney((a['transferred_cents'] as num).toInt())}',
                                ),
                              if ((a['reversed_cents'] as num? ?? 0) > 0)
                                Text(
                                  'Revertido: ${contributionMoney((a['reversed_cents'] as num).toInt())}',
                                ),
                              if (a['case_id'] is String)
                                TextButton(
                                  onPressed: () => context.push(
                                    '/rescue-cases/${a['case_id']}',
                                  ),
                                  child: Text(
                                    a['case_name'] as String? ?? 'Ver caso',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (busy)
                        const Center(child: CircularProgressIndicator()),
                      if (error != null) ...[
                        Notice(error!, isError: true),
                        TextButton(
                          onPressed: () =>
                              loadAllocations(more: allocations.isNotEmpty),
                          child: const Text('Reintentar asignaciones'),
                        ),
                      ],
                      if (cursor != null && !busy && error == null)
                        TextButton(
                          onPressed: () => loadAllocations(more: true),
                          child: const Text('Ver más asignaciones'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityMoney extends StatelessWidget {
  const ActivityMoney({super.key, required this.cents, required this.negative});
  final int cents;
  final bool negative;
  @override
  Widget build(BuildContext context) {
    final label = contributionMoney(cents).replaceAll(' MXN', '');
    final parts = label.split('.');
    return Semantics(
      label: '${negative ? '' : '+'}$label MXN',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${negative ? '' : '+'}${parts.first}'),
            if (parts.length > 1)
              WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: Text(
                  '.${parts.last}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: negative
                        ? const Color(0xffb51224)
                        : const Color(0xff12805c),
                  ),
                ),
              ),
          ],
        ),
        style: TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
          color: negative ? const Color(0xffb51224) : const Color(0xff12805c),
        ),
      ),
    );
  }
}
