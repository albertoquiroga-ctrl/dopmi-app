import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';
import '../../core/donor_canvas.dart';
import '../../core/heading_layout.dart';

export 'onboarding_flow.dart';

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
      body: DonorCanvas(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final bodyWidth = math.max(0.0, constraints.maxWidth - 56);
              double textHeight(
                String text,
                TextStyle style,
                double width, {
                bool cssLeading = false,
              }) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textScaler: scaler,
                  textDirection: Directionality.of(context),
                )..layout(maxWidth: math.max(1, width));
                final height = cssLeading
                    ? painter.computeLineMetrics().length *
                          scaler.scale(style.fontSize!) *
                          (style.height ?? 1)
                    : painter.height;
                painter.dispose();
                return height;
              }

              double wordHeight(
                String text,
                TextStyle style,
                double width, {
                bool cssLeading = false,
              }) => textHeight(
                text,
                wordSafeHeadingStyle(context, text, style, width),
                width,
                cssLeading: cssLeading,
              );
              final optionLabelWidth = math.min(
                scaler.scale(126),
                (math.min(280, bodyWidth) - 16) / 2,
              );

              const labelStyle = TextStyle(
                fontFamily: DopmiTokens.bodyFont,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w500,
              );
              final labelsHeight = options
                  .map(
                    (option) => wordHeight(
                      option.$2,
                      labelStyle,
                      math.min(
                        scaler.scale(126),
                        (math.min(280, bodyWidth) - 16) / 2,
                      ),
                    ),
                  )
                  .reduce(math.max);
              final headerHeight =
                  36 +
                  28 +
                  40 +
                  math.max(118, 92 + 10 + labelsHeight) +
                  wordHeight(
                    '¿Cómo quieres ayudar?',
                    const TextStyle(
                      fontFamily: DopmiTokens.displayFont,
                      fontSize: 28,
                      fontVariations: DopmiTokens.display28Variations,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                    math.min(240, bodyWidth),
                  );
              const footerCopy =
                  'Puedes cambiar tu selección en cualquier momento desde la configuración de tu perfil.';
              final buttonHeight = math.max(
                52.0,
                textHeight(
                      'Continuar',
                      const TextStyle(
                        fontFamily: DopmiTokens.bodyFont,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                      math.max(1, bodyWidth - 32),
                    ) +
                    22,
              );
              final footerHeight =
                  buttonHeight +
                  14 +
                  textHeight(
                    footerCopy,
                    const TextStyle(
                      fontFamily: DopmiTokens.bodyFont,
                      fontSize: 11,
                      height: 1.45,
                    ),
                    math.min(bodyWidth, scaler.scale(235.94)),
                  );
              final summaryRequired =
                  44 +
                  10 +
                  wordHeight(
                    selected?.$2 ?? '',
                    const TextStyle(
                      fontFamily: DopmiTokens.displayFont,
                      fontSize: 28,
                      fontVariations: DopmiTokens.display28Variations,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                    bodyWidth,
                  ) +
                  textHeight(
                    selected?.$3 ?? '',
                    const TextStyle(
                      fontFamily: DopmiTokens.bodyFont,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    math.min(bodyWidth, scaler.scale(247.3)),
                  );
              final availableSummary =
                  constraints.maxHeight - 60 - headerHeight - footerHeight;
              final summaryHeight = math.max(
                summaryRequired,
                math.min(280.0, availableSummary),
              );
              final footerGap = math.max(0.0, availableSummary - summaryHeight);
              final emptyHeaderHeight =
                  36 +
                  12 +
                  wordHeight(
                    'Bienvenido a DopMi',
                    const TextStyle(
                      fontFamily: DopmiTokens.displayFont,
                      fontSize: 28,
                      fontVariations: DopmiTokens.display28Variations,
                      height: 1.1,
                      letterSpacing: -.56,
                      fontWeight: FontWeight.w600,
                    ),
                    math.max(1, bodyWidth - 16),
                    cssLeading: true,
                  ) +
                  textHeight(
                    'Ayuda a mascotas rescatadas de forma segura, simple y transparente.',
                    const TextStyle(
                      fontFamily: DopmiTokens.bodyFont,
                      fontSize: 13,
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                    math.min(scaler.scale(246.04), math.max(1, bodyWidth - 16)),
                    cssLeading: true,
                  );
              final emptyPromptRequired =
                  48 +
                  wordHeight(
                    '¿Cómo quieres ayudar hoy?',
                    const TextStyle(
                      fontFamily: DopmiTokens.displayFont,
                      fontSize: 28,
                      fontVariations: DopmiTokens.display28Variations,
                      height: 1.1,
                      letterSpacing: -.56,
                      fontWeight: FontWeight.w600,
                    ),
                    math.min(256.9, bodyWidth),
                  );
              final emptyLabelsHeight = options
                  .map(
                    (option) => wordHeight(
                      option.$2,
                      labelStyle,
                      math.min(
                        scaler.scale(126),
                        (math.min(280, bodyWidth) - 16) / 2,
                      ),
                      cssLeading: true,
                    ),
                  )
                  .reduce(math.max);
              final emptyPromptHeight = math.max(
                emptyPromptRequired,
                constraints.maxHeight -
                    60 -
                    36 -
                    emptyHeaderHeight -
                    math.max(118, 92 + 10 + emptyLabelsHeight) -
                    12,
              );
              final selectedPromptHeight = wordHeight(
                '¿Cómo quieres ayudar?',
                const TextStyle(
                  fontFamily: DopmiTokens.displayFont,
                  fontSize: 28,
                  fontVariations: DopmiTokens.display28Variations,
                  height: 1.1,
                  letterSpacing: -.56,
                  fontWeight: FontWeight.w600,
                ),
                math.min(240, bodyWidth),
              );
              final welcomeHeader = AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 550),
                curve: const Cubic(.22, 1, .36, 1),
                transform: Matrix4.translationValues(
                  0,
                  selected == null ? 0 : -12,
                  0,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 36),
                      Text(
                        'Bienvenido a DopMi',
                        textAlign: TextAlign.center,
                        style: wordSafeHeadingStyle(
                          context,
                          'Bienvenido a DopMi',
                          const TextStyle(
                            fontFamily: DopmiTokens.displayFont,
                            fontSize: 28,
                            fontVariations: DopmiTokens.display28Variations,
                            height: 1.1,
                            letterSpacing: -.56,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                          math.max(1, bodyWidth - 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: scaler.scale(246.04),
                          ),
                          child: const Text(
                            'Ayuda a mascotas rescatadas de forma segura, simple y transparente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: DopmiTokens.bodyFont,
                              fontSize: 13,
                              height: 1.5,
                              letterSpacing: 0,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              return SingleChildScrollView(
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
                        if (MediaQuery.disableAnimationsOf(context))
                          selected == null
                              ? welcomeHeader
                              : const SizedBox(
                                  width: double.infinity,
                                  height: 28,
                                )
                        else
                          AnimatedCrossFade(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 550),
                            firstCurve: const Interval(
                              0,
                              400 / 550,
                              curve: Curves.ease,
                            ),
                            secondCurve: const Interval(
                              0,
                              400 / 550,
                              curve: Curves.ease,
                            ),
                            sizeCurve: const Cubic(.22, 1, .36, 1),
                            alignment: Alignment.topCenter,
                            crossFadeState: selected == null
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: welcomeHeader,
                            secondChild: const SizedBox(
                              width: double.infinity,
                              height: 28,
                            ),
                          ),
                        AnimatedContainer(
                          key: const ValueKey('welcome-prompt-region'),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 550),
                          curve: const Cubic(.22, 1, .36, 1),
                          height: selected == null
                              ? emptyPromptHeight
                              : selectedPromptHeight,
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: selected == null ? 256.9 : 240,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 450),
                              curve: const Cubic(.22, 1, .36, 1),
                              textAlign: TextAlign.center,
                              style: wordSafeHeadingStyle(
                                context,
                                selected == null
                                    ? '¿Cómo quieres ayudar hoy?'
                                    : '¿Cómo quieres ayudar?',
                                TextStyle(
                                  fontFamily: DopmiTokens.displayFont,
                                  fontSize: 28,
                                  fontVariations:
                                      DopmiTokens.display28Variations,
                                  letterSpacing: -.56,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: selected == null
                                      ? DopmiTokens.orange
                                      : ink,
                                ),
                                math.min(
                                  selected == null ? 256.9 : 240,
                                  bodyWidth,
                                ),
                              ),
                              child: Text(
                                selected == null
                                    ? '¿Cómo quieres ayudar hoy?'
                                    : '¿Cómo quieres ayudar?',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: selected == null ? 8 : 40),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final option in options) ...[
                                  if (option != options.first)
                                    const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 0),
                                      child: Semantics(
                                        label: option.$2,
                                        checked: intent == option.$1,
                                        inMutuallyExclusiveGroup: true,
                                        button: true,
                                        onTap: () =>
                                            setState(() => intent = option.$1),
                                        child: ExcludeSemantics(
                                          child: InkWell(
                                            splashFactory:
                                                NoSplash.splashFactory,
                                            highlightColor: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                            onTap: () => setState(
                                              () => intent = option.$1,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  key: ValueKey(
                                                    'welcome-orb-${option.$1}',
                                                  ),
                                                  width: 92,
                                                  height: 92,
                                                  child: AnimatedContainer(
                                                    duration:
                                                        MediaQuery.disableAnimationsOf(
                                                          context,
                                                        )
                                                        ? Duration.zero
                                                        : const Duration(
                                                            milliseconds: 250,
                                                          ),
                                                    curve: Curves.ease,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white,
                                                      gradient:
                                                          intent == null ||
                                                              intent ==
                                                                  option.$1
                                                          ? const LinearGradient(
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                              colors: [
                                                                DopmiTokens
                                                                    .orange,
                                                                DopmiTokens.sky,
                                                                DopmiTokens
                                                                    .saffronSoft,
                                                              ],
                                                              stops: [
                                                                0,
                                                                .52,
                                                                1,
                                                              ],
                                                            )
                                                          : null,
                                                      border:
                                                          intent != null &&
                                                              intent !=
                                                                  option.$1
                                                          ? Border.all(
                                                              color: DopmiTokens
                                                                  .line,
                                                              width: 1.5,
                                                            )
                                                          : null,
                                                      boxShadow:
                                                          intent == null ||
                                                              intent ==
                                                                  option.$1
                                                          ? const [
                                                              BoxShadow(
                                                                color: Color(
                                                                  0x57eb6425,
                                                                ),
                                                                blurRadius: 10,
                                                              ),
                                                              BoxShadow(
                                                                color: Color(
                                                                  0x47cbe8fa,
                                                                ),
                                                                blurRadius: 16,
                                                              ),
                                                              BoxShadow(
                                                                color: Color(
                                                                  0x38fef3d4,
                                                                ),
                                                                blurRadius: 22,
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(2),
                                                    child: Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Colors.white,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      alignment:
                                                          Alignment.center,
                                                      child: SvgPicture.asset(
                                                        option.$1 == 'rescue'
                                                            ? 'assets/profile/notif-pet.svg'
                                                            : 'assets/navigation/choice-${option.$1}.svg',
                                                        width: 32,
                                                        height: 32,
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                              intent == null ||
                                                                      intent ==
                                                                          option
                                                                              .$1
                                                                  ? DopmiTokens
                                                                        .orange
                                                                  : DopmiTokens
                                                                        .navigationInactive,
                                                              BlendMode.srcIn,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                AnimatedDefaultTextStyle(
                                                  duration:
                                                      MediaQuery.disableAnimationsOf(
                                                        context,
                                                      )
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 250,
                                                        ),
                                                  curve: Curves.ease,
                                                  textAlign: TextAlign.center,
                                                  style: wordSafeHeadingStyle(
                                                    context,
                                                    option.$2,
                                                    TextStyle(
                                                      fontFamily:
                                                          DopmiTokens.bodyFont,
                                                      fontSize: 15,
                                                      height: 1.35,
                                                      color:
                                                          intent == option.$1 &&
                                                              option.$1 !=
                                                                  'adopt'
                                                          ? ink
                                                          : DopmiTokens
                                                                .navigationInactive,
                                                      fontWeight:
                                                          intent == option.$1 &&
                                                              option.$1 !=
                                                                  'adopt'
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                    ),
                                                    optionLabelWidth,
                                                  ),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxWidth:
                                                          MediaQuery.textScalerOf(
                                                            context,
                                                          ).scale(126),
                                                    ),
                                                    child: Text(option.$2),
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
                            ),
                          ),
                        ),
                        if (selected != null) ...[
                          WelcomeSelectionEntrance(
                            child: Container(
                              key: const ValueKey('welcome-summary-region'),
                              height: summaryHeight,
                              padding: const EdgeInsets.only(
                                top: 28,
                                bottom: 16,
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    selected.$2,
                                    textAlign: TextAlign.center,
                                    style: wordSafeHeadingStyle(
                                      context,
                                      selected.$2,
                                      const TextStyle(
                                        fontFamily: DopmiTokens.displayFont,
                                        fontSize: 28,
                                        fontVariations:
                                            DopmiTokens.display28Variations,
                                        color: DopmiTokens.orange,
                                        height: 1.1,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      bodyWidth,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.textScalerOf(
                                          context,
                                        ).scale(247.3),
                                      ),
                                      child: Text(
                                        selected.$3,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          letterSpacing: 0,
                                          height: 1.5,
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: footerGap),
                          WelcomeSelectionEntrance(
                            footer: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton(
                                  style:
                                      FilledButton.styleFrom(
                                        backgroundColor:
                                            DopmiTokens.orangeButton,
                                        splashFactory: NoSplash.splashFactory,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size.fromHeight(
                                          buttonHeight,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 11,
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: DopmiTokens.bodyFont,
                                          fontSize: 16,
                                          height: 1.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ).copyWith(
                                        overlayColor:
                                            WidgetStateProperty.resolveWith<
                                              Color?
                                            >(
                                              (states) =>
                                                  states.contains(
                                                    WidgetState.pressed,
                                                  )
                                                  ? Colors.transparent
                                                  : null,
                                            ),
                                      ),
                                  onPressed: () => context.push(
                                    '/onboarding?intent=$intent',
                                  ),
                                  child: const Text('Continuar'),
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: scaler.scale(235.94),
                                    ),
                                    child: const Text(
                                      footerCopy,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: DopmiTokens.bodyFont,
                                        fontSize: 11,
                                        letterSpacing: 0,
                                        height: 1.45,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Reference summary and footer enter with independent delays and translations.
class WelcomeSelectionEntrance extends StatefulWidget {
  const WelcomeSelectionEntrance({
    super.key,
    required this.child,
    this.footer = false,
  });
  final bool footer;
  final Widget child;
  @override
  State<WelcomeSelectionEntrance> createState() =>
      _WelcomeSelectionEntranceState();
}

class _WelcomeSelectionEntranceState extends State<WelcomeSelectionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.footer ? 620 : 630),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else if (controller.status == AnimationStatus.dismissed) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (_, child) {
      final total = widget.footer ? 620.0 : 630.0;
      final opacity = Interval(
        (widget.footer ? 180 : 120) / total,
        (widget.footer ? 580 : 570) / total,
        curve: Curves.ease,
      ).transform(controller.value);
      final position = Interval(
        (widget.footer ? 120 : 80) / total,
        1,
        curve: const Cubic(.22, 1, .36, 1),
      ).transform(controller.value);
      return Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, (widget.footer ? 16 : 18) * (1 - position)),
          child: child,
        ),
      );
    },
  );
}
