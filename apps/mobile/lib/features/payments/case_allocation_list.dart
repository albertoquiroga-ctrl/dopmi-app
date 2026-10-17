import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import 'contribution_layout.dart';

class CaseAllocationList extends StatelessWidget {
  const CaseAllocationList({super.key, required this.allocations});
  final List<Json> allocations;
  @override
  Widget build(BuildContext context) {
    final confirmed = allocations
        .where((row) => (row['allocated_cents'] as num? ?? 0) > 0)
        .toList();
    if (confirmed.isEmpty) {
      return const Text('Este pago aún no tiene asignaciones confirmadas.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Distribución confirmada en el caso',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final row in confirmed) ...[
          Text(
            row['title'] as String? ?? 'Gasto aprobado',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Asignado: ${contributionMoney((row['allocated_cents'] as num? ?? 0).toInt())}',
            style: const TextStyle(color: muted),
          ),
          if ((row['reversed_cents'] as num? ?? 0) > 0)
            Text(
              'Revertido: ${contributionMoney((row['reversed_cents'] as num).toInt())}',
              style: const TextStyle(color: muted),
            ),
          if (row['remaining_cents'] is num)
            Text(
              'Neto vigente: ${contributionMoney((row['remaining_cents'] as num).toInt())}',
              style: const TextStyle(color: muted),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
