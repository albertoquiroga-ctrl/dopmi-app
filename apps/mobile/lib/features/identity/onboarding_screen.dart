import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';

String safeIntent(String? intent) =>
    ['adopt', 'donate', 'rescue'].contains(intent) ? intent! : 'adopt';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String intent = 'adopt';
  @override
  Widget build(BuildContext context) => PageFrame(
    back: false,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/welcome-pets.png',
          height: 240,
          fit: BoxFit.cover,
          semanticLabel: 'Un gato y un perro descansan juntos',
        ),
      ),
      const SizedBox(height: 24),
      const Heading(
        'Una nueva historia\nempieza contigo.',
        'Cada forma de ayudar cuenta. ¿Cómo quieres empezar?',
        eyebrow: 'BIENVENIDO A DOPMI',
      ),
      for (final option in const [
        (
          'adopt',
          Icons.pets_outlined,
          'Quiero adoptar',
          'Conocer a mi próximo compañero.',
        ),
        (
          'donate',
          Icons.favorite_border_rounded,
          'Quiero ayudar',
          'Acompañar a quienes rescatan.',
        ),
        (
          'rescue',
          Icons.volunteer_activism_outlined,
          'Soy rescatista',
          'Crear mi perfil y contar mi historia.',
        ),
      ]) ...[
        Semantics(
          selected: intent == option.$1,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: intent == option.$1 ? const Color(0xffeee7fc) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: intent == option.$1 ? purple : const Color(0xffded8ce),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => intent = option.$1),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(option.$2, color: purple),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.$3,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(option.$4),
                        ],
                      ),
                    ),
                    if (intent == option.$1)
                      const Icon(Icons.check_circle, color: purple),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 8),
      ActionButton(
        'Comenzar',
        sunny: true,
        onPressed: () => context.push('/onboarding?intent=$intent'),
      ),
      TextButton(
        onPressed: () => context.push('/login'),
        child: const Text('Ya tengo cuenta · Iniciar sesión'),
      ),
      const Text(
        'Puedes cambiar de experiencia desde tu perfil.',
        textAlign: TextAlign.center,
      ),
    ],
  );
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
              ? 'Empieza con un perfil que te represente. La verificación de rescatistas llegará en la siguiente etapa.'
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
