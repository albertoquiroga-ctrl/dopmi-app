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
        Container(
          constraints: const BoxConstraints(minHeight: 58),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xffe6e2dd)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Semantics(
            button: true,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => item.$4 == '/my-cases' || item.$4 == '/messages'
                    ? context.go(item.$4)
                    : context.push(item.$4),
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
                            'assets/profile/${item.$3}.svg',
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
                              item.$1,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                                letterSpacing: 0,
                                color: Color(0xff15110d),
                              ),
                            ),
                            if (item.$2.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.$2,
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
