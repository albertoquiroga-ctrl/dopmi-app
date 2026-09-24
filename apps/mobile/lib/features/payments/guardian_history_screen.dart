import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_repository.dart';
import 'guardian_repository.dart';

String _date(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return parsed == null
      ? 'Por confirmar'
      : '${parsed.day}/${parsed.month}/${parsed.year}';
}

const _statusLabels = {
  'processing': 'En conciliación',
  'review': 'En revisión',
  'not_paid': 'Intento cerrado sin pago confirmado',
  'skipped': 'Ciclo omitido sin cargo ni deuda',
  'assigned': 'Pago confirmado · neto asignado',
  'transferred': 'Neto transferido',
  'refund_pending': 'Devolución en proceso',
  'refund_reconciling':
      'Devolución confirmada · transferencias en conciliación',
  'refund_review': 'Devolución en revisión',
  'refunded': 'Devolución confirmada',
};

class GuardianHistoryScreen extends ConsumerWidget {
  const GuardianHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityControllerProvider);
    return ListenableBuilder(
      listenable: identity,
      builder: (context, child) {
        final owner = identity.identity?.id;
        return owner == null
            ? const SizedBox.shrink()
            : _GuardianHistory(key: ValueKey(owner), owner: owner);
      },
    );
  }
}

