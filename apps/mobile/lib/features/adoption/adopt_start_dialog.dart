import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../core/dialog_close.dart';

Future<bool?> confirmAdoptionContact(
  BuildContext context, {
  String? petName,
  String? rescuerName,
}) => showDialog<bool>(
  context: context,
  barrierColor: ink.withValues(alpha: .48),
  animationStyle: AnimationStyle.noAnimation,
  builder: (_) => AdoptStartDialog(petName: petName, rescuerName: rescuerName),
);

class AdoptStartDialog extends StatelessWidget {
  const AdoptStartDialog({super.key, this.petName, this.rescuerName});
  final String? petName, rescuerName;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 361,
        maxHeight: math.min(MediaQuery.sizeOf(context).height * .88, 720),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.textScalerOf(context).scale(22) > 30
                        ? 0
                        : 20,
                  ),
                  child: Text(
                    petName == null || petName!.trim().isEmpty
                        ? 'Conectar con la mascota'
                        : 'Conectar con ${petName!.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Iniciaremos un chat con la persona rescatista para que pueda resolver tus dudas y ayudarte a conocer a tu nuevo mejor amigo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      letterSpacing: 0,
                      color: muted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Al confirmar se enviará un saludo inicial en una conversación nueva.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.45,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 22),
                OutlinedButton(
                  style: _buttonStyle(false),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Todavía no', textAlign: TextAlign.center),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  style: _buttonStyle(true),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Sí, contactar rescatista',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          DopmiDialogClose(onPressed: () => Navigator.pop(context, false)),
        ],
      ),
    ),
  );

  ButtonStyle _buttonStyle(bool primary) => TextButton.styleFrom(
    splashFactory: NoSplash.splashFactory,
    overlayColor: Colors.transparent,
    animationDuration: Duration.zero,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    visualDensity: VisualDensity.standard,
    foregroundColor: ink,
    backgroundColor: primary ? yellow : Colors.white,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: primary ? null : const BorderSide(color: Color(0xffe6e2dd)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );
}
