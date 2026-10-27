import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';
import '../../core/reference_focus_outline.dart';

/// Private owner status: server state is preserved while matching f693's card.
class RescuerVerificationCard extends StatelessWidget {
  const RescuerVerificationCard({
    super.key,
    required this.status,
    required this.onPressed,
  });
  final String? status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'approved';
    final review = status == 'submitted';
    final correction = ['changes_requested', 'rejected'].contains(status);
    final initial = status == null || ['draft', 'not_started'].contains(status);
    final title = approved
        ? 'Cuenta verificada'
        : review
        ? 'Verificación en proceso'
        : correction
        ? 'Revisa tu información'
        : initial
        ? 'Verifica tu cuenta'
        : 'Verificación no disponible';
    return ReferenceFocusOutline(
      radius: 24,
      child: Material(
        color: DopmiTokens.ink,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          splashFactory: NoSplash.splashFactory,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: DopmiTokens.bodyFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: approved
                          ? DopmiTokens.sky
                          : const Color(0xfffdf6f1),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                ExcludeSemantics(
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: approved
                          ? DopmiTokens.sky
                          : DopmiTokens.saffronSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SvgPicture.asset(
                      'assets/profile/${review ? 'icon-clock' : 'icon-shield'}.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        DopmiTokens.ink,
                        BlendMode.srcIn,
                      ),
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
