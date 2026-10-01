import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ExpenseFrame extends StatelessWidget {
  const ExpenseFrame({
    super.key,
    required this.children,
    required this.step,
    required this.onBack,
    required this.onClose,
  });
  final List<Widget> children;
  final int step;
  final VoidCallback? onBack, onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff8f8d8b),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 384,
                    maxHeight: constraints.maxHeight * .88,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xffe3e4ed)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          offset: Offset(0, 10),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: ListView(
                        key: const ValueKey('expense-form-body'),
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: onBack,
                                tooltip: step > 0 ? 'Paso anterior' : 'Cerrar',
                                icon: SvgPicture.asset(
                                  'assets/profile/back.svg',
                                  width: 20,
                                  height: 20,
                                ),
                              ),
                              IconButton(
                                onPressed: onClose,
                                tooltip: 'Cerrar formulario',
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xff554e48),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Sube tu evidencia',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.36,
                              color: Color(0xff15110d),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Paso ${step + 1} de 3',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xff554e48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Comparte los comprobantes de la necesidad cubierta. El equipo de Dopmi revisará el gasto antes de publicarlo y recibir aportaciones.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              height: 20 / 14,
                              color: Color(0xff554e48),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ExpenseActions extends StatelessWidget {
  const ExpenseActions({
    super.key,
    required this.primaryLabel,
    this.onSave,
    this.onNext,
  });
  final String primaryLabel;
  final VoidCallback? onSave, onNext;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    final save = OutlinedButton(
      onPressed: onSave,
      style: style,
      child: const Text('Guardar progreso'),
    );
    final next = FilledButton(
      onPressed: onNext,
      style: style.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? const Color(0xffbba0f8)
              : const Color(0xff7841f2),
        ),
      ),
      child: Text(primaryLabel),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: MediaQuery.textScalerOf(context).scale(14) > 21
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [save, const SizedBox(height: 8), next],
            )
          : Row(
              children: [
                Expanded(child: save),
                const SizedBox(width: 8),
                Expanded(child: next),
              ],
            ),
    );
  }
}
