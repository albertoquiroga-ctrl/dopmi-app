import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RescuerVerificationCard extends StatefulWidget {
  const RescuerVerificationCard({
    super.key,
    required this.status,
    required this.onPressed,
  });
  final String? status;
  final VoidCallback onPressed;
  @override
  State<RescuerVerificationCard> createState() =>
      _RescuerVerificationCardState();
}

class _RescuerVerificationCardState extends State<RescuerVerificationCard> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final approved = widget.status == 'approved';
    final review = widget.status == 'submitted';
    final correction = [
      'changes_requested',
      'rejected',
    ].contains(widget.status);
    final title = approved
        ? 'Cuenta verificada'
        : correction
        ? 'Corrige tu verificación'
        : review
        ? 'Verificación en proceso'
        : 'Verifícate para recibir donaciones';
    final subtitle = approved
        ? 'Tu expediente de verificación está aprobado'
        : correction
        ? 'Hay datos que debes corregir para continuar'
        : review
        ? 'Te avisaremos cuando termine la revisión'
        : 'Presenta tu expediente para revisión';
    return Semantics(
      container: true,
      button: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.ease,
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: approved
                ? const Color(0x477841f2)
                : hovered
                ? const Color(0xffd8d2ca)
                : const Color(0xffe6e2dd),
          ),
          color: approved ? null : Colors.white,
          gradient: approved
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xfff7f2ff), Colors.white],
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: widget.onPressed,
            onHover: (value) => setState(() => hovered = value),
            borderRadius: BorderRadius.circular(20),
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x1f7841f2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SvgPicture.asset(
                        'assets/profile/${approved ? 'icon-verified' : 'icon-shield'}.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xff7841f2),
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
                          title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff15110d),
                            letterSpacing: 0,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xff554e48),
                            letterSpacing: 0,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: SvgPicture.asset(
                      'assets/profile/icon-chevron-right.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Color(0xff554e48),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
