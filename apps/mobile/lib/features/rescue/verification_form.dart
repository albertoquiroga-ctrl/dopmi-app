import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerificationFormFrame extends StatelessWidget {
  const VerificationFormFrame({
    super.key,
    required this.children,
    this.onBack,
    this.title = 'Formulario de verificación',
    this.rescuer = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 20, 16, 32),
  });
  final List<Widget> children;
  final String title;
  final bool rescuer;
  final EdgeInsets bodyPadding;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: rescuer
                      ? const Color(0xffe3e4ed)
                      : const Color(0xffe6e2dd),
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('verification-header-back'),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onPressed: onBack,
                      tooltip: 'Volver',
                      icon: Transform.translate(
                        offset: const Offset(-4, -.5),
                        child: SvgPicture.asset(
                          'assets/profile/back.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          height: 1.25,
                          letterSpacing: -.36,
                          fontWeight: FontWeight.w700,
                          color: rescuer
                              ? const Color(0xff151423)
                              : const Color(0xff15110d),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(18) > 24
                          ? 0
                          : 48,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: const ValueKey('verification-form-body'),
              padding: bodyPadding,
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}

class VerificationSectionTitle extends StatelessWidget {
  const VerificationSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Color(0xff151423),
        ),
      ),
    ),
  );
}

class VerificationProgress extends StatelessWidget {
  const VerificationProgress({
    super.key,
    required this.captured,
    required this.total,
  });
  final int captured, total;
  @override
  Widget build(BuildContext context) {
    const heading = Text(
      'Progreso del formulario',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 17 / 14,
        color: Color(0xff4f4e5c),
      ),
    );
    final status = Text(
      captured == total ? 'Completo' : 'Incompleto',
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 17 / 14,
        fontWeight: FontWeight.w700,
        color: Color(0xff151423),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe3e4ed)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.textScalerOf(context).scale(14) > 21)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 12), status],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: heading),
                const SizedBox(width: 12),
                status,
              ],
            ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: captured / total,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            color: const Color(0xff7841f2),
            backgroundColor: const Color(0xffefede8),
            semanticsLabel:
                'Progreso del formulario: $captured de $total requisitos capturados',
          ),
        ],
      ),
    );
  }
}
