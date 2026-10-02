import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../../core/design_tokens.dart';
import 'auth_ui.dart';
import 'identity_controller.dart';
import 'identity_repository.dart';
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
              'Tu nuevo mejor amigo ya te espera.',
              'Descubre mascotas que buscan un hogar y conoce su historia.',
              'Continuar',
            ),
            (
              'Conoce a quien cuida cada historia.',
              'Revisa salud y convivencia, conoce al rescatista y escríbele directo.',
              'Quiero adoptar',
            ),
          ];
    final slide = slides[step];
    if (rescue) {
      return PopScope(
        canPop: step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back();
        },
        child: RescuerIntroduction(
          step: step,
          title: slide.$1,
          description: slide.$2,
          cta: slide.$3,
          onBack: back,
          onNext: () {
            if (step == slides.length - 1) {
              context.push('/start?intent=${widget.intent}');
            } else {
              setState(() => step++);
            }
          },
        ),
      );
    }
    if (!rescue && !donate) {
      return PopScope(
        canPop: step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back();
        },
        child: AdoptionIntroduction(
          step: step,
          title: slide.$1,
          description: slide.$2,
          cta: slide.$3,
          onBack: back,
          onNext: () {
            if (step == slides.length - 1) {
              context.push('/start?intent=${widget.intent}');
            } else {
              setState(() => step++);
            }
          },
        ),
      );
    }
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
            OnboardingEntrance(
              key: ValueKey('${widget.intent}:$step'),
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
                          ?.copyWith(
                            fontSize: 26,
                            fontVariations: DopmiTokens.display26Variations,
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  OnboardingArt(intent: widget.intent, step: step),
                  const SizedBox(height: 22),
                ],
              ),
            ),
            Semantics(
              label: 'Paso ${step + 1} de ${slides.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < slides.length; index++)
                    AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      curve: Curves.ease,
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
    return Scaffold(
      backgroundColor: ink,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 393),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: Image.asset(
                  intent == 'rescue'
                      ? 'assets/onboarding/account-rescue.jpg'
                      : 'assets/welcome-pets.png',
                  fit: BoxFit.cover,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xc715110d),
                      Color(0x6b15110d),
                      Color(0x8c15110d),
                      Color(0xe015110d),
                    ],
                    stops: [0, .34, .58, 1],
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Volver',
                                    onPressed: () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/welcome');
                                      }
                                    },
                                    style: IconButton.styleFrom(
                                      fixedSize: const Size(40, 40),
                                      padding: EdgeInsets.zero,
                                      splashFactory: NoSplash.splashFactory,
                                      highlightColor: Colors.transparent,
                                    ),
                                    icon: SvgPicture.asset(
                                      'assets/profile/back.svg',
                                      width: 24,
                                      height: 24,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xf0ffffff),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const SizedBox(
                                      height: 36,
                                      child: Brand(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    24,
                                    8,
                                    20,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Semantics(
                                        header: true,
                                        child: Text(
                                          copy.$1,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineLarge!
                                              .copyWith(
                                                color: Colors.white,
                                                letterSpacing: -.64,
                                                shadows: const [
                                                  Shadow(
                                                    color: Color(0x59100000),
                                                    offset: Offset(0, 1),
                                                    blurRadius: 2,
                                                  ),
                                                ],
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        copy.$2,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          letterSpacing: 0,
                                          color: Color(0xf2ffffff),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ExcludeSemantics(
                                        child: SvgPicture.asset(
                                          'assets/onboarding/account-paw.svg',
                                          width: 28,
                                          height: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  22,
                                  20,
                                  20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x4715110d),
                                      offset: Offset(0, 12),
                                      blurRadius: 32,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: ink,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(52),
                                        shape: const StadiumBorder(),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      onPressed: () => context.push(
                                        '/signup?intent=$intent',
                                      ),
                                      child: const Text('Crea una cuenta'),
                                    ),
                                    const SizedBox(height: 14),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: ink,
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      onPressed: () => context.push('/login'),
                                      child: const Text('Inicia sesión'),
                                    ),
                                    const AccountSocialActions(),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

/// Match onb-in: 450ms, cubic-bezier(.22,1,.36,1), opacity and 10px rise.
class OnboardingEntrance extends StatelessWidget {
  const OnboardingEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: const Cubic(.22, 1, .36, 1),
      child: child,
      builder: (_, value, content) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: content,
        ),
      ),
    );
  }
}

