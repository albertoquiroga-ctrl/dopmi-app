import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
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
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              const Center(
                child: SizedBox(
                  width: 244.244,
                  child: Text(
                    'No hay mascotas disponibles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 26,
                      height: 1.2,
                      letterSpacing: -.52,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filtered
                    ? 'Prueba otros filtros o limpia la selección para ver más opciones.'
                    : global
                    ? 'Por ahora no hay mascotas en adopción. Vuelve pronto o apoya a quienes ya buscan ayuda.'
                    : 'Por ahora no hay ${species == 'dog' ? 'perros' : 'gatos'} en adopción. Prueba la otra categoría o vuelve pronto.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.45,
                  color: muted,
                ),
              ),
              const SizedBox(height: 18),
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
  });
  final List<String> photos;
  final VoidCallback restart;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (photos.isNotEmpty)
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      box.maxWidth * .04,
                      box.maxHeight * .12,
                      box.maxWidth * .04,
                      box.maxHeight * .08,
                    ),
                    child: Opacity(
                      opacity: .38,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          .88189,
                          .10728,
                          .01083,
                          0,
                          0,
                          .03189,
                          .95728,
                          .01083,
                          0,
                          0,
                          .03189,
                          .10728,
                          .86083,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: LayoutBuilder(
                          builder: (_, mosaic) {
                            final width = (mosaic.maxWidth - 14) / 2;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (var index = 0; index < 4; index++)
                                  Positioned(
                                    left: (index % 2) * (width + 14),
                                    top:
                                        (index ~/ 2) *
                                        ((mosaic.maxHeight + 14) / 2),
                                    width: width,
                                    height: width * 4 / 3,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x1f15110d),
                                            offset: Offset(0, 10),
                                            blurRadius: 24,
                                          ),
                                        ],
                                      ),
                                      child: AdoptionPhoto(
                                        photos[index % photos.length],
                                        radius: 22,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
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
                      '¡No te desanimes! nuestro feed se actualiza constantemente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 1.45,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tip: Ajusta los filtros para descubrir más historias.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.4,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 18),
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
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: restart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: muted,
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
