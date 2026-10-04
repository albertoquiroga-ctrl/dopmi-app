import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'community_repository.dart';

const personalityLabels = <String, String>{
  'alegre': 'Alegre',
  'feliz': 'Feliz',
  'esperanzado': 'Esperanzado',
  'emocionado': 'Emocionado',
  'triste': 'Triste',
  'enojado': 'Enojado',
  'ansioso': 'Ansioso',
  'tranquilo': 'Tranquilo',
  'contento': 'Contento',
  'satisfecho': 'Satisfecho',
  'solo': 'Solo',
  'nervioso': 'Nervioso',
};

const personalityColors = <String, Color>{
  'alegre': Color(0xfff7f4ef),
  'feliz': Color(0xfff7efb8),
  'esperanzado': Color(0xffd8efc4),
  'emocionado': Color(0xfff6d0dc),
  'triste': Color(0xffd7dceb),
  'enojado': Color(0xfff5d0b8),
  'ansioso': Color(0xffe8dcc8),
  'tranquilo': Color(0xffcfe4f5),
  'contento': Color(0xffcfeee0),
  'satisfecho': Color(0xffddd0f0),
  'solo': Color(0xffc9d7f2),
  'nervioso': Color(0xffe8efb8),
};

const legacyPersonalityLabels = <String, String>{
  'affectionate': 'Cariñoso',
  'playful': 'Juguetón',
  'calm': 'Tranquilo',
  'active': 'Activo',
  'sociable': 'Sociable',
  'independent': 'Independiente',
};

const discoveryFilterSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><path d="M4 7h16" stroke="#15110d" stroke-width="1.8" stroke-linecap="round"/><circle cx="16.5" cy="7" r="2.25" fill="#15110d"/><path d="M4 17h16" stroke="#15110d" stroke-width="1.8" stroke-linecap="round"/><circle cx="7.5" cy="17" r="2.25" fill="#15110d"/></svg>';

class DiscoveryFilters extends StatefulWidget {
  const DiscoveryFilters(this.current, {super.key});
  final Json current;
  @override
  State<DiscoveryFilters> createState() => _DiscoveryFiltersState();
}

class _DiscoveryFiltersState extends State<DiscoveryFilters> {
  late String? sex = widget.current['sex'] as String?;
  late String? size = widget.current['size'] as String?;
  late Set<String> traits = Set<String>.from(
    widget.current['personality'] as List? ?? const [],
  );
  Widget heading(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: ink,
      letterSpacing: 0,
    ),
  );

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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text(
                    'Filtros',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      height: 18 / 22,
                      fontWeight: FontWeight.w600,
                      color: ink,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                heading('Género'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xffe6e2dd)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in const [
                          ('female', 'Hembra'),
                          ('male', 'Macho'),
                        ])
                          SizedBox(
                            width:
                                MediaQuery.textScalerOf(context).scale(14) > 20
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 8) / 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: FilterOption(
                                label: item.$2,
                                selected: sex == item.$1,
                                fill: sex == item.$1 ? ink : Colors.white,
                                foreground: sex == item.$1
                                    ? Colors.white
                                    : muted,
                                fontSize: 14,
                                onPressed: () => setState(
                                  () => sex = sex == item.$1 ? null : item.$1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                heading('Tamaño'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final item in const [
                        ('small', 'Chico', 30.0),
                        ('medium', 'Mediano', 40.0),
                        ('large', 'Grande', 52.0),
                      ])
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: size == item.$1,
                            label: item.$2,
                            child: Tooltip(
                              message: item.$2,
                              child: InkWell(
                                splashFactory: NoSplash.splashFactory,
                                overlayColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => setState(
                                  () => size = size == item.$1 ? null : item.$1,
                                ),
                                child: SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: SvgPicture.string(
                                      sizeDogSvg(size == item.$1),
                                      width: item.$3,
                                      height: item.$3 * .78,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                heading('Personalidad'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(11) > 20
                        ? 1
                        : MediaQuery.textScalerOf(context).scale(11) > 15
                        ? 2
                        : 4;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in personalityLabels.entries)
                          SizedBox(
                            width:
                                (constraints.maxWidth - (columns - 1) * 8) /
                                columns,
                            child: FilterOption(
                              label: item.value,
                              selected: traits.contains(item.key),
                              fill: personalityColors[item.key]!,
                              foreground: ink,
                              fontSize: 11,
                              outlined: true,
                              onPressed: () => setState(() {
                                traits.contains(item.key)
                                    ? traits.remove(item.key)
                                    : traits.add(item.key);
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                    animationDuration: Duration.zero,
                    minimumSize: const Size(0, 42),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: yellow,
                    foregroundColor: ink,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.pop(<String, dynamic>{
                    if (sex != null) 'sex': sex,
                    if (size != null) 'size': size,
                    if (traits.isNotEmpty) 'personality': traits.toList(),
                  }),
                  child: const Text('Aplicar filtros'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                    animationDuration: Duration.zero,
                    minimumSize: const Size(0, 42),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: ink,
                    side: const BorderSide(color: Color(0xffe6e2dd)),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.pop(<String, dynamic>{}),
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Cerrar',
              style: IconButton.styleFrom(overlayColor: Colors.transparent),
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close, size: 22, color: muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class FilterOption extends StatelessWidget {
  const FilterOption({
    super.key,
    required this.label,
    required this.selected,
    required this.fill,
    required this.foreground,
    required this.fontSize,
    required this.onPressed,
    this.outlined = false,
  });
  final String label;
  final bool selected, outlined;
  final Color fill, foreground;
  final double fontSize;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: TextButton(
      style: TextButton.styleFrom(
        splashFactory: NoSplash.splashFactory,
        overlayColor: Colors.transparent,
        animationDuration: Duration.zero,
        minimumSize: Size(0, outlined ? 34 : 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(
          horizontal: outlined ? 0 : 4,
          vertical: 6,
        ),
        backgroundColor: fill,
        foregroundColor: foreground,
        side: BorderSide(
          width: 1.5,
          color: outlined && selected ? ink : Colors.transparent,
        ),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          height: 1.15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: MediaQuery.textScalerOf(context).scale(fontSize) > 15,
        overflow: TextOverflow.visible,
      ),
    ),
  );
}

String sizeDogSvg(bool active) {
  final fill = active ? '#15110d' : 'none';
  final color = active ? '#15110d' : '#9a9289';
  final legs = active ? 3.2 : 2.2;
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 56" fill="none"><g stroke="$color" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="$fill"><path d="M10 28c-6-2-9 2-9 7 0 2 2 3.5 4 2.5l7-3.5"/><ellipse cx="30" cy="32" rx="18" ry="12"/><circle cx="50" cy="22" r="11"/><path d="M46 12c2-8 12-10 16-4 1.2 1.8 0 4-2.2 4.2L50 13"/><ellipse cx="60" cy="26" rx="6" ry="4.5"/></g><circle cx="52" cy="20" r="1.8" fill="${active ? '#ffffff' : color}"/><g stroke="$color" stroke-width="$legs" stroke-linecap="round"><path d="M18 42v8M26 43v7"/><path d="M38 42v8M46 41v9"/></g></svg>';
}
