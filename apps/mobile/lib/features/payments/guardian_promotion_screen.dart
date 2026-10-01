import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'contribution_layout.dart';

class GuardianPromotionScreen extends StatefulWidget {
  const GuardianPromotionScreen({
    super.key,
    this.available = true,
    this.navigation,
  });
  final bool available;
  final Widget? navigation;
  @override
  State<GuardianPromotionScreen> createState() => _GuardianPromotionState();
}

class _GuardianPromotionState extends State<GuardianPromotionScreen> {
  final pages = PageController();
  int active = 0;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void select(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      pages.jumpToPage(index);
    } else {
      pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeHeading = MediaQuery.textScalerOf(context).scale(26) > 39;
    const slides = [
      _PromotionSlide(
        photo: 'assets/guardian/guardian-urgent.jpg',
        tag: 'Gastos aprobados',
        lead: 'Tu ayuda llega a',
        highlight: 'casos que necesitan apoyo',
        copy: 'Cada aporte mensual ayuda a cubrir necesidades reales de mascotas rescatadas.',
        icon: Icons.pets_outlined,
        stages: ['Atención veterinaria', 'Alimentación', 'Cuidados necesarios'],
      ),
      _PromotionSlide(
        tag: 'Asignación completa',
        lead: 'Tu aportación cubre',
        highlight: 'necesidades reales',
        copy: 'Solo se cobra cuando todo el neto puede asignarse a gastos aprobados. Si no hay capacidad, ese mes se omite sin cargo ni deuda.',
        icon: Icons.shield_outlined,
        stages: [
          'Aportación mensual',
          'Asignación del neto completo',
          'Gastos aprobados',
        ],
      ),
      _PromotionSlide(
        photo: 'assets/guardian/guardian-reports.jpg',
        tag: 'Avances publicados',
        lead: 'Ves el impacto',
        highlight: 'de tu aporte',
        copy: 'Consulta las asignaciones de tus aportaciones y los avances públicos de los casos que apoyaste.',
        icon: Icons.auto_stories_outlined,
        stages: [
          'Tus asignaciones',
          'Avances de los casos',
          'Evidencia publicada',
        ],
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: widget.navigation,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Conviértete en Guardián',
                  style: TextStyle(
                    fontSize: largeHeading ? 23 : 26,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Elige un apoyo mensual para ayudar a cubrir gastos aprobados de mascotas rescatadas que necesitan atención y un hogar.',
                style: TextStyle(fontSize: 14, height: 1.5, color: muted),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, box) => SizedBox(
                  height: slides
                      .map(
                        (slide) => slide.requiredHeight(context, box.maxWidth),
                      )
                      .fold<double>(
                        box.maxWidth * 4 / 3,
                        (left, right) => math.max(left, right),
                      ),
                  child: PageView(
                    controller: pages,
                    onPageChanged: (value) => setState(() => active = value),
                    children: slides,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(5, (slot) {
                  if (slot.isOdd) return const SizedBox(width: 6);
                  final index = slot ~/ 2;
                  return Semantics(
                    button: true,
                    selected: active == index,
                    label: 'Ir a la página ${index + 1} de 3',
                    child: InkWell(
                      onTap: () => select(index),
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        width: active == index ? 22 : 8,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: active == index ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active == index
                                  ? yellow
                                  : const Color(0xffd9d4cd),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              for (final label in [
                'Consulta tus avances',
                'Cancela los ciclos futuros',
                'Monto ajustable',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 13, color: ink),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              ContributionButton(
                widget.available
                    ? 'Unirme como Guardián'
                    : 'Guardián todavía no está disponible',
                onPressed: widget.available
                    ? () => context.push('/guardian?enroll=1')
                    : null,
              ),
              TextButton(
                onPressed: () => context.push('/impact?history=1'),
                child: const Text('Ver mi impacto'),
              ),
              TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/profile'),
                child: const Text('Regresar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionSlide extends StatelessWidget {
  const _PromotionSlide({
    this.photo,
    required this.tag,
    required this.lead,
    required this.highlight,
    required this.copy,
    required this.icon,
    required this.stages,
  });
  final String? photo;
  final String tag, lead, highlight, copy;
  final IconData icon;
  final List<String> stages;
  double requiredHeight(BuildContext context, double width) {
    double measure(
      String text,
      double size,
      double height,
      FontWeight weight,
      double available,
    ) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(
            TextStyle(
              fontSize: size,
              height: height,
              fontWeight: weight,
              letterSpacing: size == 23 ? -.46 : 0,
            ),
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: available);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final stage =
        28 +
        24 +
        10 +
        stages.fold<double>(
          0,
          (sum, value) =>
              sum + 10 + measure(value, 13, 1.3, FontWeight.w600, width - 56),
        );
    return 28 +
        stage +
        24 +
        measure(tag, 11, 1.2, FontWeight.w600, width - 48) +
        10 +
        6 +
        measure(lead, 23, 1.14, FontWeight.w800, width - 28) +
        measure(highlight, 23, 1.14, FontWeight.w800, width - 28) +
        6 +
        measure(copy, 12, 1.45, FontWeight.w400, width - 28);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (photo != null)
          ExcludeSemantics(
            child: Image.asset(
              photo!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xfff5f1e8),
                  Color(0xff7b7367),
                  Color(0xff1c1916),
                ],
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x57000000),
                Color(0x0a000000),
                Color(0x85000000),
                Color(0xf20a0806),
              ],
              stops: [0, .28, .58, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xf5ffffff),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: ink, size: 24),
                    const SizedBox(height: 10),
                    for (final stage in stages)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          stage,
                          style: const TextStyle(
                            fontSize: 13,
                            letterSpacing: 0,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x29ffffff),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 0,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lead,
                style: const TextStyle(
                  fontSize: 23,
                  letterSpacing: -.46,
                  height: 1.14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                highlight,
                style: const TextStyle(
                  fontSize: 23,
                  letterSpacing: -.46,
                  height: 1.14,
                  fontWeight: FontWeight.w800,
                  color: yellow,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                copy,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
