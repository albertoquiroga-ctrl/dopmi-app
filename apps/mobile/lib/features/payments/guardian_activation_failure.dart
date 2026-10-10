import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import 'contribution_layout.dart';

class GuardianActivationFailure extends StatelessWidget {
  const GuardianActivationFailure({
    super.key,
    required this.cents,
    required this.onRetry,
    required this.onReturn,
  });
  final int cents;
  final VoidCallback onRetry, onReturn;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(13) > 20;
    Widget row(String label, Widget value, {bool last = false}) => Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xffe6e2dd))),
      ),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    letterSpacing: 0,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                value,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      letterSpacing: 0,
                      color: muted,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                value,
              ],
            ),
    );
    Widget value(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.2,
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onReturn();
      },
      child: ContributionFrame(
        title: 'Pago no completado',
        back: onReturn,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xfffff2f3),
                    border: Border.all(
                      color: const Color(0xffffd4d8),
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/profile/payment-card-error.svg',
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No pudimos procesar tu pago',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.25,
                  letterSpacing: -.48,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 34.08),
              const Text(
                'Tu suscripción no fue activada. Puedes intentarlo nuevamente o usar otro método de pago.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  letterSpacing: 0,
                  color: muted,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xffe6e2dd)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    const Text(
                      'RESUMEN DE LA SUSCRIPCIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        letterSpacing: .88,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    row('Membresía', value('Guardián')),
                    row('Monto mensual', value(contributionMoney(cents))),
                    row('Método de pago', value('Se elige en Stripe')),
                    row(
                      'Estado',
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffffe2e2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Fallido',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffc10007),
                          ),
                        ),
                      ),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text(
                    'Intentar de nuevo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xffe6e2dd)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text(
                    'Cambiar método de pago',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: onReturn,
                child: const Text(
                  'Volver a Apoyar',
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Modo de prueba: no uses datos de una tarjeta real.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
