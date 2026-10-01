import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../rescue/rescue_repository.dart';

class GuardianMembershipCard extends StatelessWidget {
  const GuardianMembershipCard({
    super.key,
    required this.status,
    required this.cents,
    this.nextBilling,
  });
  final String? status;
  final int cents;
  final Object? nextBilling;
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e2dd)),
        borderRadius: BorderRadius.circular(20),
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
                      color: active
                          ? const Color(0xffe5f7ec)
                          : const Color(0xffefede8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: active ? const Color(0xff157347) : muted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xfffff2b8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/profile/icon-star.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Color(0xff6b5000),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
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
                  : '${date.day}/${date.month}/${date.year}',
            ),
          meta('Método de pago', 'En Stripe'),
        ],
      ),
    );
  }
}
