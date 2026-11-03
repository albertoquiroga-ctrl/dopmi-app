import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/ui.dart';
import '../../core/donor_notification_button.dart';
import '../adoption/community_ui.dart';
import 'rescue_repository.dart';

class PublishChoiceScreen extends ConsumerStatefulWidget {
  const PublishChoiceScreen({super.key});
  @override
  ConsumerState<PublishChoiceScreen> createState() => _PublishChoiceState();
}

class _PublishChoiceState extends ConsumerState<PublishChoiceScreen> {
  bool busy = false;
  String? error;

  Future<void> receive() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // The server requires an active account with confirmed email. Dopmi
      // verification is optional; case approval and Stripe requirements remain.
      await ref.read(rescueRepositoryProvider).dashboard();
      if (!mounted ||
          GoRouter.of(context).routeInformationProvider.value.uri.path !=
              '/publish') {
        return;
      }
      await context.push('/rescue/new?kind=case');
    } catch (cause) {
      if (mounted) setState(() => error = rescueError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? selected;

  Future<void> continueChoice() async {
    if (busy || selected == null) return;
    if (selected == 'adoption') {
      await context.push('/my-adoptions/new');
    } else {
      await receive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = selected != null;
    final motion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(3, selectedPath: '/publish'),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, viewport) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 42,
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/profile/logo-paw-naranja.svg',
                              width: 40,
                              height: 40,
                              semanticsLabel: 'Dopmi',
                            ),
                            const Spacer(),
                            const DonorNotificationButton(rescuer: true),
                          ],
                        ),
                      ),
                      AnimatedPadding(
                        duration: motion
                            ? Duration.zero
                            : const Duration(milliseconds: 450),
                        curve: const Cubic(.22, 1, .36, 1),
                        padding: EdgeInsets.only(
                          top: chosen
                              ? 20
                              : MediaQuery.textScalerOf(context).scale(14) > 20
                              ? 32
                              : viewport.maxHeight * .315,
                        ),
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: chosen ? 46 : 0,
                          ),
                          padding: chosen
                              ? const EdgeInsets.fromLTRB(2, 2, 2, 4)
                              : EdgeInsets.zero,
                          alignment: chosen
                              ? Alignment.centerLeft
                              : Alignment.center,
                          child: Text(
                            '¿Qué quieres publicar?',
                            textAlign: chosen
                                ? TextAlign.left
                                : TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 28,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: DopmiTokens.ink,
                            ),
                          ),
                        ),
                      ),
                      if (!chosen)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
                          child: Text(
                            'Selecciona el tipo de publicación que deseas crear',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: DopmiTokens.muted,
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: PublishTypeCard(
                                  title: 'Dar en adopción',
                                  subtitle: 'Publica una mascota que esté lista para encontrar un hogar',
                                  asset: 'assets/profile/publish-adopter.svg',
                                  colors: const [
                                    DopmiTokens.orange,
                                    DopmiTokens.sky,
                                    DopmiTokens.saffronSoft,
                                  ],
                                  selected: selected == 'adoption',
                                  muted: chosen && selected != 'adoption',
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => selected = 'adoption',
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: PublishTypeCard(
                                  title: 'Recibir Apoyo',
                                  subtitle: 'Crea un caso para apoyarte a solventar los gastos que ya hayas cubierto recientemente de una mascota.',
                                  asset: 'assets/profile/tab-donate.svg',
                                  colors: const [
                                    DopmiTokens.orange,
                                    DopmiTokens.sky,
                                    DopmiTokens.saffronSoft,
                                  ],
                                  selected: selected == 'donation',
                                  muted: chosen && selected != 'donation',
                                  verification: true,
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => selected = 'donation',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: motion
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                        curve: const Cubic(.22, 1, .36, 1),
                        child: chosen
                            ? SizedBox(
                                height:
                                    MediaQuery.textScalerOf(context).scale(14) >
                                        20
                                    ? null
                                    : 244,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    28,
                                    12,
                                    16,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        selected == 'adoption'
                                            ? 'Dar en adopción'
                                            : 'Recibir Apoyo',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 28,
                                          height: 1.1,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -.56,
                                          color: DopmiTokens.orange,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        selected == 'adoption'
                                            ? 'Publica una mascota que esté lista para encontrar un hogar'
                                            : 'Crea un caso para apoyarte a solventar los gastos que ya hayas cubierto recientemente de una mascota.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: DopmiTokens.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (error != null) Notice(error!, isError: true),
                      if (chosen)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => _PublishReviewDialog(
                                    adoption: selected == 'adoption',
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: DopmiTokens.ink,
                                  minimumSize: const Size(0, 48),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'DopMi revisará el caso antes de publicar',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.info_outline, size: 14),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: busy ? null : continueChoice,
                                style: FilledButton.styleFrom(
                                  backgroundColor: DopmiTokens.orangeButton,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 52),
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                          semanticsLabel:
                                              'Consultando tu cuenta',
                                        ),
                                      )
                                    : const Text('Empezar'),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => context.go('/rescuer'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 41),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PublishReviewDialog extends StatelessWidget {
  const _PublishReviewDialog({required this.adoption});

  final bool adoption;

  Widget heading() => Text(
    adoption ? 'Revisión del caso de adopción' : 'Revisión del caso de apoyo',
    style: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: DopmiTokens.ink,
    ),
  );

  Widget close(BuildContext context) => IconButton(
    onPressed: () => Navigator.pop(context),
    tooltip: 'Cerrar',
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: const Icon(Icons.close, size: 22, color: DopmiTokens.muted),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (MediaQuery.textScalerOf(context).scale(22) > 30) ...[
              Align(alignment: Alignment.centerRight, child: close(context)),
              heading(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading()),
                  close(context),
                ],
              ),
            const SizedBox(height: 14),
            _ReviewPoint(
              title: 'Qué es:',
              description: adoption
                  ? 'revisamos la información y las fotos de tu publicación antes de mostrarla a los adoptantes.'
                  : 'revisamos la información, las fotos, las necesidades y los comprobantes de tu caso antes de publicarlo.',
            ),
            const SizedBox(height: 10),
            _ReviewPoint(
              title: 'Por qué:',
              description: adoption
                  ? 'cuidamos a quienes buscan adoptar y a las mascotas frente a casos incompletos o engañosos.'
                  : 'cuidamos la confianza de quienes apoyan: las necesidades deben corresponder a gastos ya pagados y estar respaldadas.',
            ),
            const SizedBox(height: 10),
            _ReviewPoint(
              title: 'Cómo funciona:',
              description: adoption
                  ? 'completas el flujo de publicación y envías el caso; queda en revisión hasta que Dopmi lo apruebe y aparezca en Adoptar.'
                  : 'completas el caso y sus necesidades, adjuntas los comprobantes y envías todo a revisión; Dopmi revisa el conjunto completo antes de publicarlo en Apoyar.',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: DopmiTokens.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReviewPoint extends StatelessWidget {
  const _ReviewPoint({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('• ', style: TextStyle(fontSize: 13, height: 1.45)),
      Expanded(
        child: Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.45,
              color: DopmiTokens.ink,
            ),
            children: [
              TextSpan(
                text: '$title ',
                style: const TextStyle(
                  color: DopmiTokens.orangeButton,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: description),
            ],
          ),
        ),
      ),
    ],
  );
}

class PublishTypeCard extends StatelessWidget {
  const PublishTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.colors,
    required this.onPressed,
    this.verification = false,
    this.selected = false,
    this.muted = false,
  });
  final String title, subtitle, asset;
  final List<Color> colors;
  final VoidCallback? onPressed;
  final bool verification, selected, muted;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onPressed != null,
    label: title,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(46),
      splashFactory: NoSplash.splashFactory,
      child: Column(
        children: [
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            width: 92,
            height: 92,
            padding: EdgeInsets.all(muted ? 1.5 : 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: muted ? DopmiTokens.line : null,
              gradient: muted
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                      stops: colors.length == 3 ? const [0, .52, 1] : null,
                    ),
              boxShadow: muted
                  ? null
                  : const [
                      BoxShadow(color: Color(0x57eb6425), blurRadius: 10),
                      BoxShadow(color: Color(0x47cbe8fa), blurRadius: 16),
                      BoxShadow(color: Color(0x38fef3d4), blurRadius: 22),
                    ],
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Center(
                child: SvgPicture.asset(
                  asset,
                  width: 32,
                  height: 32,
                  colorFilter: ColorFilter.mode(
                    muted ? DopmiTokens.navigationInactive : DopmiTokens.orange,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: DopmiTokens.muted,
            ),
          ),
        ],
      ),
    ),
  );
}
