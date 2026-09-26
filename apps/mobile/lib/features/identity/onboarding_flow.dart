import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'auth_ui.dart';
import 'onboarding_art.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.intent});
  final String intent;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  void back() {
    if (step > 0) {
      setState(() => step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rescue = widget.intent == 'rescue';
    final donate = widget.intent == 'donate';
    final slides = rescue
        ? const [
            (
              'Encontrarle hogar también es parte del rescate.',
              'Comparte la historia de una mascota y haz que llegue a las personas correctas.',
              'Continuar',
            ),
            (
              'Tú lo cuidas. Te ayudamos a cubrir lo que necesita.',
              'Verifica tu cuenta y solicita apoyo para reembolsar gastos ya pagados, con evidencia revisada y aprobada por DopMi.',
              'Empezar',
            ),
          ]
        : donate
        ? const [
            (
              'Quieres ayudar. Aquí sabes a quién.',
              'Apoya una necesidad concreta con gastos aprobados y sigue tu aportación.',
              'Continuar',
            ),
            (
              'Tu ayuda no se pierde de vista.',
              'La rescatista registra gastos pagados y DopMi revisa la evidencia antes de recibir aportaciones.',
              'Quiero ayudar',
            ),
          ]
        : const [
            (
              'Tu nuevo mejor amigo ya te está esperando.',
              'Descubre mascotas que buscan un hogar y conoce su historia.',
              'Continuar',
            ),
            (
              'Conoce a quien está detrás de cada historia.',
              'Revisa la información de la mascota, conoce al rescatista y contacta directamente para continuar.',
              'Quiero adoptar',
            ),
          ];
    final slide = slides[step];
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: AuthFrame(
        onBack: back,
        accountLink: true,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ActionButton(
              slide.$3,
              onPressed: () {
                if (step == slides.length - 1) {
                  context.push('/start?intent=${widget.intent}');
                } else {
                  setState(() => step++);
                }
              },
            ),
            if (step == 1 && !rescue) ...[
              const SizedBox(height: 10),
              Text(
                donate ? 'Con tu cuenta sigues cada caso que apoyas.' : 'Con tu cuenta guardas tus favoritos y escribes a rescatistas.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ],
        ),
        child: Column(
          children: [
            if (donate && step == 0) ...[
              const Chip(label: Text('Apoyo puntual')),
              const SizedBox(height: 10),
            ],
            Semantics(
              header: true,
              child: Text(
                slide.$1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: 26),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              slide.$2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.5, color: muted),
            ),
            const SizedBox(height: 22),
            OnboardingArt(intent: widget.intent, step: step),
            const SizedBox(height: 22),
            Semantics(
              label: 'Paso ${step + 1} de ${slides.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < slides.length; index++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == step ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == step ? yellow : const Color(0xffe5e0d8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountStartScreen extends StatelessWidget {
  const AccountStartScreen({super.key, required this.intent});
  final String intent;
  @override
  Widget build(BuildContext context) {
    final copy = intent == 'rescue'
        ? (
            'Crea tu espacio para publicar',
            'Verifica tu cuenta, publica casos y comparte evidencia con transparencia.',
          )
        : intent == 'donate'
        ? (
            'Casi listo para apoyar',
            'Elige gastos aprobados y sigue el impacto de cada aportación.',
          )
        : (
            'Casi listo para encontrar hogar',
            'Guarda favoritos, revisa historias y contacta al rescatista cuando quieras.',
          );
    return AuthFrame(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionButton(
            'Crear cuenta',
            onPressed: () => context.push('/signup?intent=$intent'),
          ),
          TextButton(
            onPressed: () => context.push('/login'),
            child: const Text('¿Ya tienes cuenta? Inicia sesión'),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Column(
          children: [
            AuthHeading(copy.$1, copy.$2),
            const Icon(Icons.pets_outlined, color: yellow, size: 28),
          ],
        ),
      ),
    );
  }
}
