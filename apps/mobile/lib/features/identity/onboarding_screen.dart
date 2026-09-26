import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';

import '../../core/ui.dart';

String safeIntent(String? intent) =>
    ['adopt', 'donate', 'rescue'].contains(intent) ? intent! : 'adopt';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? intent;
  static const options = [
    (
      'donate',
      'Donar',
      'Apoya necesidades concretas de casos reales y sigue el impacto de tu aportación.',
    ),
    (
      'adopt',
      'Adoptar',
      'Conoce mascotas rescatadas listas para un hogar y habla con su rescatista.',
    ),
    (
      'rescue',
      'Dar en adopción',
      'Publica casos, pide apoyo para necesidades y comparte evidencia con tu comunidad.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final selected = intent == null
        ? null
        : options.firstWhere((option) => option.$1 == intent);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 60).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Brand(),
                    ),
                    if (selected == null) ...[
                      const SizedBox(height: 36),
                      Text(
                        'Bienvenido a DopMi',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ayuda a mascotas rescatadas de forma segura, simple y transparente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: SvgPicture.asset(
                          'assets/navigation/choice-paw.svg',
                          width: 28,
                          height: 28,
                        ),
                      ),
                      SizedBox(
                        height:
                            (constraints.maxHeight - 620).clamp(24, 220) / 2,
                      ),
                    ] else
                      const SizedBox(height: 28),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          selected == null
                              ? '¿Cómo quieres ayudar hoy?'
                              : '¿Cómo quieres ayudar?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: DopmiTokens.displayFont,
                            fontSize: selected == null ? 32 : 28,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                    if (selected == null)
                      SizedBox(
                        height:
                            (constraints.maxHeight - 620).clamp(24, 220) / 2,
                      )
                    else
                      const SizedBox(height: 40),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final option in options)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: option.$1 == 'adopt' ? 0 : 22,
                              ),
                              child: Semantics(
                                label: option.$2,
                                checked: intent == option.$1,
                                inMutuallyExclusiveGroup: true,
                                button: true,
                                onTap: () => setState(() => intent = option.$1),
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(50),
                                    onTap: () =>
                                        setState(() => intent = option.$1),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          width: intent == option.$1
                                              ? 92
                                              : selected == null
                                              ? 76
                                              : 64,
                                          height: intent == option.$1
                                              ? 92
                                              : selected == null
                                              ? 76
                                              : 64,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: intent == option.$1
                                                ? const Color(0xfffff6cf)
                                                : Colors.white,
                                            border: Border.all(
                                              color: yellow,
                                              width: intent == option.$1
                                                  ? 2
                                                  : 1.5,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: SvgPicture.asset(
                                            'assets/navigation/choice-${option.$1}.svg',
                                            width: intent == option.$1
                                                ? 32
                                                : 26,
                                            height: intent == option.$1
                                                ? 32
                                                : 26,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          option.$2,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: intent == option.$1
                                                ? ink
                                                : muted,
                                            fontWeight: intent == option.$1
                                                ? FontWeight.w700
                                                : FontWeight.w500,
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
                    ),
                    if (selected != null) ...[
                      SizedBox(
                        height:
                            (constraints.maxHeight - 620).clamp(24, 220) / 2,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        selected.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: DopmiTokens.displayFont,
                          fontSize: 36,
                          color: ink,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selected.$3,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height:
                            (constraints.maxHeight - 620).clamp(24, 220) / 2,
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () =>
                            context.push('/onboarding?intent=$intent'),
                        child: const Text('Continuar'),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Puedes cambiar tu selección en cualquier momento desde la configuración de tu perfil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Ya tengo cuenta · Iniciar sesión'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/adoptions'),
                      child: const Text('Explorar adopciones sin cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.intent});
  final String intent;
  @override
  Widget build(BuildContext context) {
    final rescue = intent == 'rescue';
    return PageFrame(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(36),
          decoration: const BoxDecoration(
            color: yellow,
            shape: BoxShape.circle,
          ),
          child: Icon(
            rescue ? Icons.volunteer_activism_outlined : Icons.pets_rounded,
            size: 86,
            color: ink,
          ),
        ),
        const SizedBox(height: 32),
        Heading(
          rescue
              ? 'Tu cuidado merece\nuna comunidad.'
              : 'Pequeños pasos.\nGrandes historias.',
          rescue
              ? 'Completa tu perfil y envía tus documentos para solicitar la verificación como rescatista.'
              : 'Crea tu cuenta para ser parte de Dopmi y preparar tu perfil.',
          eyebrow: 'TU PRIMER PASO',
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.mail_outline, color: purple),
          title: Text('Un correo, una cuenta'),
          subtitle: Text('Confirma tu correo para cuidar tu acceso.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.swap_horiz_rounded, color: purple),
          title: Text('Ayuda a tu manera'),
          subtitle: Text('Alterna entre donante/adoptante y rescatista.'),
        ),
        const SizedBox(height: 24),
        ActionButton(
          'Crear mi cuenta',
          sunny: true,
          onPressed: () => context.push('/signup?intent=$intent'),
        ),
        TextButton(
          onPressed: () => context.push('/login'),
          child: const Text('Ya tengo cuenta'),
        ),
      ],
    );
  }
}
