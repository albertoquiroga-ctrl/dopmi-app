import '../../core/css_linear_gradient.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../rescue/rescue_repository.dart';
import 'rescuer_settings_details.dart';

class RescuerSettingsVerification extends ConsumerWidget {
  const RescuerSettingsVerification({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SettingsVerificationHeading(),
      const SizedBox(height: 10),
      LiveSection<Json>(
        tables: const ['dopmi_rescue_records'],
        load: () => ref.read(rescueRepositoryProvider).dashboard(),
        builder: (data, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsVerificationCard(
              status: data['verification_status'] as String?,
              onPressed: () => context.push('/rescue/new?kind=verification'),
            ),
            if (data['verification_status'] == 'approved')
              const RescuerSettingsDetails()
            else
              const SettingsBankingSection(),
          ],
        ),
      ),
      const SizedBox(height: 10),
    ],
  );
}

class _SettingsVerificationHeading extends StatelessWidget {
  const _SettingsVerificationHeading();
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: const Text(
      'Estado de verificación',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0,
        color: Color(0xff151423),
      ),
    ),
  );
}

class SettingsVerificationCard extends StatelessWidget {
  const SettingsVerificationCard({
    super.key,
    required this.status,
    required this.onPressed,
  });
  final String? status;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final approved = status == 'approved';
    final correction = status == 'changes_requested' || status == 'rejected';
    final review = status == 'submitted';
    final initial =
        status == null || status == 'not_started' || status == 'draft';
    final title = approved
        ? 'Cuenta verificada'
        : correction
        ? 'Verificación con errores'
        : review
        ? 'Verificación en proceso'
        : initial
        ? 'No verificada'
        : 'Verificación no disponible';
    final copy = approved
        ? 'Tu expediente de verificación está aprobado.'
        : correction
        ? 'Hay información que debes corregir para continuar.'
        : review
        ? 'Estamos revisando tu información. Te avisaremos en cuanto termine.'
        : initial
        ? 'Presenta tu expediente para revisión.'
        : 'No pudimos determinar el estado de tu expediente.';
    final action = correction
        ? 'Corregir información'
        : review
        ? 'Ver estado'
        : initial
        ? 'Iniciar verificación'
        : null;
    final ink = approved
        ? const Color(0xff0b7a5d)
        : correction
        ? const Color(0xffb51224)
        : const Color(0xff7841f2);
    final gradient = approved
        ? const [Color(0x1f2dc08e), Color(0x0d2dc08e)]
        : correction
        ? const [Color(0x1ae21d2f), Color(0x0ae21d2f)]
        : const [Color(0x1a7c3aed), Color(0x0d7c3aed)];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: approved
              ? const Color(0x592dc08e)
              : correction
              ? const Color(0xffffd4d8)
              : const Color(0x4d7c3aed),
        ),
        gradient: CssLinearGradient(degrees: 149, colors: gradient),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: approved
                        ? const Color(0x332dc08e)
                        : correction
                        ? const Color(0x24e21d2f)
                        : const Color(0x337c3aed),
                  ),
                  child: SvgPicture.asset(
                    'assets/profile/icon-shield.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    letterSpacing: 0,
                    color: ink,
                  ),
                ),
              ),
              if (action != null)
                const ExcludeSemantics(
                  child: Icon(Icons.chevron_right, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            copy,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.55,
              letterSpacing: 0,
              color: Color(0xff151423),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: review ? Alignment.center : Alignment.centerLeft,
              child: SizedBox(
                width: review ? double.infinity : null,
                child: FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff7841f2),
                    foregroundColor: const Color(0xfffbfbff),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    splashFactory: NoSplash.splashFactory,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(action),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
