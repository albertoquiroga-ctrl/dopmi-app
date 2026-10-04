import 'package:flutter/material.dart';

import '../../core/ui.dart';
import 'guardian_payment_card.dart';

Future<bool> confirmSavedCard(BuildContext context) => _confirm(context);

Future<bool> confirmIndependentCardMethod(
  BuildContext context,
  GuardianPaymentCard card, {
  required bool remove,
}) => _confirm(context, card: card, remove: remove);

Future<bool> _confirm(
  BuildContext context, {
  GuardianPaymentCard? card,
  bool remove = false,
}) async {
  var resolved = false;
  void finish(BuildContext context, bool agreed) {
    if (resolved) return;
    resolved = true;
    Navigator.pop(context, agreed);
  }

  return await showDialog<bool>(
        context: context,
        barrierColor: ink.withValues(alpha: .48),
        animationStyle: AnimationStyle.noAnimation,
        builder: (context) => AlertDialog(
          scrollable: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: MediaQuery.textScalerOf(context).scale(22) > 33 ? 18 : 22,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.55,
            color: muted,
          ),
          title: Text(
            card == null
                ? 'Agregar tarjeta'
                : remove
                ? '¿Eliminar esta tarjeta?'
                : '¿Usar esta tarjeta por defecto?',
          ),
          content: Text(
            card != null
                ? remove
                      ? 'Eliminarás ${card.brandLabel} •••• ${card.last4} de tus tarjetas guardadas. Tu tarjeta predeterminada no cambiará. Para volver a usarla tendrás que agregarla de nuevo.'
                      : 'Autorizo usar ${card.brandLabel} •••• ${card.last4} como mi tarjeta predeterminada para futuros apoyos que yo autorice. Este cambio no genera un cobro ni activa Guardián.'
                : 'Autorizo guardar mi tarjeta en Stripe para usarla en futuros apoyos que yo autorice. Esta acción no realiza un cobro, no activa Guardián y no cambia mi tarjeta predeterminada. Stripe puede solicitar autenticación bancaria.',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: ink,
                minimumSize: const Size(44, 44),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => finish(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: remove ? const Color(0xffe52b21) : ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => finish(context, true),
              child: Text(
                card == null
                    ? 'Guardar y continuar'
                    : remove
                    ? 'Eliminar tarjeta'
                    : 'Autorizar y continuar',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ) ??
      false;
}
