import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../../core/design_tokens.dart';
import '../rescue/rescue_repository.dart';
import 'contribution_layout.dart';

class GuardianMembershipCard extends StatelessWidget {
  const GuardianMembershipCard({
    super.key,
    required this.status,
    required this.cents,
    this.nextBilling,
    this.billing = false,
  });
  final String? status;
  final int cents;
  final Object? nextBilling;
  final bool billing;
  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final date = DateTime.tryParse(nextBilling?.toString() ?? '')?.toLocal();
    final label = switch (status) {
      'active' => 'Suscripción activa',
      'cancel_requested' => 'Cancelación solicitada',
      'canceled' => 'Suscripción cancelada',
      _ => 'Estado por confirmar',
    };
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    Widget meta(String title, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xffe6e2dd)),
          const SizedBox(height: 10),
          if (large)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: muted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      color: muted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: DopmiTokens.saffronSoft,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33fab919),
            offset: Offset(0, 12),
            blurRadius: 32,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : const Color(0xffefede8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: active ? ink : muted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: DopmiTokens.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/profile/icon-star.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
          if (!billing) ...[
            const SizedBox(height: 10),
            const Text(
              'Guardián',
              style: TextStyle(
                fontSize: 18,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                pesos(cents).replaceAll(' MXN', ''),
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.55,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Text(
                'MXN / mes',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
          if (active)
            meta(
              'Próximo cobro',
              date == null
                  ? 'Por confirmar'
                  : billing
                  ? '${date.day} ${const ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'][date.month - 1]} ${date.year}'
                  : '${date.day}/${date.month}/${date.year}',
            ),
          if (!billing) meta('Método de pago', 'En Stripe'),
        ],
      ),
    );
  }
}

class GuardianInactiveCard extends StatelessWidget {
  const GuardianInactiveCard({super.key, required this.onSubscribe});
  final VoidCallback? onSubscribe;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe6e2dd)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            const Text(
              'Suscripción mensual',
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xffefede8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Sin suscripción',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ContributionButton('Suscribirme', onPressed: onSubscribe),
      ],
    ),
  );
}
