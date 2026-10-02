import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import 'contribution_layout.dart';

/// Shown only after the owning account's matching checkout is active.
class GuardianActivationSuccess extends StatelessWidget {
  const GuardianActivationSuccess({
    super.key,
    required this.cents,
    required this.nextBilling,
    required this.onReturn,
  });
  final int cents;
  final String? nextBilling;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final next = DateTime.tryParse(nextBilling ?? '')?.toLocal();
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onReturn();
      },
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: yellow,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/profile/check.svg',
                      width: 36,
                      height: 36,
                      colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '¡Ya eres Guardián!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    letterSpacing: -.48,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gracias por formar parte de Dopmi, la manada ya sabe que estás aquí. Desde hoy, tu aportación mensual nos ayuda a que más mascotas tengan una vida digna.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    letterSpacing: 0,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xfffffdf4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xfff4c917)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Membresía activa',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          letterSpacing: 0,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Guardián',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: contributionMoney(cents)
                                  .replaceFirst(' MXN', ''),
                              style: const TextStyle(
                                fontSize: 26,
                                height: 1.2,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            const TextSpan(
                              text: ' MXN / mes',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w500,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.start,
                      ),
                      if (next != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Próximo cargo: ${next.day} de ${months[next.month - 1]}, ${next.year}',
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            letterSpacing: 0,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onReturn,
                    child: const Text(
                      'Volver a Apoyar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Modo de prueba: no se mueve dinero real.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
