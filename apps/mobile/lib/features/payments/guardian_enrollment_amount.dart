import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../rescue/rescue_repository.dart';
import 'contribution_layout.dart';

class GuardianEnrollmentAmount extends StatefulWidget {
  const GuardianEnrollmentAmount({
    super.key,
    required this.amount,
    this.headingKey,
    required this.locked,
    required this.onChanged,
  });
  final TextEditingController amount;
  final Key? headingKey;
  final bool locked;
  final VoidCallback onChanged;
  @override
  State<GuardianEnrollmentAmount> createState() =>
      _GuardianEnrollmentAmountState();
}

class _GuardianEnrollmentAmountState extends State<GuardianEnrollmentAmount> {
  bool custom = false;
  final amountFocus = FocusNode();
  @override
  void dispose() {
    amountFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GuardianEnrollmentAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locked && !oldWidget.locked) amountFocus.unfocus();
  }

  void openCustom() {
    if (widget.locked) return;
    setState(() => custom = true);
    widget.onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && custom && !widget.locked) amountFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cents = parsePesos(widget.amount.text);
    final showCustom =
        custom || widget.locked || ![5000, 20000, 50000].contains(cents);
    final large = MediaQuery.textScalerOf(context).scale(18) > 27;
    Widget preset(int value) => Semantics(
      button: true,
      selected: !custom && cents == value,
      child: Material(
        color: !custom && cents == value
            ? const Color(0xfffff8d7)
            : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: !custom && cents == value ? yellow : const Color(0xffe6e2dd),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: widget.locked
              ? null
              : () {
                  amountFocus.unfocus();
                  setState(() {
                    custom = false;
                    widget.amount.text = (value / 100).toStringAsFixed(2);
                  });
                  widget.onChanged();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contributionMoney(value).replaceAll(' MXN', ''),
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'MXN / mes',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final amountLabel = cents != null && cents >= 1000 && cents <= 1000000
        ? pesos(cents)
        : 'Importe por confirmar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Elige tu apoyo',
          key: widget.headingKey,
          style: const TextStyle(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Selecciona cuánto quieres aportar cada mes.',
          style: TextStyle(fontSize: 14, height: 1.55, color: muted),
        ),
        const SizedBox(height: 16),
        if (large)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final value in [5000, 20000, 50000]) ...[
                preset(value),
                const SizedBox(height: 10),
              ],
            ],
          )
        else
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: preset([5000, 20000, 50000][i])),
              ],
            ],
          ),
        const SizedBox(height: 8),
        if (showCustom) ...[
          TextField(
            controller: widget.amount,
            focusNode: amountFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => amountFocus.unfocus(),
            enabled: !widget.locked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              setState(() => custom = true);
              widget.onChanged();
            },
            decoration: const InputDecoration(
              labelText: 'Importe mensual en MXN',
              prefixText: '\$ ',
              suffixText: 'MXN',
              helperText: 'De \$10 a \$10,000; hasta dos decimales.',
              helperMaxLines: 3,
            ),
          ),
          TextButton(
            onPressed: widget.locked
                ? null
                : () {
                    amountFocus.unfocus();
                    setState(() {
                      custom = false;
                      widget.amount.text = '50.00';
                    });
                    widget.onChanged();
                  },
            child: const Text('Volver a cantidades sugeridas'),
          ),
        ] else
          TextButton(
            onPressed: widget.locked ? null : openCustom,
            child: const Text(
              'Otra cantidad',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        const SizedBox(height: 10),
        ContributionSummary(
          title: 'Resumen',
          balancedColumns: true,
          emphasizeLast: true,
          rows: [
            ('Apoyo mensual', amountLabel),
            ('Frecuencia', 'Mensual'),
            ('Total al activar', amountLabel),
          ],
        ),
      ],
    );
  }
}
