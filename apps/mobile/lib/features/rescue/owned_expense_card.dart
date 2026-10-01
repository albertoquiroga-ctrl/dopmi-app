import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../payments/payment_repository.dart';
import 'rescue_repository.dart';

/// Own expenses retain their private record route. Funding is read from the
/// server projection, never inferred from reservation or evidence status.
class OwnedExpenseCard extends ConsumerWidget {
  const OwnedExpenseCard(this.record, {super.key, required this.refresh});
  final RescueRecord record;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget contents(Json? funding) => OwnedExpenseSummary(
      record,
      funding: funding,
      onOpen: () async {
        await context.push('/rescue/${record.id}');
        refresh();
      },
    );
    if (!['approved', 'closed'].contains(record.status)) {
      return contents(null);
    }
    return LiveSection<Json>(
      key: ValueKey('owned-expense-funding:${record.id}'),
      tables: const ['dopmi_donations', 'dopmi_rescue_records'],
      load: () => ref.read(paymentRepositoryProvider).funding(record.id),
      errorMessage: paymentError,
      builder: (funding, _) => contents(funding),
    );
  }
}

class OwnedExpenseSummary extends StatelessWidget {
  const OwnedExpenseSummary(
    this.record, {
    super.key,
    required this.funding,
    required this.onOpen,
  });
  final RescueRecord record;
  final Json? funding;
  final VoidCallback onOpen;
  static const ink = Color(0xff15110d);
  static const muted = Color(0xff554e48);

  @override
  Widget build(BuildContext context) {
    final category = record.publicData['category'];
    final (symbol, label) = switch (category) {
      'veterinary' => (Icons.medical_services_outlined, 'Atención veterinaria'),
      'medicine' => (Icons.medication_outlined, 'Medicamentos'),
      'food' => (Icons.restaurant_outlined, 'Comida'),
      _ => (Icons.auto_awesome_outlined, 'Otro gasto'),
    };
    final target = funding?['reimbursable_cents'] as int? ?? 0;
    final funded = funding?['funded_cents'] as int? ?? 0;
    final transferred = funding?['transferred_cents'] as int? ?? 0;
    final remaining = (target - funded).clamp(0, target);
    final ratio = target > 0 ? (funded / target).clamp(0.0, 1.0) : 0.0;
    final action = switch (record.status) {
      'draft' => 'Continuar gasto',
      'changes_requested' || 'rejected' => 'Corregir gasto',
      'submitted' => 'Ver envío',
      _ => 'Consultar gasto y comprobantes',
    };
    final large = MediaQuery.textScalerOf(context).scale(16) > 20;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record.title,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            height: 1.4,
            letterSpacing: .72,
            color: muted,
          ),
        ),
        if (record.data['urgent'] == true)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xffe7000b),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Urgente',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
    final amount = Text(
      pesos(target),
      style: const TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffe6e2dd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xfff0eff8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(symbol, size: 22, color: purple),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: heading),
              if (funding != null && !large) ...[
                const SizedBox(width: 10),
                amount,
              ],
            ],
          ),
          if (funding != null && large) ...[const SizedBox(height: 10), amount],
          const SizedBox(height: 10),
          Text(
            rescueStatuses[record.status] ?? record.status,
            style: const TextStyle(fontSize: 12, height: 1.4, color: muted),
          ),
          if (funding != null) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  '${pesos(target)} reembolsables',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: muted,
                  ),
                ),
                Text(
                  '${pesos(remaining)} restantes',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
              color: purple,
              backgroundColor: const Color(0x2e7c3aed),
              semanticsLabel: 'Asignación al gasto aprobado',
              semanticsValue: '${(ratio * 100).round()}%',
            ),
            const SizedBox(height: 10),
            Text(
              'Neto asignado: ${pesos(funded)} · Transferido a Stripe: ${pesos(transferred)}',
              style: const TextStyle(fontSize: 12, height: 1.4, color: muted),
            ),
          ],
          if ((record.data['feedback'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              record.data['feedback'] as String,
              style: const TextStyle(fontSize: 13, height: 1.4, color: muted),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffeee7fc),
              foregroundColor: purple,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text(action, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
