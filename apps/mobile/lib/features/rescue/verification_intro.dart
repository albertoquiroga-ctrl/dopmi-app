import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerificationIntroScreen extends StatelessWidget {
  const VerificationIntroScreen({
    super.key,
    required this.onContinue,
    required this.onLater,
  });
  final VoidCallback onContinue, onLater;
  static const purple = Color(0xff7841f2);
  static const ink = Color(0xff15110d);
  static const muted = Color(0xff554e48);
  Widget icon(String name, double size) => SvgPicture.asset(
    'assets/profile/$name',
    width: size,
    height: size,
    colorFilter: const ColorFilter.mode(purple, BlendMode.srcIn),
  );

  Widget card(String title, String copy, {bool notice = false}) => DecoratedBox(
    decoration: BoxDecoration(
      color: notice ? const Color(0x0f7c3aed) : Colors.white,
      border: Border.all(
        color: notice ? const Color(0x407c3aed) : const Color(0xffe6e2dd),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon(notice ? 'icon-doc.svg' : 'icon-shield.svg', 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: notice ? purple : ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget requirement(String title, String copy) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 3),
        child: Icon(Icons.check_circle_outline, size: 16, color: purple),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              copy,
              style: const TextStyle(fontSize: 13, height: 1.55, color: muted),
            ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff8f8d8b),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 430,
              maxHeight: MediaQuery.sizeOf(context).height * .86,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ColoredBox(
                color: Colors.white,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0x337c3aed),
                                ),
                                child: Center(
                                  child: icon('icon-shield.svg', 28),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              header: true,
                              child: const Text(
                                'Verifícate para recibir donaciones',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 22,
                                  height: 1.55,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            card(
                              'Protege a donadores y mascotas',
                              'La verificación ayuda a Dopmi a garantizar que las donaciones lleguen a rescatistas reales.',
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Cómo funciona el reembolso',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Para recibir el dinero donado, deberás comprobar los gastos con evidencia:',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.55,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            requirement(
                              'Para comida:',
                              'Comprobante de compra y fotografías de la mascota con la comida.',
                            ),
                            const SizedBox(height: 12),
                            requirement(
                              'Para medicina o veterinario:',
                              'Comprobante, descripción del gasto y evidencia fotográfica cuando aplique.',
                            ),
                            const SizedBox(height: 16),
                            card(
                              'Revisión manual',
                              'El equipo Dopmi revisa manualmente cada evidencia. La aprobación puede tardar. Los fondos se liberan solo después de la revisión.',
                              notice: true,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: onContinue,
                              style: FilledButton.styleFrom(
                                backgroundColor: purple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text(
                                'Continuar a verificación',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: onLater,
                              style: TextButton.styleFrom(
                                foregroundColor: muted,
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                ),
                              ),
                              child: const Text('Después'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: onLater,
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close, size: 22, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
