import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class RescuerProfileAccess extends StatelessWidget {
  const RescuerProfileAccess({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _RescuerAccessHeading(),
      const SizedBox(height: 12),
      for (final item in const [
        (
          'Configuración',
          'Verificación, redes y datos bancarios',
          'icon-settings',
          '/settings',
        ),
        (
          'Mis casos',
          'Gestiona adopción y donación',
          'rtab-cases',
          '/my-cases',
        ),
        ('Mensajes', 'Habla con adoptantes', 'icon-messages', '/messages'),
        ('Centro de ayuda', '', 'icon-help', '/help'),
      ]) ...[
        if (item.$1 != 'Configuración') const SizedBox(height: 10),
        RescuerNavigationRow(
          title: item.$1,
          subtitle: item.$2,
          icon: item.$3,
          path: item.$4,
        ),
      ],
    ],
  );
}

class _RescuerAccessHeading extends StatelessWidget {
  const _RescuerAccessHeading();
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: const Text(
      'Accesos',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Color(0xff15110d),
      ),
    ),
  );
}

class RescuerNavigationRow extends StatefulWidget {
  const RescuerNavigationRow({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    required this.path,
  });
  final String title, subtitle, icon, path;
  @override
  State<RescuerNavigationRow> createState() => _RescuerNavigationRowState();
}

class _RescuerNavigationRowState extends State<RescuerNavigationRow> {
  bool hovered = false, focused = false;
  void updateHighlightMode(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(updateHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(updateHighlightMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        key: const ValueKey('rescuer-navigation-card'),
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: hovered ? const Color(0xffd8d2ca) : const Color(0xffe6e2dd),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Semantics(
          button: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onHover: (value) => setState(() => hovered = value),
              onFocusChange: (value) => setState(() => focused = value),
              onTap: () =>
                  widget.path == '/my-cases' || widget.path == '/messages'
                  ? context.go(widget.path)
                  : context.push(widget.path),
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xfffff6d6),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'assets/profile/${widget.icon}.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Color(0xff6b5000),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: 0,
                              color: Color(0xff15110d),
                            ),
                          ),
                          if (widget.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                height: 1.4,
                                letterSpacing: 0,
                                color: Color(0xff554e48),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        'assets/profile/icon-chevron-right.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (focused &&
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional)
        Positioned(
          left: -5,
          right: -5,
          top: -5,
          bottom: -5,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: DecoratedBox(
                key: const ValueKey('rescuer-navigation-focus'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0x4d7841f2), width: 3),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
