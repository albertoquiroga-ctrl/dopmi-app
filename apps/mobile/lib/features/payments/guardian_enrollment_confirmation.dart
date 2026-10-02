import 'package:flutter/material.dart';

import '../../core/ui.dart';

class GuardianEnrollmentConfirmation extends StatelessWidget {
  const GuardianEnrollmentConfirmation({
    super.key,
    required this.firstPaymentDate,
    required this.nextBillingDate,
    required this.consent,
    required this.onConsentChanged,
    this.restored = false,
  });
  final String firstPaymentDate, nextBillingDate;
  final bool consent, restored;
  final ValueChanged<bool?>? onConsentChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Selecciona método de pago',
        style: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe6e2dd)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.credit_card_outlined, size: 20, color: ink),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pago seguro en Stripe',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Elige tu medio de pago en Stripe antes de confirmar el cobro.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Primer intento de cobro: hoy, $firstPaymentDate, al activar. Próxima fecha aproximada: $nextBillingDate. Después, cada aniversario mensual; si el mes no tiene ese día, se usa su último día. Stripe te mostrará el importe antes de confirmar.',
        style: const TextStyle(fontSize: 12, height: 1.5, color: muted),
      ),
      const SizedBox(height: 12),
      const Text(
        'Solo modo de prueba. No uses datos de una tarjeta real.',
        style: TextStyle(fontSize: 12, height: 1.5, color: muted),
      ),
      const SizedBox(height: 12),
      const Text(
        'Solo se cobra si el neto completo puede asignarse a gastos aprobados. Si no hay capacidad, ese mes se omite sin cargo ni deuda. Dopmi descuenta el 2% y los costos de Stripe; el neto se asigna por prioridad. Puedes cancelar los ciclos futuros.',
        style: TextStyle(fontSize: 12, height: 1.5, color: muted),
      ),
      if (!restored) ...[
        const SizedBox(height: 8),
        CheckboxListTile(
          value: consent,
          onChanged: onConsentChanged,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: yellow,
          checkColor: ink,
          title: const Text(
            'Autorizo el primer pago y los cobros mensuales condicionados por el importe elegido, y guardar mi medio de pago en Stripe.',
            style: TextStyle(fontSize: 13, height: 1.5, color: ink),
          ),
        ),
      ],
    ],
  );
}
