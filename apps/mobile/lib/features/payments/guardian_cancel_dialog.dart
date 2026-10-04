import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../core/dialog_close.dart';
import 'contribution_layout.dart';

Future<bool?> confirmGuardianCancellation(BuildContext context) =>
    showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar confirmación de cancelación',
      barrierColor: ink.withValues(alpha: .48),
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          const GuardianCancelDialog(),
    );

class GuardianCancelDialog extends StatelessWidget {
  const GuardianCancelDialog({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (MediaQuery.textScalerOf(context).scale(22) > 33)
                          const SizedBox(height: 24),
                        Text(
                          '¿Cancelar suscripción?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                MediaQuery.textScalerOf(context).scale(22) > 33
                                ? 18
                                : 22,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Detendremos los ciclos futuros. Un pago ya iniciado puede terminar de procesarse. Los pagos anteriores conservan su historial y no se devuelven automáticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            splashFactory: NoSplash.splashFactory,
                            overlayColor: Colors.transparent,
                            animationDuration: Duration.zero,
                            backgroundColor: const Color(0xffd52f26),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text(
                            'Cancelar suscripción',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ContributionButton(
                          'Mantener suscripción',
                          secondary: true,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                  ),
                  DopmiDialogClose(
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