/// Adopter layout: art fills the upper region; copy stays above dots and CTA.
class AdoptionIntroduction extends StatelessWidget {
  const AdoptionIntroduction({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.cta,
    required this.onBack,
    required this.onNext,
  });
  final int step;
  final String title, description, cta;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final scaler = MediaQuery.textScalerOf(context);
          final width = math.min(393.0, box.maxWidth) - 40;
          final copyWidth = math.min(width, scaler.scale(321.74));
          const titleStyle = TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 28,
            fontVariations: DopmiTokens.display28Variations,
            height: 1.12,
            letterSpacing: -.56,
            fontWeight: FontWeight.w600,
            color: ink,
          );
          const bodyStyle = TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            height: 1.45,
            letterSpacing: 0,
            color: muted,
          );
          const noteStyle = TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.4,
            letterSpacing: 0,
            color: muted,
          );
          const note =
              'Con tu cuenta guardas favoritos y escribes a rescatistas.';
          double height(String text, TextStyle style, double maxWidth) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout(maxWidth: math.max(1, maxWidth));
            final result = painter.height;
            painter.dispose();
            return result;
          }

          final copyHeight =
              height(
                title,
                titleStyle,
                math.min(copyWidth, scaler.scale(300.38)),
              ) +
              8 +
              height(description, bodyStyle, copyWidth) +
              (step == 1
                  ? 8 +
                        height(
                          note,
                          noteStyle,
                          math.min(width, scaler.scale(257.39)),
                        )
                  : 0);
          final buttonHeight = math.max(
            52.0,
            height(
                  cta,
                  const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    height: 1.2,
                  ),
                  width - 32,
                ) +
                22,
          );
          // Extra header row at large text is measured by the wrapping layout;
          // scrolling permits it without clipping the art, copy or controls.
          final bodyHeight = math.max(
            248 + copyHeight + 40,
            box.maxHeight - 24 - 44 - 4 - 16 - buttonHeight - 20,
          );
          final artHeight = bodyHeight - 8 - copyHeight - 24 - 16;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: math.min(393.0, box.maxWidth),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IntroductionHeader(onBack: onBack),
                      const SizedBox(height: 4),
                      OnboardingEntrance(
                        key: ValueKey('adopt:$step'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(minHeight: artHeight),
                              child: Center(
                                heightFactor: 1,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: step == 0 ? copyWidth : width,
                                    child: OnboardingArt(
                                      intent: 'adopt',
                                      step: step,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              header: true,
                              child: SizedBox(
                                width: math.min(
                                  copyWidth,
                                  scaler.scale(300.38),
                                ),
                                child: Text(title, style: titleStyle),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: copyWidth,
                              child: Text(description, style: bodyStyle),
                            ),
                            if (step == 1) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: math.min(width, scaler.scale(257.39)),
                                child: Text(note, style: noteStyle),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Semantics(
                              label: 'Paso ${step + 1} de 2',
                              child: SizedBox(
                                width: step == 0 ? copyWidth : width,
                                height: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (var index = 0; index < 2; index++)
                                      AnimatedContainer(
                                        duration:
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            )
                                            ? Duration.zero
                                            : const Duration(milliseconds: 350),
                                        curve: Curves.ease,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        width: index == step ? 24 : 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: index == step
                                              ? yellow
                                              : const Color(0xffe5e0d8),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: ink,
                          foregroundColor: Colors.white,
                          minimumSize: Size.fromHeight(buttonHeight),
                          shape: const StadiumBorder(),
                          splashFactory: NoSplash.splashFactory,
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(cta),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _IntroductionHeader extends StatelessWidget {
  const _IntroductionHeader({required this.onBack, this.headerHeight = 44});
  final VoidCallback onBack;
  final double headerHeight;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    alignment: WrapAlignment.spaceBetween,
    children: [
      Transform.translate(
        offset: const Offset(-10, 0),
        child: SizedBox(
          height: headerHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Volver',
                onPressed: onBack,
                style: IconButton.styleFrom(
                  minimumSize: Size(40, headerHeight),
                  fixedSize: Size(40, headerHeight),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                ),
                icon: SvgPicture.asset(
                  'assets/profile/back.svg',
                  width: 24,
                  height: 24,
                ),
              ),
              const SizedBox(width: 2),
              const Brand(),
            ],
          ),
        ),
      ),
      TextButton(
        onPressed: () => context.push('/login'),
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: Size(0, headerHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          splashFactory: NoSplash.splashFactory,
          padding: EdgeInsets.symmetric(
            horizontal: headerHeight == 40 ? 0 : 4,
            vertical: 8,
          ),
        ),
        child: const Text(
          'Ya tengo cuenta',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            letterSpacing: 0,
          ),
        ),
      ),
    ],
  );
}

class RescuerIntroduction extends StatelessWidget {
  const RescuerIntroduction({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.cta,
    required this.onBack,
    required this.onNext,
  });
  final int step;
  final String title, description, cta;
  final VoidCallback onBack, onNext;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 393),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _IntroductionHeader(onBack: onBack, headerHeight: 40),
                          const SizedBox(height: 8),
                          OnboardingEntrance(
                            key: ValueKey('rescue:$step'),
                            child: Column(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.textScalerOf(context)
                                        .scale(314.03),
                                  ),
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Fraunces',
                                        fontSize: 26,
                                        fontVariations:
                                            DopmiTokens.display26Variations,
                                        height: 1.15,
                                        letterSpacing: -.52,
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.textScalerOf(context)
                                        .scale(262.44),
                                  ),
                                  child: Text(
                                    description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      height: 1.5,
                                      letterSpacing: 0,
                                      color: muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                OnboardingArt(intent: 'rescue', step: step),
                                const SizedBox(height: 18),
                                Semantics(
                                  label: 'Paso ${step + 1} de 2',
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (var i = 0; i < 2; i++)
                                        AnimatedContainer(
                                          duration:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              )
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 350,
                                                ),
                                          curve: Curves.ease,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          width: i == step ? 24 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: i == step
                                                ? yellow
                                                : const Color(0xffe5e0d8),
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: ink,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            shape: const StadiumBorder(),
                            splashFactory: NoSplash.splashFactory,
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(cta),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Configured providers use the same repository and session listener as login.
/// Cancellation never opens the authenticated app or fabricates an identity.
class AccountSocialActions extends ConsumerStatefulWidget {
  const AccountSocialActions({super.key});
  @override
  ConsumerState<AccountSocialActions> createState() =>
      _AccountSocialActionsState();
}

class _AccountSocialActionsState extends ConsumerState<AccountSocialActions> {
  bool busy = false;
  String? error;

  Future<void> social(String provider) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(identityRepositoryProvider).oauth(provider);
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    if (!config.googleEnabled && !config.appleNativeAvailable) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        const SizedBox(height: 18),
        const Divider(height: 1, thickness: 1, color: DopmiTokens.line),
        const SizedBox(height: 16),
        const Text(
          'Continuar con',
          style: TextStyle(
            fontSize: 13,
            height: 1.3,
            letterSpacing: 0,
            color: muted,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            if (config.appleNativeAvailable) providerButton('apple', 'Apple'),
            if (config.googleEnabled) providerButton('google', 'Google'),
          ],
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              label: 'Abriendo inicio de sesión',
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DopmiTokens.danger),
              ),
            ),
          ),
      ],
    );
  }

  Widget providerButton(String provider, String label) => IconButton(
    tooltip: 'Continuar con $label',
    onPressed: busy ? null : () => social(provider),
    style: IconButton.styleFrom(
      fixedSize: const Size(52, 52),
      minimumSize: const Size(52, 52),
      padding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      foregroundColor: ink,
      side: const BorderSide(color: DopmiTokens.line),
      shape: const CircleBorder(),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    ),
    icon: SvgPicture.asset(
      'assets/onboarding/icon-$provider.svg',
      width: 22,
      height: 22,
    ),
  );
}
