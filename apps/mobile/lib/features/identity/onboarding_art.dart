import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../../core/design_tokens.dart';

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
                fontVariations: detail ? DopmiTokens.display20Variations : null,
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
    builder: (_, box) {
      final width = box.maxWidth;
      Widget card(Widget child, {required bool main}) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: main ? .12 : .1),
              offset: Offset(0, main ? 12 : 8),
              blurRadius: main ? 28 : 20,
            ),
          ],
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xffe6e2dd)),
          ),
          child: child,
        ),
      );
      return SizedBox(
        height: 248,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Transform.rotate(
                angle: .0872664626,
                child: SizedBox(
                  width: width * .44,
                  height: 248 * .7,
                  child: card(
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        photo('nina-card', width * .44, 248 * .7, radius: 24),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: .78),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Michi también busca hogar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                height: 1.25,
                                letterSpacing: 0,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    main: false,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: SizedBox(
                width: width * .82,
                height: 248 * .92,
                child: card(
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      photo('luna-card', width * .82, 248 * .92, radius: 24),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 248 * .92 * .48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, .45, 1],
                              colors: [
                                Color(0x0015110d),
                                Color(0x8c15110d),
                                Color(0xe015110d),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 16,
                        right: 56,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Luna',
                              style: TextStyle(
                                fontFamily: 'Fraunces',
                                fontSize: 24,
                                fontVariations: DopmiTokens.display24Variations,
                                height: 1.1,
                                letterSpacing: 0,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Refugio Patitas',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                letterSpacing: 0,
                                color: Color(0xebffffff),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: ink.withValues(alpha: .12),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/profile/icon-heart.svg',
                              width: 40,
                              height: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  main: true,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget adoptionDetail() => LayoutBuilder(
    builder: (_, box) {
      Widget detailTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xfffff9df),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: yellow.withValues(alpha: .4)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: ink,
          ),
        ),
      );
      Widget section(String title, List<String> tags) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: .44,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map(detailTag).toList(),
          ),
        ],
      );
      final card = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffe6e2dd)),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: .08),
              offset: const Offset(0, 10),
              blurRadius: 28,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                photo('luna-detail', 64, 64, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Luna',
                        style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 22,
                          fontVariations: DopmiTokens.display22Variations,
                          height: 1.15,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Refugio Patitas',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              color: muted,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xfffff9df),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: yellow.withValues(alpha: .45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: SvgPicture.asset(
                                    'assets/profile/icon-verified.svg',
                                    width: 64,
                                    height: 64,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Flexible(
                                  child: Text(
                                    'Verificada',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xffe6e2dd)),
                  bottom: BorderSide(color: Color(0xffe6e2dd)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  section('SALUD', ['Vacunada', 'Esterilizada']),
                  const SizedBox(height: 10),
                  section('CONVIVE CON', ['Perros', 'Gatos', 'Niños']),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xfff7f4ef),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xffe6e2dd)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '¡Hola! Me interesa Luna',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: yellow,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/onboarding/send.svg',
                        width: 14,
                        height: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cada publicación pasa por revisión de DopMi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.4,
                letterSpacing: 0,
                color: muted,
              ),
            ),
          ],
        ),
      );
      // Source reserves 320px while the decorative card extends below it.
      // Narrow layouts instead retain the full intrinsic height for readable copy.
      if (box.maxWidth < 320) return card;
      return SizedBox(
        height: 320,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: card,
        ),
      );
    },
  );

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

  Widget rescue() => step == 0 ? publicationPreview() : supportPreview();

  Widget supportPreview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SvgPicture.asset(
                'assets/profile/icon-bell.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ejemplo de un caso con apoyo',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffe6e2dd)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: yellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ink.withValues(alpha: .1),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: photo('nina-card', 84, 84, radius: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final need in [
                    ('Comida', 'assets/profile/tab-donate.svg'),
                    ('Medicina', 'assets/onboarding/onb-syringe.svg'),
                    ('Veterinario', 'assets/onboarding/icon-plus-circle.svg'),
                  ]) ...[
                    if (need.$1 != 'Comida') const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xfffff9df),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: yellow.withValues(alpha: .35),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(need.$2, width: 18, height: 18),
                            const SizedBox(height: 6),
                            Text(
                              need.$1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Gastos pagados y aprobados',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  'assets/profile/icon-verified.svg',
                  width: 14,
                  height: 14,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tu cuenta verificada ayuda a que las personas confíen en ti.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.4,
                      letterSpacing: 0,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget publicationPreview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Tu próxima publicación',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.55,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffe6e2dd)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: yellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ink.withValues(alpha: .1),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: photo('nina-card', 84, 84, radius: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Canela',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 22,
                fontVariations: DopmiTokens.display22Variations,
                height: 1.2363636,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vacunada · Convive con niños',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.2666667,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: muted,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'En adopción',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.2666667,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
