import 'dart:math' as math;
import 'dart:ui' as ui;

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

  Widget frost(
    Widget child, {
    double radius = 28,
    double opacity = .38,
    double blur = 16,
    EdgeInsets padding = const EdgeInsets.all(11),
  }) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1a46281d),
          offset: Offset(0, 12),
          blurRadius: 32,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xc7ffffff)),
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-.259, -.966),
              end: Alignment(.259, .966),
              stops: [0, .52, 1],
              colors: [
                for (final veil in const [
                  Color(0x61ffffff),
                  Color(0xb8ffffff),
                  Color(0xd1ffffff),
                ])
                  Color.alphaBlend(
                    veil,
                    Colors.white.withValues(alpha: opacity),
                  ),
              ],
            ),
          ),
          child: child,
        ),
      ),
    ),
  );

  Widget sampleText(
    String text, {
    double size = 12,
    Color color = ink,
    FontWeight weight = FontWeight.w600,
    double height = 1.3,
  }) => Text(
    text,
    style: TextStyle(
      fontFamily: DopmiTokens.bodyFont,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    ),
  );

  Widget discoverCard({bool species = true, bool tags = true}) => frost(
    Stack(
      children: [
        Positioned.fill(
          child: photo('rocky', double.infinity, double.infinity, radius: 20),
        ),
        const Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: .58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .38, .72, 1],
                    colors: [
                      Color(0x0015110d),
                      Color(0x5946281d),
                      Color(0xd115110d),
                      Color(0xeb15110d),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (species)
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0x6115110d),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: DopmiTokens.orange, width: 1.5),
                    ),
                    child: sampleText(
                      'Perros',
                      size: 14,
                      color: DopmiTokens.orange,
                      weight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: sampleText(
                      'Gatos',
                      size: 14,
                      color: const Color(0xb8ffffff),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 32,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sampleText(
                'Rocky',
                size: 28,
                color: yellow,
                weight: FontWeight.w700,
                height: 1.05,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/profile/location.svg',
                    width: 12,
                    height: 12,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Monterrey, MX',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DopmiTokens.bodyFont,
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              if (tags) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in ['Macho', 'Grande', 'Alegre'])
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33ffffff),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: const Color(0x6bffffff)),
                        ),
                        child: sampleText(
                          tag,
                          size: 11,
                          color: const Color(0xfffdf6f1),
                          weight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget sampleLike() => Container(
    width: 52,
    height: 52,
    decoration: const BoxDecoration(
      color: DopmiTokens.orange,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Color(0x61eb6425),
          offset: Offset(0, 6),
          blurRadius: 18,
        ),
      ],
    ),
    child: Center(
      child: SvgPicture.asset(
        'assets/navigation/nav-heart-solid.svg',
        width: 22,
        height: 22,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    ),
  );

  Widget adoptionStack() => Builder(
    builder: (context) {
      final height = math.max(
        320.0,
        math.min(380.0, MediaQuery.sizeOf(context).height * .5),
      );
      return SizedBox(
        height: height,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    right: 6,
                    width: box.maxWidth * .72,
                    height: height * .78,
                    child: frost(
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/guardian/bubbles/milo-card.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 0,
                    width: box.maxWidth * .8,
                    height: height * .86,
                    child: frost(
                      photo(
                        'luna-card',
                        double.infinity,
                        double.infinity,
                        radius: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: box.maxWidth * .92,
                    height: height * .94,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: discoverCard()),
                        Positioned(right: 6, bottom: 6, child: sampleLike()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget adoptionDetail() => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 442),
    child: frost(
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x47ffffff),
            border: Border.all(color: const Color(0xc7ffffff)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              photo('luna-detail', double.infinity, 132, radius: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sampleText(
                      'Luna',
                      size: 22,
                      weight: FontWeight.w700,
                      height: 1.1,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        sampleText(
                          'Refugio Patitas',
                          size: 13,
                          color: muted,
                          height: 1.2,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: DopmiTokens.sky,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: DopmiTokens.sky),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/profile/icon-verified-celeste.svg',
                                width: 12,
                                height: 12,
                              ),
                              const SizedBox(width: 4),
                              sampleText(
                                'Verificada',
                                size: 10,
                                color: const Color(0xff3a6d8c),
                                weight: FontWeight.w700,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: Color(0x1446281d)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in [
                            ('SALUD', ['Vacunada', 'Esterilizada']),
                            ('CONVIVE CON', ['Perros', 'Gatos', 'Niños']),
                          ]) ...[
                            if (entry.$1 != 'SALUD') const SizedBox(height: 8),
                            sampleText(
                              entry.$1,
                              size: 10,
                              weight: FontWeight.w700,
                              height: 1.2,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                for (final value in entry.$2)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DopmiTokens.saffronSoft,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: const Color(0x8cffffff),
                                      ),
                                    ),
                                    child: sampleText(
                                      value,
                                      size: 10,
                                      weight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    frost(
                      Row(
                        children: [
                          Expanded(
                            child: sampleText(
                              '¡Hola! Me interesa Luna',
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: ink,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/onboarding/send.svg',
                                width: 14,
                                height: 14,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      radius: 99,
                      opacity: .48,
                      blur: 14,
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Cada publicación pasa por revisión de DopMi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        height: 1.4,
                        color: DopmiTokens.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      opacity: .4,
      blur: 28,
    ),
  );

  Widget rescue() => step == 0 ? publicationPreview() : supportPreview();

  Widget publicationPreview() => Builder(
    builder: (context) {
      final height = math.max(
        340.0,
        math.min(400.0, MediaQuery.sizeOf(context).height * .52),
      );
      return SizedBox(
        height: height,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    width: math.min(272.0, box.maxWidth * .82),
                    child: frost(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sampleText(
                            'En adopción',
                            size: 17,
                            weight: FontWeight.w700,
                            height: 1.15,
                          ),
                          const SizedBox(height: 8),
                          sampleText(
                            '15 activos | 3 pendientes de publicar',
                            size: 11,
                            color: muted,
                            weight: FontWeight.w400,
                            height: 1.35,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            child: Stack(
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Positioned(
                                    left: i * 29.0,
                                    top: 0,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: ClipOval(
                                        child: Image.asset(
                                          i == 2
                                              ? 'assets/guardian/bubbles/milo-card.png'
                                              : 'assets/onboarding/${i == 0 ? 'luna-card' : 'rocky'}.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      radius: 22,
                      opacity: .82,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: -10,
                    bottom: 78,
                    left: box.maxWidth * .18,
                    child: LayoutBuilder(
                      builder: (context, cardBox) => Align(
                        alignment: Alignment.bottomRight,
                        child: SizedBox(
                          width: cardBox.maxWidth * .78,
                          height: cardBox.maxHeight * .96,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: discoverCard(
                                  species: false,
                                  tags: false,
                                ),
                              ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: sampleLike(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: height * .74,
                    left: 0,
                    width: math.min(268.0, box.maxWidth * .82),
                    child: frost(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              sampleText(
                                'Chats',
                                size: 14,
                                weight: FontWeight.w700,
                              ),
                              sampleText('Sin leer', size: 11),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.fromLTRB(4, 9, 6, 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                photo('luna-card', 40, 40, radius: 99),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Luna - Ana P.',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 12,
                                                height: 1.3,
                                                fontWeight: FontWeight.w700,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          sampleText(
                                            '10:36',
                                            size: 10,
                                            color: const Color(0xff9a9289),
                                            weight: FontWeight.w500,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Perfecto. ¿Cuándo podrías visitarnos…',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          height: 1.35,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 18,
                                  height: 18,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: ink,
                                    shape: BoxShape.circle,
                                  ),
                                  child: sampleText(
                                    '1',
                                    size: 10,
                                    color: Colors.white,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      radius: 22,
                      opacity: .88,
                      blur: 14,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget supportPreview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: DopmiTokens.sky,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffb8ddf5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/profile/icon-bell.svg',
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                Color(0xff3a6d8c),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: sampleText(
                '3 personas ya apoyaron a Canela',
                color: const Color(0xff3a6d8c),
                height: 1.35,
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
          border: Border.all(color: DopmiTokens.line),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: yellow,
                    shape: BoxShape.circle,
                  ),
                  child: sampleText('M', size: 20, weight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                photo('nina-card', 88, 88, radius: 20),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff9df),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x59f7cb2d)),
                      ),
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            'assets/onboarding/${['icon-bone', 'icon-medicine', 'icon-paw'][index]}.svg',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(height: 6),
                          sampleText(
                            ['Comida', 'Medicina', 'Veterinario'][index],
                            size: 11,
                            weight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            sampleText(
              '12 personas ya apoyaron este mes',
              size: 13,
              weight: FontWeight.w700,
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
                Expanded(
                  child: sampleText(
                    'Tu cuenta verificada es lo que hace que la gente confíe en ti.',
                    color: DopmiTokens.navigationInactive,
                    weight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
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
}
