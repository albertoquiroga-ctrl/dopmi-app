import 'package:flutter/material.dart';

import '../../core/ui.dart';

/// Decorative teaching examples from the mockup; never a live catalog.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.intent, required this.step});
  final String intent;
  final int step;
  Widget photo(
    String name,
    double width,
    double height, {
    double radius = 16,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.asset(
      'assets/onboarding/$name.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
    ),
  );
  Widget tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xfffff9df),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: yellow.withValues(alpha: .4)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
  );
  Widget panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffe6e2dd)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  Widget identity({bool detail = false}) => Row(
    children: [
      photo(
        detail ? 'luna-detail' : 'luna-card',
        detail ? 56 : 64,
        detail ? 56 : 64,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Luna',
              style: TextStyle(
                fontFamily: detail ? 'Fraunces' : 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const Text(
              'Refugio Patitas',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const Text(
              '✓ Verificada',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final art = intent == 'adopt'
        ? (step == 0 ? adoptionStack() : adoptionDetail())
        : intent == 'donate'
        ? donation()
        : rescue();
    return Semantics(
      label: 'Ilustración de ejemplo',
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1,
          maxScaleFactor: 1,
          child: art,
        ),
      ),
    );
  }

  Widget adoptionStack() => LayoutBuilder(
    builder: (_, box) => SizedBox(
      height: 230,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 28,
            child: Transform.rotate(
              angle: .07,
              child: SizedBox(
                width: box.maxWidth * .42,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    photo('nina-card', box.maxWidth * .42, 150, radius: 22),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Michi también busca hogar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 8,
            child: SizedBox(
              width: box.maxWidth * .78,
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    photo('luna-card', box.maxWidth * .78, 200, radius: 22),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x66000000)],
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Luna',
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Refugio Patitas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.favorite_border,
                          color: purple,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget adoptionDetail() => panel([
    identity(detail: true),
    const SizedBox(height: 12),
    const Text(
      'SALUD',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted),
    ),
    const SizedBox(height: 6),
    Wrap(spacing: 6, children: [tag('Vacunada'), tag('Esterilizada')]),
    const SizedBox(height: 12),
    const Text(
      'CONVIVE CON',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted),
    ),
    const SizedBox(height: 6),
    Wrap(spacing: 6, children: [tag('Perros'), tag('Gatos'), tag('Niños')]),
    const SizedBox(height: 12),
    const Text(
      'Cada publicación pasa por revisión de DopMi.',
      style: TextStyle(fontSize: 12, color: muted),
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff7f4ef),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              '¡Hola! Me interesa Luna',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Icon(Icons.send_outlined, size: 18),
        ],
      ),
    ),
  ]);

  Widget donation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (step == 0)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            tag('Quién publica'),
            tag('Cuánto falta'),
            tag('Evidencia'),
          ],
        )
      else
        tag('✓ Evidencia revisada en el caso de Luna'),
      const SizedBox(height: 12),
      panel([
        identity(),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Medicina',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (step == 0)
              const Text('70 %', style: TextStyle(fontSize: 12, color: muted))
            else
              tag('✓ Completada'),
          ],
        ),
        if (step == 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: .7,
            color: yellow,
            backgroundColor: const Color(0xfff3f0e9),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
        if (step == 1) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfffff9df),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.description_outlined, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ticket de consulta',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Subido por Refugio Patitas',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    ],
  );

  Widget rescue() => Column(
    children: [
      if (step == 0)
        const Text(
          'Tu próxima publicación',
          style: TextStyle(fontSize: 12, color: muted),
        )
      else
        tag('Ejemplo de un caso con apoyo'),
      const SizedBox(height: 12),
      panel([
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 27,
              backgroundColor: Color(0xfffff9df),
              child: Text('M', style: TextStyle(color: ink)),
            ),
            const SizedBox(width: 10),
            ClipOval(child: photo('nina-card', 86, 86, radius: 43)),
          ],
        ),
        const SizedBox(height: 14),
        if (step == 0) ...[
          const Text(
            'Canela',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vacunada · Convive con niños',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          Center(child: tag('En adopción')),
        ] else ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [tag('Comida'), tag('Medicina'), tag('Veterinario')],
          ),
          const SizedBox(height: 14),
          const Text(
            'Gastos pagados y aprobados',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu cuenta verificada ayuda a que las personas confíen en ti.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ]),
    ],
  );
}
