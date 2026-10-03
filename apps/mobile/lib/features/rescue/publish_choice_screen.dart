import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
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

  @override
  Widget build(BuildContext context) {
    // The reference cancel control occupies 16px padding plus a 1.2 line.
    // Keep its 48px touch target without moving the visible centered content.
    final cancelCompensation =
        (48 - (MediaQuery.textScalerOf(context).scale(14) * 1.2 + 16)).clamp(
          0.0,
          48.0,
        ) /
        2;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(3, selectedPath: '/publish'),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, viewport) => DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    48 + cancelCompensation,
                    24,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              children: [
                                Text(
                                  '¿Qué quieres publicar?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 28,
                                    height: 1.15,
                                    letterSpacing: -.56,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff151423),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Selecciona el tipo de publicación que deseas crear',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: Color(0xff4f4e5c),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          PublishTypeCard(
                            title: 'Dar en adopción',
                            subtitle: 'Publica una mascota que esté lista para encontrar un hogar',
                            asset: 'assets/profile/publish-adopter.svg',
                            colors: const [
                              Color(0xff00bc7d),
                              Color(0xff00bba7),
                            ],
                            onPressed: busy
                                ? null
                                : () => context.push('/my-adoptions/new'),
                          ),
                          const SizedBox(height: 16),
                          PublishTypeCard(
                            title: 'Recibir donaciones',
                            subtitle: 'Crea un caso de donación para cubrir necesidades de una mascota',
                            asset: 'assets/profile/publish-donor.svg',
                            colors: const [
                              Color(0xff9810fa),
                              Color(0xff8200db),
                            ],
                            verification: true,
                            onPressed: busy ? null : receive,
                          ),
                          if (busy) ...[
                            const SizedBox(height: 16),
                            const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Consultando tu verificación',
                                ),
                              ),
                            ),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 16),
                            Notice(error!, isError: true),
                          ],
                          SizedBox(height: 32 - cancelCompensation),
                          Center(
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => context.go('/rescuer'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xff4f4e5c),
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class PublishTypeCard extends StatefulWidget {
  const PublishTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.colors,
    required this.onPressed,
    this.verification = false,
  });
  final String title, subtitle, asset;
  final List<Color> colors;
  final VoidCallback? onPressed;
  final bool verification;
  @override
  State<PublishTypeCard> createState() => _PublishTypeCardState();
}

class _PublishTypeCardState extends State<PublishTypeCard> {
  bool hover = false, focused = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onPressed != null,
    label:
        '${widget.title}. ${widget.subtitle}${widget.verification ? '. Requiere verificación' : ''}',
    onTap: widget.onPressed,
    child: FocusableActionDetector(
      enabled: widget.onPressed != null,
      onShowHoverHighlight: (value) => setState(() => hover = value),
      onShowFocusHighlight: (value) => setState(() => focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.ease,
            transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: hover
                    ? const Color(0xffd8d2ca)
                    : const Color(0xffe3e4ed),
              ),
              boxShadow: [
                BoxShadow(
                  color: hover
                      ? const Color(0x1a15110d)
                      : const Color(0x0f15110d),
                  offset: Offset(0, hover ? 12 : 8),
                  blurRadius: hover ? 28 : 22,
                ),
                if (focused)
                  const BoxShadow(color: Color(0x477841f2), spreadRadius: 3),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.colors,
                    ),
                  ),
                  child: SvgPicture.asset(widget.asset, width: 28, height: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.2,
                          letterSpacing: -.34,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff151423),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: Color(0xff4f4e5c),
                        ),
                      ),
                      if (widget.verification) ...[
                        const SizedBox(height: 9),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Color(0xffc2410c),
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Requiere verificación',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xffc2410c),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
