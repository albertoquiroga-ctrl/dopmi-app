import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';

import '../../core/ui.dart';

/// Shared access layout from Irlanda's auth-gate, with native scrolling,
/// autofill, keyboard avoidance and accessible controls.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.child,
    this.footer,
    this.back = true,
    this.onBack,
    this.accountLink = false,
    this.sheet = false,
    this.intent = 'adopt',
    this.sheetBottomPadding = 18,
  });
  final Widget child;
  final Widget? footer;
  final bool back, accountLink, sheet;
  final String intent;
  final double sheetBottomPadding;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: sheet
            ? theme.inputDecorationTheme.copyWith(
                filled: true,
                fillColor: WidgetStateColor.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? Colors.white
                      : const Color(0xfffaf8f5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                constraints: const BoxConstraints(minHeight: 48),
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.2,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: const AuthIdleBorder(),
                focusedBorder: const AuthFocusBorder(),
              )
            : theme.inputDecorationTheme,

        colorScheme: theme.colorScheme.copyWith(
          primary: ink,
          onPrimary: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            disabledBackgroundColor: sheet ? const Color(0xffcfc8bf) : null,
            disabledForegroundColor: sheet ? Colors.white : null,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: ink),
        ),
      ),
      child: sheet
          ? _AuthSheet(
              intent: intent,
              back: back,
              onBack: onBack,
              bottomPadding: sheetBottomPadding,
              child: child,
            )
          : Scaffold(
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (back)
                                      IconButton(
                                        tooltip: 'Volver',
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                        ),
                                        onPressed:
                                            onBack ??
                                            () {
                                              if (context.canPop()) {
                                                context.pop();
                                              } else {
                                                context.go('/welcome');
                                              }
                                            },
                                      ),
                                    const Brand(),
                                    if (accountLink)
                                      TextButton(
                                        onPressed: () => context.push('/login'),
                                        child: const Text('Ya tengo cuenta'),
                                      ),
                                  ],
                                ),
                                SizedBox(height: accountLink ? 8 : 28),
                                child,
                              ],
                            ),
                            if (footer != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: footer!,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class AuthConsentRow extends StatelessWidget {
  const AuthConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  static const label =
      'Confirmo que tengo 18 años o más y acepto los Términos y el Aviso de privacidad.';

  @override
  Widget build(BuildContext context) {
    final toggle = onChanged == null ? null : () => onChanged!(!value);
    return Semantics(
      label: label,
      checked: value,
      enabled: onChanged != null,
      onTap: toggle,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: toggle,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: value,
                        onChanged: onChanged == null
                            ? null
                            : (next) => onChanged!(next ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.4,
                      letterSpacing: 0,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeading extends StatelessWidget {
  const AuthHeading(
    this.title,
    this.description, {
    super.key,
    this.sheet = false,
  });
  final String title, description;
  final bool sheet;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ConstrainedBox(
        constraints: BoxConstraints(
          // Source 14ch at Fraunces28; honor the user's text scale.
          maxWidth: sheet
              ? 262.836 * MediaQuery.textScalerOf(context).scale(28) / 28
              : double.infinity,
        ),
        child: Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: sheet
                ? Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontVariations: DopmiTokens.display28Variations,
                    letterSpacing: -.56,
                  )
                : Theme.of(context).textTheme.headlineLarge,
          ),
        ),
      ),
      SizedBox(height: sheet ? 6 : 8),
      ConstrainedBox(
        constraints: BoxConstraints(
          // Source 32ch at Inter14, measured in the rendered reference.
          maxWidth: sheet
              ? 282.625 * MediaQuery.textScalerOf(context).scale(14) / 14
              : double.infinity,
        ),
        child: Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sheet ? 14 : 13,
            height: 1.5,
            letterSpacing: 0,
            color: muted,
          ),
        ),
      ),
      SizedBox(height: sheet ? 16 : 22),
    ],
  );
}

