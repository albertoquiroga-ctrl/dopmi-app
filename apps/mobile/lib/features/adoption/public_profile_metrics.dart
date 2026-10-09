import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import 'community_repository.dart';

/// These four public counts come from the server's approved projections.
class PublicProfileMetrics extends StatelessWidget {
  const PublicProfileMetrics({
    super.key,
    required this.name,
    required this.metrics,
  });
  final String name;
  final Json metrics;
  String count(String key) => metrics[key] is int && (metrics[key] as int) >= 0
      ? '${metrics[key]}'
      : '—';
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final single =
          MediaQuery.textScalerOf(context).scale(14) > 20 ||
          constraints.maxWidth < 280;
      final cards = [
        (
          'active_adoptions',
          'Mascotas están buscando un hogar.',
          'rtab-home',
          const Color(0xfff5f0ff),
          const Color(0xff6d28d9),
        ),
        (
          'adopted_count',
          'Mascotas encontraron un hogar.',
          'check-circle',
          const Color(0xfffff4eb),
          const Color(0xffea580c),
        ),
        (
          'active_donation_cases',
          'Mascotas están recibiendo apoyo.',
          'tab-donate',
          const Color(0xffeef5ff),
          const Color(0xff2563eb),
        ),
        (
          'received_support_pets',
          'Mascotas recibieron apoyo.',
          'icon-heart',
          const Color(0xffecfdf3),
          const Color(0xff16a34a),
        ),
      ];
      Widget card(int index) {
        final item = cards[index];
        return Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: item.$4,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      count(item.$1),
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x8cffffff),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/profile/${item.$3}.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(item.$5, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.$2,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff5c5650),
                ),
              ),
            ],
          ),
        );
      }

      final memberSince = DateTime.tryParse(
        metrics['member_since'] as String? ?? '',
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Gracias a $name:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 4; i += single ? 1 : 2) ...[
            if (i > 0) const SizedBox(height: 10),
            if (single)
              card(i)
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: card(i)),
                    const SizedBox(width: 10),
                    Expanded(child: card(i + 1)),
                  ],
                ),
              ),
          ],
          if (memberSince != null) ...[
            const SizedBox(height: 18),
            Text(
              '$name forma parte de Dopmi desde ${memberSince.month.toString().padLeft(2, '0')}/${memberSince.year}.\n¡Gracias por ser parte de la manada!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.5, color: muted),
            ),
          ],
        ],
      );
    },
  );
}
