import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';

class VerificationIntroScreen extends StatelessWidget {
  const VerificationIntroScreen({
    super.key,
    required this.onContinue,
    required this.onLater,
    this.profileGaps = const [],
    this.onContinueWithoutProfile,
    this.asDialog = false,
    this.confirmingSubmission = false,
  });

  final VoidCallback onContinue, onLater;
  final List<String> profileGaps;
  final VoidCallback? onContinueWithoutProfile;
  final bool asDialog, confirmingSubmission;

  static const _body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: DopmiTokens.muted,
  );
  static const _heading = TextStyle(
    color: DopmiTokens.ink,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const _buttonText = TextStyle(
    fontFamily: DopmiTokens.bodyFont,
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  bool get _showGaps => !confirmingSubmission && profileGaps.isNotEmpty;

  Widget _icon(String name, double size, Color color) => SvgPicture.asset(
    'assets/profile/$name',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );

  Widget _introCard() => DecoratedBox(
    decoration: BoxDecoration(
      color: DopmiTokens.surface,
      border: Border.all(color: DopmiTokens.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_showGaps) ...[
            _icon('icon-shield.svg', 18, DopmiTokens.ink),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confirmingSubmission
                      ? 'Revisión del sello Dopmi'
                      : _showGaps
                      ? 'Confirma tu identidad y experiencia como rescatista'
                      : 'Sello Dopmi para tu refugio',
                  style: _heading,
                ),
                const SizedBox(height: 4),
                Text(
                  confirmingSubmission
                      ? 'El equipo de Dopmi revisará tu solicitud y tus documentos. '
                            'Tus documentos son privados y no aparecerán en tu perfil.'
                      : 'Al aprobar tu solicitud, el sello aparecerá en tu perfil y tus publicaciones. '
                            'Ayuda a que los adoptantes reconozcan a tu refugio.',
                  style: _body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _gapList() => Semantics(
    container: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Puedes completar estos datos en tu perfil',
          style: _heading,
        ),
        const SizedBox(height: 10),
        for (final gap in profileGaps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _icon(
                    'check-circle.svg',
                    16,
                    DopmiTokens.orangeButton,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    gap,
                    style: _body.copyWith(
                      color: DopmiTokens.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _panel(BuildContext context) => SizedBox(
    width: 340,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.textScalerOf(context).scale(22) > 32
                  ? 16
                  : 24,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DopmiTokens.sky,
                    ),
                    child: Center(
                      child: _icon('icon-shield.svg', 28, DopmiTokens.skyInk),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    confirmingSubmission
                        ? '¿Enviar solicitud de verificación?'
                        : 'Verifica tu cuenta',
                    textAlign: TextAlign.center,
                    style: _heading.copyWith(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 16),
                _introCard(),
                if (_showGaps) ...[
                  const SizedBox(height: 16),
                  _gapList(),
                ] else if (!confirmingSubmission) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Refugios, fundaciones y centros',
                    style: _heading,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Si representas a un refugio establecido, una fundación o '
                    'un centro de bienestar animal, puedes solicitar el sello. '
                    'Es opcional: puedes publicar mascotas en adopción sin él.',
                    style: _body,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: DopmiTokens.orangeButton,
                    foregroundColor: Colors.white,
                    textStyle: _buttonText,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: _buttonShape,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                    animationDuration: Duration.zero,
                  ),
                  child: Text(
                    confirmingSubmission
                        ? 'Enviar solicitud'
                        : _showGaps
                        ? 'Completar mi información'
                        : 'Completar solicitud',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onLater,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DopmiTokens.ink,
                    textStyle: _buttonText,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    side: const BorderSide(color: DopmiTokens.line),
                    shape: _buttonShape,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                    animationDuration: Duration.zero,
                  ),
                  child: Text(
                    _showGaps ? 'Cerrar' : 'Ahora no',
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_showGaps && onContinueWithoutProfile != null) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onContinueWithoutProfile,
                    style: TextButton.styleFrom(
                      foregroundColor: DopmiTokens.ink,
                      textStyle: _buttonText,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text(
                      'Continuar con la solicitud',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 4,
            child: IconButton(
              onPressed: onLater,
              tooltip: 'Cerrar',
              style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory)
                  .copyWith(
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
              icon: const Icon(Icons.close, size: 22, color: DopmiTokens.muted),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    if (asDialog) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        backgroundColor: DopmiTokens.surface,
        elevation: 0,
        child: _panel(context),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xff8f8d8b),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: DopmiTokens.surface,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: _panel(context),
            ),
          ),
        ),
      ),
    );
  }
}