/// Auth sheet stays bottom-aligned while content is short and scrolls within
/// the remaining height when the keyboard or enlarged text reduces space.
class _AuthSheet extends StatelessWidget {
  const _AuthSheet({
    required this.intent,
    required this.back,
    this.onBack,
    required this.child,
    required this.bottomPadding,
  });
  final String intent;
  final double bottomPadding;
  final bool back;
  final VoidCallback? onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: intent == 'rescue'
                      ? const [
                          Color.fromRGBO(40, 18, 72, .8),
                          Color.fromRGBO(21, 17, 13, .4),
                          Color.fromRGBO(21, 17, 13, .58),
                          Color.fromRGBO(21, 17, 13, .92),
                        ]
                      : const [
                          Color.fromRGBO(21, 17, 13, .72),
                          Color.fromRGBO(21, 17, 13, .35),
                          Color.fromRGBO(21, 17, 13, .55),
                          Color.fromRGBO(21, 17, 13, .92),
                        ],
                  stops: intent == 'rescue'
                      ? const [0, .3, .55, 1]
                      : const [0, .28, .52, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (back)
                          IconButton(
                            tooltip: 'Volver',
                            onPressed:
                                onBack ??
                                () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/welcome');
                                  }
                                },
                            style: IconButton.styleFrom(
                              fixedSize: const Size(40, 40),
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                            color: const Color.fromRGBO(255, 255, 255, .94),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const SizedBox(height: 36, child: Brand()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          key: const ValueKey('auth-form-sheet'),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(21, 17, 13, .28),
                                offset: Offset(0, 12),
                                blurRadius: 32,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                18,
                                22,
                                18,
                                bottomPadding,
                              ),
                              child: child,
                            ),
                          ),
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
    ),
  );
}

/// Source focus has an immediate 3px spread and no blur/transition.
/// Paint the ring outside the input border, excluding native validation text.
class AuthFocusBorder extends OutlineInputBorder {
  const AuthFocusBorder()
    : super(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: const BorderSide(color: yellow),
      );
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    final inner = borderRadius.toRRect(rect);
    canvas.drawDRRect(
      inner.inflate(3),
      inner,
      Paint()..color = const Color.fromRGBO(247, 203, 45, .22),
    );
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b;
}

class AuthIdleBorder extends OutlineInputBorder {
  const AuthIdleBorder()
    : super(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: const BorderSide(color: Color(0xffe8e2d9)),
      );
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b;
}

/// Source's auth-gate-alt; capabilities and actual authentication are supplied
/// by the form, so unsupported providers never become simulated entry points.
class AuthProviderIcons extends StatelessWidget {
  const AuthProviderIcons({
    super.key,
    required this.google,
    required this.apple,
    required this.busy,
    required this.onPick,
  });
  final bool google, apple, busy;
  final Future<void> Function(String) onPick;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      children: [
        const Divider(height: 1, thickness: 1, color: DopmiTokens.line),
        const SizedBox(height: 8),
        const Text(
          'Continuar con',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.3,
            letterSpacing: 0,
            color: muted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            if (apple) button('apple', 'Apple'),
            if (google) button('google', 'Google'),
          ],
        ),
      ],
    ),
  );
  Widget button(String provider, String name) => IconButton(
    tooltip: 'Continuar con $name',
    onPressed: busy ? null : () => onPick(provider),
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

/// Fits the 48px link target inside Source's 14px gap, 20.15px paragraph,
/// and 18px sheet padding. Large text falls back to an unconstrained Wrap.
class AuthSwitchFooter extends StatelessWidget {
  const AuthSwitchFooter({
    super.key,
    required this.signup,
    required this.busy,
    required this.intent,
  });
  final bool signup, busy;
  final String intent;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const labelStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        height: 1.55,
        letterSpacing: 0,
        color: muted,
      );
      const actionStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        height: 1.55,
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
      );
      final question = signup ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?';
      final action = signup ? 'Inicia sesión' : 'Crear cuenta';
      final scaler = MediaQuery.textScalerOf(context);
      double width(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final result = painter.width;
        painter.dispose();
        return result;
      }

      final actionWidth = width(action, actionStyle);
      final rowWidth =
          width(question, labelStyle) +
          4 +
          (actionWidth < 48 ? 48 : actionWidth);
      final label = Text(question, style: labelStyle);
      final button = TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: actionStyle,
        ),
        onPressed: busy
            ? null
            : () => context.push(
                '${signup ? '/login' : '/signup'}?intent=$intent',
              ),
        child: Text(action),
      );
      final lineHeight = scaler.scale(13) * 1.55;
      if (rowWidth <= box.maxWidth && lineHeight <= 48) {
        return SizedBox(
          key: const ValueKey('auth-switch-footer'),
          height: 14 + lineHeight + 18,
          child: Stack(
            children: [
              Positioned(
                top: 14 + (lineHeight - 48) / 2,
                left: 0,
                right: 0,
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [label, const SizedBox(width: 4), button],
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        key: const ValueKey('auth-switch-footer'),
        padding: const EdgeInsets.only(top: 14, bottom: 18),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [label, button],
        ),
      );
    },
  );
}
