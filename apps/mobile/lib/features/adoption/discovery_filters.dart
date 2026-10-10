import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/dialog_close.dart';
import 'community_repository.dart';
import 'adoption_traits.dart';
export 'adoption_traits.dart'
    show personalityLabels, personalityColors, legacyPersonalityLabels;

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
  late Set<String> traits = (widget.current['personality'] as List? ?? const [])
      .whereType<String>()
      .where(personalityLabels.containsKey)
      .take(1)
      .toSet();
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                const SizedBox(height: 12),
                heading('Sexo'),
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
                LayoutBuilder(
                  builder: (context, box) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in const [
                        ('small', 'Chico', 14.0),
                        ('medium', 'Mediano', 22.0),
                        ('large', 'Grande', 30.0),
                      ])
                        SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(13) > 20
                              ? box.maxWidth
                              : (box.maxWidth - 16) / 3,
                          child: Semantics(
                            button: true,
                            selected: size == item.$1,
                            label: item.$2,
                            child: Tooltip(
                              message: item.$2,
                              child: TextButton(
                                onPressed: () => setState(
                                  () => size = size == item.$1 ? null : item.$1,
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: size == item.$1
                                      ? const Color(0x147c3aed)
                                      : Colors.white,
                                  foregroundColor: size == item.$1
                                      ? const Color(0xff7c3aed)
                                      : const Color(0xff151423),
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    8,
                                    4,
                                    6,
                                  ),
                                  minimumSize: const Size(0, 66),
                                  visualDensity: VisualDensity.standard,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  splashFactory: NoSplash.splashFactory,
                                  overlayColor: Colors.transparent,
                                  animationDuration: Duration.zero,
                                  side: BorderSide(
                                    color: size == item.$1
                                        ? const Color(0xff7c3aed)
                                        : const Color(0xffe3e4ed),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.15,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 30,
                                      child: Center(
                                        child: SvgPicture.asset(
                                          'assets/profile/notif-pet.svg',
                                          width: item.$3,
                                          height: item.$3,
                                          colorFilter: ColorFilter.mode(
                                            size == item.$1
                                                ? const Color(0xff7c3aed)
                                                : const Color(0xff151423),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(item.$2, textAlign: TextAlign.center),
                                  ],
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
                    final textScaler = MediaQuery.textScalerOf(context);
                    final widths = <String, double>{};
                    for (final item in personalityLabels.entries) {
                      final painter = TextPainter(
                        text: TextSpan(
                          text: item.value,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: textScaler,
                      )..layout();
                      widths[item.key] = math.min(
                        constraints.maxWidth,
                        painter.width.ceilToDouble() + 26,
                      );
                      painter.dispose();
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in personalityLabels.entries)
                          SizedBox(
                            width: widths[item.key],
                            child: FilterOption(
                              label: item.value,
                              selected: traits.contains(item.key),
                              fill: personalityColors[item.key]!,
                              foreground: traits.contains(item.key)
                                  ? const Color(0xff4c1d95)
                                  : personalityTextColors[item.key]!,
                              border: traits.contains(item.key)
                                  ? const Color(0xff7c3aed)
                                  : personalityBorderColors[item.key]!,
                              fontSize: 12,
                              outlined: true,
                              onPressed: () => setState(() {
                                final selected = traits.contains(item.key);
                                traits.clear();
                                if (!selected) traits.add(item.key);
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                    animationDuration: Duration.zero,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    visualDensity: VisualDensity.standard,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: yellow,
                    foregroundColor: ink,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      height: 1.25,
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
                  child: const Text(
                    'Aplicar filtros',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                    animationDuration: Duration.zero,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    visualDensity: VisualDensity.standard,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: ink,
                    side: const BorderSide(color: Color(0xffe6e2dd)),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.pop(<String, dynamic>{}),
                  child: const Text(
                    'Limpiar filtros',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          DopmiDialogClose(onPressed: () => context.pop()),
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
    this.border,
  });
  final String label;
  final bool selected, outlined;
  final Color fill, foreground;
  final Color? border;
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
          width: outlined && selected ? 2 : 1,
          color: border ?? (outlined && selected ? ink : Colors.transparent),
        ),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          height: 1.15,
          fontWeight: outlined ? FontWeight.w500 : FontWeight.w600,
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
