import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

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
      final repository = ref.read(rescueRepositoryProvider);
      final state = await repository.dashboard();
      if (!mounted ||
          GoRouter.of(context).routeInformationProvider.value.uri.path !=
              '/publish') {
        return;
      }
      if (state['verification_status'] == 'approved') {
        await context.push('/rescue/new?kind=case');
      } else {
        final requests = await repository.mine('verification', 1);
        if (!mounted ||
            GoRouter.of(context).routeInformationProvider.value.uri.path !=
                '/publish') {
          return;
        }
        final current = requests.items
            .where((item) => item.kind == 'verification')
            .firstOrNull;
        await context.push(
          current == null
              ? '/rescue/new?kind=verification'
              : '/rescue/${current.id}',
        );
      }
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
                              'assets/profile/logo-paw.svg',
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
                              color: Color(0xff15110d),
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
                              color: Color(0xff8a837c),
                            ),
                          ),
                        ),
                      SizedBox(height: chosen ? 40 : 28),
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
                                    Color(0xff7841f2),
                                    Color(0xff7841f2),
                                  ],
                                  selected: selected == 'adoption',
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
                                    Color(0xff7841f2),
                                    Color(0xff7841f2),
                                  ],
                                  selected: selected == 'donation',
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
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xff15110d),
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
                                          color: Color(0xff8a837c),
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
                                  builder: (context) => AlertDialog(
                                    title: const Text('Revisión del caso'),
                                    content: const Text(
                                      'Dopmi revisará los textos, fotos y privacidad antes de publicar. Los gastos requieren comprobantes y aprobación independiente.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Entendido'),
                                      ),
                                    ],
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xff7841f2),
                                  minimumSize: Size.zero,
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
                                  backgroundColor: const Color(0xff15110d),
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
                                          semanticsLabel:
                                              'Consultando tu verificación',
                                        ),
                                      )
                                    : const Text('Continuar'),
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
  });
  final String title, subtitle, asset;
  final List<Color> colors;
  final VoidCallback? onPressed;
  final bool verification, selected;
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? const Color(0xfff3eeff) : Colors.white,
              border: Border.all(
                color: const Color(0xff7841f2),
                width: selected ? 2 : 1.5,
              ),
            ),
            child: SvgPicture.asset(
              asset,
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Color(0xff15110d),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? const Color(0xff15110d)
                    : const Color(0xff8a837c),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
