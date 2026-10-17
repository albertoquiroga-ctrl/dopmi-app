import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../rescue/rescue_public_photo.dart';
import 'contribution_layout.dart';

class PaymentSuccessBadge extends StatelessWidget {
  const PaymentSuccessBadge({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 112,
      height: 88,
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: yellow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x73f4c917),
                    offset: Offset(0, 12),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, size: 34, color: ink),
            ),
          ),
          for (final dot in const [
            (8.0, 18.0, 8.0, yellow),
            (100.0, 8.0, 6.0, Color(0xffc9c4bd)),
            (0.0, 73.0, 5.0, yellow),
            (90.0, 72.0, 10.0, Color(0xffe6e2dd)),
          ])
            Positioned(
              left: dot.$1,
              top: dot.$2,
              width: dot.$3,
              height: dot.$3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dot.$4,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class PaymentSuccessDetails extends StatelessWidget {
  const PaymentSuccessDetails({
    super.key,
    required this.value,
    this.caseName,
    this.casePhoto,
  });
  final Json value;
  final String? caseName, casePhoto;
  @override
  Widget build(BuildContext context) {
    final confirmedAt = DateTime.tryParse(
      value['processed_at']?.toString() ?? '',
    );
    final createdAt = DateTime.tryParse(value['created_at']?.toString() ?? '');
    final date = (confirmedAt ?? createdAt)?.toLocal();
    final dateLabel = confirmedAt != null
        ? 'Fecha de confirmación'
        : createdAt != null
        ? 'Fecha de creación'
        : 'Fecha';
    final dateValue = date == null
        ? 'Fecha no disponible'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final photo = casePhoto;
    final destination = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Se destinó a',
          style: TextStyle(fontSize: 13, height: 1.3, color: muted),
        ),
        const SizedBox(height: 4),
        Text(
          caseName ?? 'Caso apoyado',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: ink,
          ),
        ),
        if (photo == null || photo.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Foto pública no disponible.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ],
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xfffff8d7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final polaroid = photo == null || photo.isEmpty
                      ? null
                      : Transform.rotate(
                          angle: -4 * math.pi / 180,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(7, 7, 7, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x2415110d),
                                  offset: Offset(0, 8),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 76,
                              child: RescuePublicPhoto(
                                photo,
                                height: 88,
                                radius: 2,
                                compact: true,
                              ),
                            ),
                          ),
                        );
                  if (polaroid == null) return destination;
                  if (MediaQuery.textScalerOf(context).scale(14) > 22 ||
                      box.maxWidth < 230) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        polaroid,
                        const SizedBox(height: 16),
                        destination,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      polaroid,
                      const SizedBox(width: 16),
                      Expanded(child: destination),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _SuccessMeta(
              label: 'Monto',
              value: value['gross_cents'] is int
                  ? contributionMoney(value['gross_cents'] as int)
                  : 'Monto no disponible',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 10),
            _SuccessMeta(
              label: dateLabel,
              value: dateValue,
              icon: Icons.description_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessMeta extends StatelessWidget {
  const _SuccessMeta({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xfff3f1ee),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, height: 1.3, color: muted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
