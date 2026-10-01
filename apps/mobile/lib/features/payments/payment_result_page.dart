import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import 'contribution_layout.dart';
import 'payment_repository.dart';

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({
    super.key,
    required this.value,
    required this.refresh,
    required this.back,
    this.retry,
    this.caseId,
    this.caseName,
    this.busy = false,
    this.error,
  });
  final Json value;
  final VoidCallback refresh, back;
  final VoidCallback? retry;
  final String? caseId, caseName, error;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final status = value['payment_status'] as String?;
    final confirmed = status == 'confirmed';
    final canceled = status == 'canceled';
    final refunded = status == 'refunded';
    final gross = value['gross_cents'] as int?;
    final allocated = value['allocated_cents'] as int?;
    final transfer = transferLabels[value['transfer_status']];
    final heading = confirmed
        ? '¡Eres mi héroe, choca esas huellitas!'
        : switch (status) {
            'canceled' => 'Pago cancelado',
            'refunded' => 'Pago devuelto',
            _ => 'Pago en procesamiento',
          };
    final copy = confirmed
        ? 'Gracias por apoyar. ${gross == null ? 'Stripe confirmó tu donación.' : 'Tu donación de ${contributionMoney(gross)} fue confirmada por Stripe.'}'
        : switch (status) {
            'canceled' => 'Stripe no confirmó un cobro para este intento. Puedes elegir una nueva aportación.',
            'refunded' => 'El servidor confirmó la devolución del pago. Consulta su seguimiento en tu historial.',
            _ => 'Aún esperamos evidencia del procesador. No inicies otra aportación.',
          };
    final rows = <(String, String)>[
      if (caseName != null) ('Caso', caseName!),
      if (gross != null) ('Monto', contributionMoney(gross)),
      (
        'Estado',
        switch (status) {
          'confirmed' => 'Pago confirmado',
          'canceled' => 'Cancelado sin cobro',
          'refunded' => 'Devuelto',
          _ => 'Pendiente de confirmación',
        },
      ),
      if (confirmed && allocated != null)
        ('Asignado', contributionMoney(allocated)),
      if (confirmed && transfer != null) ('Transferencia', transfer),
    ];
    final icon = Container(
      width: canceled ? 96 : 64,
      height: canceled ? 96 : 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: confirmed
            ? const Color(0xff2ac39b)
            : canceled
            ? const Color(0xfffff2f3)
            : refunded
            ? const Color(0xffeee8ff)
            : const Color(0xfffff8d6),
        border: canceled
            ? Border.all(color: const Color(0xffffd4d8), width: 3)
            : null,
      ),
      child: Center(
        child: confirmed
            ? SvgPicture.asset(
                'assets/profile/check.svg',
                width: 32,
                height: 32,
              )
            : canceled
            ? SvgPicture.asset(
                'assets/profile/payment-card-error.svg',
                width: 48,
                height: 48,
              )
            : Icon(
                refunded ? Icons.undo : Icons.hourglass_top,
                size: 32,
                color: ink,
              ),
      ),
    );
    final content = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: confirmed ? constraints.maxHeight : 0,
          ),
          child: Padding(
            padding: confirmed
                ? const EdgeInsets.all(28)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              mainAxisAlignment: confirmed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(child: icon),
                SizedBox(height: confirmed ? 26 : 18),
                Semantics(
                  header: true,
                  child: Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: -.48,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  copy,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 26),
                if (!confirmed) ...[
                  ContributionSummary(rows: rows),
                  const SizedBox(height: 18),
                ],
                if (error != null) ...[
                  Notice(error!, isError: true),
                  const SizedBox(height: 12),
                ],
                if (confirmed && caseId != null) ...[
                  ContributionButton(
                    'Ver caso actualizado',
                    onPressed: () => context.go('/rescue-cases/$caseId'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canceled && retry != null) ...[
                  ContributionButton(
                    'Intentar de nuevo',
                    busy: busy,
                    onPressed: retry,
                  ),
                  const SizedBox(height: 18),
                ],
                if (!confirmed && !canceled && !refunded) ...[
                  ContributionButton(
                    'Consultar resultado',
                    busy: busy,
                    onPressed: refresh,
                  ),
                  const SizedBox(height: 18),
                ],
                ContributionButton(
                  'Ir al historial',
                  secondary: !refunded,
                  onPressed: () => context.go('/payments'),
                ),
                if (caseId != null && !confirmed) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: back,
                    child: const Text('Volver al caso'),
                  ),
                ],
                if (confirmed) ...[
                  const SizedBox(height: 18),
                  if (allocated != null)
                    Text(
                      'Asignado: ${contributionMoney(allocated)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: muted,
                      ),
                    ),
                  if (transfer != null)
                    Text(
                      transfer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: muted,
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Solo pagos de prueba.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return confirmed
        ? Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(child: content),
          )
        : ContributionFrame(
            title: canceled
                ? 'Pago no completado'
                : refunded
                ? 'Pago devuelto'
                : 'Tu aportación',
            back: busy ? null : back,
            child: content,
          );
  }
}
