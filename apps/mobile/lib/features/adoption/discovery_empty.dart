import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/design_tokens.dart';
import 'community_ui.dart';

class DiscoveryEmpty extends StatelessWidget {
  const DiscoveryEmpty({
    super.key,
    required this.filtered,
    required this.global,
    required this.species,
    required this.clear,
    required this.switchSpecies,
  });
  final bool filtered, global;
  final String species;
  final VoidCallback clear, switchSpecies;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          key: const ValueKey('discovery-empty-card'),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xffe6e2dd)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2415110d),
                offset: Offset(0, 12),
                blurRadius: 32,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _EmptyHeading(),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width:
                      264.961 * MediaQuery.textScalerOf(context).scale(14) / 14,
                  child: _EmptyCopy(
                    filtered
                        ? 'Prueba otros filtros o limpia la selección para ver más opciones.'
                        : global
                        ? 'Por ahora no hay mascotas en adopción. Vuelve pronto o apoya a quienes ya buscan ayuda.'
                        : 'Por ahora no hay ${species == 'dog' ? 'perros' : 'gatos'} en adopción. Prueba la otra categoría o vuelve pronto.',
                  ),
                ),
              ),
              // Source paragraph margin16 + grid gap8 + button margin4.
              const SizedBox(height: 28),
              FilledButton(
                onPressed: filtered
                    ? clear
                    : global
                    ? () => context.go('/rescue-cases')
                    : switchSpecies,
                style: FilledButton.styleFrom(
                  backgroundColor: global && !filtered
                      ? ink
                      : const Color(0xfffaf8f5),
                  foregroundColor: global && !filtered ? Colors.white : ink,
                  minimumSize: const Size(0, 52),
                  side: global && !filtered
                      ? null
                      : const BorderSide(color: Color(0xffe8e2d9)),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  filtered
                      ? 'Limpiar filtros'
                      : global
                      ? 'Ir a Apoyar'
                      : 'Ver ${species == 'dog' ? 'gatos' : 'perros'}',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DiscoveryEnd extends StatelessWidget {
  const DiscoveryEnd({
    super.key,
    required this.restart,
    this.photos = const [],
    this.minimumHeight = 0,
  });
  final List<String> photos;
  final double minimumHeight;
  final VoidCallback restart;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minimumHeight),
    child: Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 328),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (photos.isNotEmpty)
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (_, box) {
                          final width = (box.maxWidth - 12) / 2;
                          return Opacity(
                            opacity: .46,
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                .905512,
                                .085824,
                                .008664,
                                0,
                                0,
                                .025512,
                                .965824,
                                .008664,
                                0,
                                0,
                                .025512,
                                .085824,
                                .888664,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                              child: Stack(
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final photo in photos.take(4))
                                        SizedBox(
                                          width: width,
                                          height: width * 4 / 3,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x1f15110d),
                                                  offset: Offset(0, 10),
                                                  blurRadius: 24,
                                                ),
                                              ],
                                            ),
                                            child: AdoptionPhoto(
                                              photo,
                                              radius: 22,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Positioned.fill(
                                    child: ColoredBox(color: Color(0x47ffffff)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 302),
                  child: Container(
                    key: const ValueKey('discovery-end-card'),
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1f15110d),
                          offset: Offset(0, 8),
                          blurRadius: 28,
                        ),
                        BoxShadow(
                          color: Color(0x0f15110d),
                          offset: Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Nuestra manada llegó hasta aquí por ahora',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Todos los días hay historias nuevas esperando a alguien como tú.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            height: 1.45,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.go('/messages'),
                          style: FilledButton.styleFrom(
                            backgroundColor: yellow,
                            foregroundColor: ink,
                            minimumSize: const Size(0, 50),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Ir a mis '),
                                TextSpan(
                                  text: 'favoritos',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: restart,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            side: const BorderSide(color: yellow, width: 1.5),
                            minimumSize: const Size(0, 50),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Volver a '),
                                TextSpan(
                                  text: 'descubrir',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Reserves fractional CSS line height without scaling native glyphs.
class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy(this.text);
  final String text;
  static const style = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.45,
    color: muted,
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final measure = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: box.maxWidth);
      final height =
          measure.computeLineMetrics().length * scaler.scale(14) * 1.45;
      measure.dispose();
      return SizedBox(
        height: height,
        child: Text(text, textAlign: TextAlign.center, style: style),
      );
    },
  );
}

/// HTML word-break:normal keeps long words intact even when they extend into
/// the card padding. Flutter Text would otherwise split them mid-word.
class _EmptyHeading extends StatelessWidget {
  const _EmptyHeading();
  static const title = 'No hay mascotas disponibles';
  static const style = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 26,
    fontVariations: DopmiTokens.display26Variations,
    height: 1.2,
    letterSpacing: -.52,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final space = TextPainter(
      text: const TextSpan(text: ' ', style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final spacing = space.width;
    space.dispose();
    Widget wordWidget(String word) {
      final measure = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = measure.width;
      final height = scaler.scale(26) * 1.2;
      measure.dispose();
      return LayoutBuilder(
        builder: (_, constraints) => SizedBox(
          width: width.clamp(0.0, constraints.maxWidth).toDouble(),
          height: height,
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: Text(
              word,
              style: style,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Center(
      child: SizedBox(
        key: const ValueKey('discovery-empty-heading'),
        width: 244.244 * scaler.scale(26) / 26,
        child: Semantics(
          key: const ValueKey('discovery-empty-heading-semantics'),
          container: true,
          header: true,
          label: title,
          child: ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              children: [for (final word in title.split(' ')) wordWidget(word)],
            ),
          ),
        ),
      ),
    );
  }
}
