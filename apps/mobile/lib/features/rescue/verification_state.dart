import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'verification_form.dart';

class VerificationStateScreen extends StatelessWidget {
  const VerificationStateScreen({
    super.key,
    required this.approved,
    required this.loading,
    required this.onBack,
    required this.onHome,
    required this.onRecord,
    required this.onRefresh,
    this.onPublish,
    this.onWithdraw,
  });
  final bool approved, loading;
  final VoidCallback onBack, onHome, onRecord, onRefresh;
  final VoidCallback? onPublish, onWithdraw;
  @override
  Widget build(BuildContext context) => VerificationFormFrame(
    title: 'Verificación',
    onBack: loading ? null : onBack,
    bodyPadding: EdgeInsets.zero,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 520),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.textScalerOf(context).scale(24) > 32 ? 12 : 28,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (approved) ...[
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xff2ac39b),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/profile/check.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Semantics(
                header: true,
                child: Text(
                  approved
                      ? 'Cuenta verificada'
                      : 'Estamos revisando tu información',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff15110d),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                approved
                    ? 'Tu solicitud fue aprobada. Puedes continuar con la publicación de tus casos.'
                    : 'El equipo revisará tus datos y documentos. Te avisaremos cuando responda.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xff554e48),
                ),
              ),
              const SizedBox(height: 10),
              if (loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Consultando estado de verificación',
                  ),
                ),
              if (approved)
                FilledButton(
                  onPressed: loading ? null : onPublish,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff7841f2),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                  child: const Text('Publicar un caso'),
                )
              else
                OutlinedButton(
                  onPressed: loading ? null : onHome,
                  child: const Text('Volver al inicio'),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: loading ? null : onRecord,
                child: const Text('Consultar expediente'),
              ),
              TextButton(
                onPressed: loading ? null : onRefresh,
                child: const Text('Recargar estado'),
              ),
              if (onWithdraw != null)
                OutlinedButton(
                  onPressed: loading ? null : onWithdraw,
                  child: const Text('Retirar a borrador'),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
