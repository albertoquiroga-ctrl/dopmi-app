import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adoption/community_repository.dart';

class CaseNeedRow extends StatelessWidget {
  const CaseNeedRow({
    super.key,
    required this.item,
    this.onRemove,
    this.showRemove = false,
    this.showUrgency = false,
  });
  final Json item;
  final VoidCallback? onRemove;
  final bool showRemove, showUrgency;

  @override
  Widget build(BuildContext context) {
    final cents = item['amount_cents'] as int;
    final amount =
        '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
    final detail = item['detail'] as String;
    final remove = TextButton(
      onPressed: onRemove,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xffd52222),
        padding: const EdgeInsets.all(8),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: const Text('Eliminar'),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(12) > 16;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe3e4ed)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: SvgPicture.asset(
                  'assets/profile/need-${item['type']}.svg',
                  width: 24,
                  height: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff151423),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$$amount${detail.isEmpty ? '' : ' • $detail'}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xff616174),
                      ),
                    ),
                    if (showUrgency && item['urgent'] == true) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffd52222),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Urgente',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showRemove && !stacked) ...[
                const SizedBox(width: 12),
                remove,
              ],
            ],
          ),
          if (showRemove && stacked)
            Align(alignment: Alignment.centerRight, child: remove),
        ],
      ),
    );
  }
}
