import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import 'contribution_layout.dart';
import 'payment_repository.dart';
import 'case_allocation_list.dart';
import 'payment_success_details.dart';
import 'payment_environment.dart';

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({
    super.key,
    required this.value,
    required this.refresh,
    required this.back,
    this.retry,
    this.continueAttempt,
    this.checkWhileAuthorizing,
    this.caseId,
    this.caseName,
    this.casePhoto,
    this.busy = false,
    this.error,
    this.paymentEnvironment = const PaymentEnvironment.compiled(),
  });
  final Json value;
  final VoidCallback refresh, back;
  final VoidCallback? retry, continueAttempt, checkWhileAuthorizing;
  final String? caseId, caseName, casePhoto, error;
  final bool busy;
  final PaymentEnvironment paymentEnvironment;

  @override
  Widget build(BuildContext context) {
    final presentation = contributionOutcome(value);
    final confirmed = presentation == ContributionOutcome.confirmed;
    final canceled = presentation == ContributionOutcome.canceled;
    final refunded = presentation == ContributionOutcome.refunded;
    final refundPending = [
      ContributionOutcome.refundPending,
      ContributionOutcome.refundReconciling,
      ContributionOutcome.refundReview,
    ].contains(presentation);
    final gross = value['gross_cents'] as int?;
    final allocated = value['allocated_cents'] as int?;
    final transfer = transferLabels[value['transfer_status']];
    final caseContribution = value['contribution_scope'] == 'case';
    final allocations = (value['case_allocations'] as List? ?? [])
        .map((row) => Json.from(row as Map))
        .toList();
    final heading = confirmed
        ? 'Pago exitoso'
        : switch (presentation) {
            ContributionOutcome.canceled => 'Pago cancelado',
            ContributionOutcome.refunded => 'Pago devuelto',
            ContributionOutcome.refundPending => 'Devolución total en proceso',
            ContributionOutcome.refundReconciling =>
              'Devolución y transferencias en conciliación',
            ContributionOutcome.refundReview => 'Devolución en revisión',
            _ => 'Pago en procesamiento',
          };
    final copy = confirmed
        ? '¡Muchas gracias por apoyar a la manada!'
        : switch (presentation) {
            ContributionOutcome.canceled => 'Stripe no confirmó un cobro para este intento. Puedes elegir una nueva aportación.',
            ContributionOutcome.refunded => 'El servidor confirmó la devolución del pago. Consulta su seguimiento en tu historial.',
            ContributionOutcome.refundPending ||
            ContributionOutcome.refundReconciling ||
            ContributionOutcome.refundReview => 'Este pago no puede contar como apoyo asignado. Conservamos la misma aportación mientras se confirma la devolución total y, cuando corresponde, la reversión de la transferencia. No inicies otro pago.',
            _ => 'Aún esperamos evidencia del procesador. No inicies otra aportación.',
          };
    final rows = <(String, String)>[
      if (caseName != null) ('Caso', caseName!),
      if (gross != null) ('Monto', contributionMoney(gross)),
      (
        'Estado',
        switch (presentation) {
          ContributionOutcome.confirmed => 'Pago confirmado',
          ContributionOutcome.canceled => 'Cancelado sin cobro',
          ContributionOutcome.refunded => 'Devuelto',
          ContributionOutcome.refundPending => 'Devolución total en proceso',
          ContributionOutcome.refundReconciling =>
            'Devolución y transferencias en conciliación',
          ContributionOutcome.refundReview => 'Devolución en revisión',
          _ => 'Pendiente de confirmación',
        },
      ),
      if (confirmed && allocated != null)
        ('Asignado', contributionMoney(allocated)),
      if (confirmed && transfer != null) ('Transferencia', transfer),
      if (caseContribution && value['platform_fee_cents'] is int)
        (
          'Comisión Dopmi',
          contributionMoney(value['platform_fee_cents'] as int),
        ),
      if (caseContribution && value['stripe_fee_cents'] is int)
        (
          'Costo real de Stripe',
          contributionMoney(value['stripe_fee_cents'] as int),
        ),
    ];
    final icon = confirmed
        ? const PaymentSuccessBadge()
        : Container(
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
                ? const EdgeInsets.symmetric(horizontal: 18, vertical: 16)
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
                    style: TextStyle(
                      fontSize: confirmed ? 26 : 24,
                      fontWeight: confirmed ? FontWeight.w800 : FontWeight.w700,
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
                if (confirmed) ...[
                  PaymentSuccessDetails(
                    value: value,
                    caseName: caseName,
                    casePhoto: casePhoto,
                  ),
                  const SizedBox(height: 24),
                ],
                if (!confirmed || caseContribution) ...[
                  ContributionSummary(rows: rows),
                  const SizedBox(height: 18),
                ],
                if (caseContribution &&
                    allocations.isNotEmpty &&
                    (confirmed || refunded)) ...[
                  CaseAllocationList(allocations: allocations),
                  const SizedBox(height: 18),
                ],
                if (error != null) ...[
                  Notice(error!, isError: true),
                  const SizedBox(height: 12),
                ],
                if (checkWhileAuthorizing != null) ...[
                  TextButton(
                    onPressed: checkWhileAuthorizing,
                    child: const Text('Consultar estado del mismo intento'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (confirmed && caseId != null) ...[
                  ContributionButton(
                    'Ver caso actualizado',
                    onPressed: busy
                        ? null
                        : () => context.go('/rescue-cases/$caseId'),
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
                  if (continueAttempt != null && !refundPending) ...[
                    ContributionButton(
                      'Continuar la misma aportación',
                      busy: busy,
                      onPressed: continueAttempt,
                    ),
                    const SizedBox(height: 12),
                  ],
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
                  onPressed: busy ? null : () => context.go('/payments'),
                ),
                if (caseId != null && !confirmed) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy ? null : back,
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
                Text(
                  paymentEnvironment.isProduction
                      ? 'Aportaciones reales mediante Stripe.'
                      : 'Solo pagos de prueba.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: muted),
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
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: ContributionButton(
                'Ir a inicio',
                onPressed: busy ? null : () => context.go('/rescue-cases'),
              ),
            ),
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