class _GuardianHistory extends ConsumerStatefulWidget {
  const _GuardianHistory({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<_GuardianHistory> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<_GuardianHistory> {
  final items = <Json>[];
  Json? cursor;
  String? error;
  bool busy = false;
  int revision = 0;
  String get owner => widget.owner;
  bool get current =>
      mounted && ref.read(identityControllerProvider).identity?.id == owner;

  @override
  void initState() {
    super.initState();
    if (ref.read(guardianEnabledProvider)) load();
  }

  Future<void> load({bool more = false}) async {
    if (!current || busy || !ref.read(guardianEnabledProvider)) return;
    setState(() {
      busy = true;
      error = null;
      if (!more) {
        items.clear();
        cursor = null;
        revision++;
      }
    });
    try {
      final page = await ref
          .read(guardianRepositoryProvider)
          .history(cursor: more ? cursor : null);
      if (!current) return;
      setState(() {
        final known = items.map((item) => item['id']).toSet();
        items.addAll(
          (page['items'] as List)
              .map((item) => Json.from(item))
              .where((item) => known.add(item['id'])),
        );
        cursor = page['next_cursor'] is Map
            ? Json.from(page['next_cursor'])
            : null;
      });
    } catch (_) {
      if (current) {
        setState(
          () => error = 'No pudimos consultar el historial. Intenta de nuevo.',
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(guardianEnabledProvider);
    if (ref.watch(identityControllerProvider).identity?.id != owner) {
      return const SizedBox.shrink();
    }
    return CommunityFrame(
      children: [
        const Heading(
          'Historial de ciclos',
          'Consulta tus aportaciones, asignaciones y devoluciones.',
          eyebrow: 'GUARDIÁN · PRUEBA',
        ),
        if (!enabled) const Notice('Guardián todavía no está disponible.'),
        if (enabled) ...[
          const Notice(
            'Una transferencia al rescatista no confirma un depósito en su banco. Los ciclos omitidos no acumulan deuda.',
          ),
          TextButton(
            onPressed: busy ? null : () => load(),
            child: const Text('Actualizar historial'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (!busy && error == null && items.isEmpty)
            const Notice('Todavía no tienes ciclos registrados.'),
          for (final item in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['kind'] == 'initial'
                          ? 'Intento de alta'
                          : item['kind'] == 'monthly'
                          ? 'Ciclo mensual'
                          : 'Ciclo'} · ${_date(item['period_start'] ?? item['created_at'])}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (item['period_end'] != null)
                      Text(
                        'Siguiente aniversario de este ciclo: ${_date(item['period_end'])}',
                      ),
                    Text(
                      _statusLabels[item['status']] ?? 'Estado por confirmar',
                    ),
                    Text(
                      'Importe autorizado: ${pesos(item['authorized_cents'] as int)}',
                    ),
                    if (item['paid_cents'] != null) ...[
                      Text(
                        'Pago confirmado: ${pesos(item['paid_cents'] as int)}',
                      ),
                      Text(
                        'Comisión Dopmi: ${pesos(item['platform_fee_cents'] as int)}',
                      ),
                      Text(
                        'Costos de Stripe: ${pesos(item['stripe_fee_cents'] as int)}',
                      ),
                      Text(
                        'Neto asignado: ${pesos(item['assigned_cents'] as int)}',
                      ),
                      Text(
                        'Transferido: ${pesos(item['transferred_cents'] as int)}',
                      ),
                    ],
                    if ((item['refund_cents'] as int? ?? 0) > 0)
                      Text(
                        '${item['status'] == 'refunded' ? 'Devuelto' : 'Por devolver'}: ${pesos(item['refund_cents'] as int)}',
                      ),
                    if ([
                          'refund_reconciling',
                          'refund_review',
                        ].contains(item['status']) &&
                        (item['refunded_cents'] as int? ?? 0) > 0)
                      Text(
                        'Devuelto confirmado: ${pesos(item['refunded_cents'] as int)}',
                      ),
                    if (item['status'] == 'refund_reconciling')
                      const Text(
                        'El pago ya fue devuelto. Seguimos conciliando las transferencias anteriores.',
                      ),
                    if ((item['reversed_cents'] as int? ?? 0) > 0)
                      Text(
                        'Transferencias revertidas: ${pesos(item['reversed_cents'] as int)}',
                      ),
                    if (item['status'] == 'refund_pending' ||
                        item['status'] == 'refunded')
                      const Text(
                        'La devolución corresponde al importe completo del pago. Los costos de procesamiento no reducen lo que se te devuelve.',
                      ),
                    if (item['status'] == 'processing' ||
                        item['status'] == 'review')
                      const Text(
                        'Esperamos confirmación del resultado. No inicies otro pago para este ciclo.',
                      ),
                    if (item['skip_reason'] != null)
                      Text(switch (item['skip_reason']) {
                        'no_capacity' => 'No había capacidad para asignar la aportación completa.',
                        'authentication_required' => 'Se requería autenticación bancaria. Actualizar el medio de pago sólo aplica a próximos ciclos.',
                        'payment_failed' => 'El pago fue rechazado. Puedes actualizar el medio para próximos ciclos.',
                        _ => 'El ciclo se cerró sin cobro.',
                      }),
                    if (item['needs_review'] == true)
                      const Notice(
                        'La entrega o devolución requiere revisión. El importe confirmado se conserva en este historial.',
                      ),
                    if ((item['allocation_count'] as int? ?? 0) > 0)
                      _Allocations(
                        key: ValueKey('$owner:$revision:${item['id']}'),
                        owner: owner,
                        cycle: item['id'] as String,
                      ),
                  ],
                ),
              ),
            ),
          if (error != null) Notice(error!, isError: true),
          if (cursor != null)
            TextButton(
              onPressed: busy ? null : () => load(more: true),
              child: Text(
                error == null
                    ? 'Ver ciclos anteriores'
                    : 'Reintentar ciclos anteriores',
              ),
            ),
        ],
      ],
    );
  }
}

class _Allocations extends ConsumerStatefulWidget {
  const _Allocations({super.key, required this.owner, required this.cycle});
  final String owner, cycle;
  @override
  ConsumerState<_Allocations> createState() => _AllocationsState();
}

class _AllocationsState extends ConsumerState<_Allocations> {
  final items = <Json>[];
  String? cursor, error;
  bool busy = false, loaded = false;
  bool get current =>
      mounted &&
      ref.read(identityControllerProvider).identity?.id == widget.owner;
  Future<void> load() async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await ref
          .read(guardianRepositoryProvider)
          .allocations(widget.cycle, cursor: cursor);
      if (!current) return;
      setState(() {
        final known = items.map((item) => item['id']).toSet();
        items.addAll(
          (page['items'] as List)
              .map((item) => Json.from(item))
              .where((item) => known.add(item['id'])),
        );
        cursor = page['next_cursor'] as String?;
        loaded = true;
      });
    } catch (_) {
      if (current) {
        setState(() => error = 'No pudimos consultar las asignaciones.');
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Ver asignaciones'),
    onExpansionChanged: (open) {
      if (open && !loaded) load();
    },
    children: [
      for (final item in items)
        ListTile(
          title: Text(item['title'] as String),
          subtitle: Text(
            '${pesos(item['amount_cents'] as int)} · ${switch (item['status']) {
              'reversed' => 'Importe original; reversión confirmada',
              'transferred' => 'Transferencia confirmada',
              _ => 'Asignado; transferencia pendiente',
            }}',
          ),
        ),
      if (busy) const LinearProgressIndicator(),
      if (error != null) Notice(error!, isError: true),
      if (error != null || cursor != null)
        TextButton(
          onPressed: busy ? null : load,
          child: Text(
            error != null ? 'Reintentar asignaciones' : 'Ver más asignaciones',
          ),
        ),
      if (loaded && items.isEmpty)
        const Text('No hay asignaciones confirmadas.'),
    ],
  );
}
