import 'package:flutter/material.dart';

import '../../core/ui.dart';
import 'contribution_layout.dart';

class PaymentHistoryRow extends StatefulWidget {
  const PaymentHistoryRow({
    super.key,
    required this.payment,
    required this.details,
    this.statusLabel,
    this.methodLabel,
    this.amountLabel,
    this.onOpenCase,
    this.caseName,
    this.titleWeight = FontWeight.w700,
  });
  final Map<String, dynamic> payment;
  final Widget details;
  final VoidCallback? onOpenCase;
  final String? caseName;
  final FontWeight titleWeight;
  final String? statusLabel, methodLabel, amountLabel;
  @override
  State<PaymentHistoryRow> createState() => _PaymentHistoryRowState();
}

class _PaymentHistoryRowState extends State<PaymentHistoryRow> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.payment;
    final date = DateTime.tryParse(d['created_at']?.toString() ?? '')
        ?.toLocal();
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final label =
        widget.statusLabel ??
        switch (d['payment_status']) {
          'confirmed' => 'Pagado',
          'pending' => 'En proceso',
          'canceled' => 'Cancelado',
          'refunded' => 'Devuelto',
          _ => 'En revisión',
        };
    final background = switch (d['payment_status']) {
      'confirmed' => const Color(0xff2dc08e),
      'pending' => const Color(0xfff7cb2d),
      _ => const Color(0xffe8e4de),
    };
    final foreground = switch (d['payment_status']) {
      'confirmed' => const Color(0xff071a13),
      'pending' => const Color(0xff0d0d0d),
      'canceled' => const Color(0xff5c5650),
      _ => ink,
    };
    final dateView = Text(
      date == null ? '—' : '${date.day} ${months[date.month - 1]}',
      style: const TextStyle(
        fontSize: 12,
        height: 15 / 12,
        fontWeight: FontWeight.w600,
        color: muted,
      ),
    );
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (widget.caseName != null) ...[
                TextSpan(
                  text: widget.caseName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: " - ${d['expense_title'] ?? 'Aportación'}",
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ] else
                TextSpan(text: d['expense_title']?.toString() ?? 'Aportación'),
            ],
          ),
          maxLines: large ? null : 1,
          overflow: large ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 17 / 14,
            fontWeight: widget.titleWeight,
            color: ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.methodLabel ??
              (d['processor'] == 'stripe' ? 'Stripe' : 'Método no disponible'),
          style: const TextStyle(fontSize: 12, height: 15 / 12, color: muted),
        ),
      ],
    );
    final amountContent = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          widget.amountLabel ??
              (d['gross_cents'] is int
                  ? contributionMoney(d['gross_cents'] as int)
                        .replaceAll(' MXN', '')
                  : 'Importe no disponible'),
          style: const TextStyle(
            fontSize: 13,
            height: 16 / 13,
            fontWeight: FontWeight.w700,
            color: Color(0xff6b5000),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
        ),
      ],
    );
    final amount = widget.onOpenCase == null
        ? amountContent
        : Semantics(
            button: true,
            label: 'Ver detalle del pago',
            expanded: expanded,
            child: InkWell(
              onTap: () => setState(() => expanded = !expanded),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              child: amountContent,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: widget.onOpenCase == null ? expanded : null,
          child: InkWell(
            onTap:
                widget.onOpenCase ?? () => setState(() => expanded = !expanded),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: large
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          dateView,
                          const SizedBox(height: 10),
                          body,
                          const SizedBox(height: 10),
                          amount,
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(width: 52, child: dateView),
                          const SizedBox(width: 10),
                          Expanded(child: body),
                          const SizedBox(width: 10),
                          amount,
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: widget.details,
          ),
      ],
    );
  }
}
