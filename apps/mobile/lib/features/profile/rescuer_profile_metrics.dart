import 'package:flutter/material.dart';

import '../adoption/community_repository.dart';

class RescuerProfileMetrics extends StatelessWidget {
  const RescuerProfileMetrics({
    super.key,
    required this.data,
    required this.onCases,
    required this.onTransfers,
  });
  final Json data;
  final VoidCallback onCases, onTransfers;
  static const valueStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -.66,
    color: Color(0xff151423),
  );
  @override
  Widget build(BuildContext context) {
    final counts = Json.from(data['case_counts'] as Map? ?? {});
    final financial = Json.from(data['financial'] as Map? ?? {});
    final open = [
      'active',
      'draft',
      'review',
      'corrections',
    ].fold<int>(0, (sum, key) => sum + (counts[key] as int? ?? 0));
    final cents = financial['transferred_cents'] as int?;
    final completeCounts = [
      'active',
      'draft',
      'review',
      'corrections',
    ].every((key) => counts[key] is int);
    final values = [
      completeCounts ? '$open' : '—',
      counts['active'] is int ? '${counts['active']}' : '—',
      cents == null
          ? '—'
          : '\$${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}',
    ];
    const labels = ['Casos', 'Activos', 'Transferido'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = (constraints.maxWidth - 20) / 3 - 24;
        var column = MediaQuery.textScalerOf(context).scale(22) > 30;
        for (final value in values) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: valueStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          column = column || painter.width > available;
          painter.dispose();
        }
        final cards = [
          for (var n = 0; n < 3; n++)
            RescuerProfileMetric(
              value: values[n],
              label: labels[n],
              onPressed: n == 2 ? onTransfers : onCases,
            ),
        ];
        if (column) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var n = 0; n < cards.length; n++) ...[
                if (n > 0) const SizedBox(height: 10),
                cards[n],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var n = 0; n < cards.length; n++) ...[
              if (n > 0) const SizedBox(width: 10),
              Expanded(child: cards[n]),
            ],
          ],
        );
      },
    );
  }
}

class RescuerProfileMetric extends StatefulWidget {
  const RescuerProfileMetric({
    super.key,
    required this.value,
    required this.label,
    required this.onPressed,
  });
  final String value, label;
  final VoidCallback onPressed;
  @override
  State<RescuerProfileMetric> createState() => _RescuerProfileMetricState();
}

class _RescuerProfileMetricState extends State<RescuerProfileMetric> {
  bool pressed = false, hovered = false;
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);
    return AnimatedScale(
      scale: pressed ? .98 : 1,
      duration: duration,
      curve: Curves.ease,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.ease,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: hovered
                  ? const Color(0x1a15110d)
                  : const Color(0x0f15110d),
              offset: Offset(0, hovered ? 10 : 8),
              blurRadius: hovered ? 28 : 24,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => pressed = value),
            onHover: (value) => setState(() => hovered = value),
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.value,
                    textAlign: TextAlign.center,
                    style: RescuerProfileMetrics.valueStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: 0,
                      color: Color(0xff4f4e5c),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
