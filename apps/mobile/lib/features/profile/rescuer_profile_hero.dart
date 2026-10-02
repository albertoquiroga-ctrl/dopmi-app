import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_repository.dart';
import '../rescue/rescue_repository.dart';

class RescuerProfileHero extends ConsumerWidget {
  const RescuerProfileHero(this.profile, {super.key});
  final Profile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LiveSection<Json>(
    tables: const ['dopmi_rescue_records'],
    load: () => ref.read(rescueRepositoryProvider).dashboard(),
    builder: (data, _) => RescuerIdentityCard(
      name: profile.name,
      city: profile.city,
      status: data['verification_status'] as String?,
      onEdit: () => context.push('/rescuer/profile/edit'),
    ),
  );
}

class RescuerIdentityCard extends StatefulWidget {
  const RescuerIdentityCard({
    super.key,
    required this.name,
    required this.city,
    required this.status,
    required this.onEdit,
  });
  final String name, city;
  final String? status;
  final VoidCallback onEdit;
  @override
  State<RescuerIdentityCard> createState() => _RescuerIdentityCardState();
}

class _RescuerIdentityCardState extends State<RescuerIdentityCard> {
  final states = WidgetStatesController();
  bool pressed = false;
  @override
  void initState() {
    super.initState();
    states.addListener(() {
      final next = states.value.contains(WidgetState.pressed);
      if (mounted && pressed != next) setState(() => pressed = next);
    });
  }

  @override
  void dispose() {
    states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verified = widget.status == 'approved';
    final label = switch (widget.status) {
      'approved' => 'Verificado',
      'submitted' => 'En revisión',
      'changes_requested' || 'rejected' => 'Requiere correcciones',
      null || 'draft' => 'Sin verificar',
      _ => 'Verificación no disponible',
    };
    final edit = AnimatedScale(
      scale: pressed ? .97 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.ease,
      child: TextButton.icon(
        key: const ValueKey('rescuer-profile-edit'),
        onPressed: widget.onEdit,
        statesController: states,
        icon: ExcludeSemantics(
          child: SvgPicture.asset(
            'assets/profile/icon-edit.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xff7841f2),
              BlendMode.srcIn,
            ),
          ),
        ),
        label: const Text('Editar'),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xf2ffffff),
          foregroundColor: const Color(0xff7841f2),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const StadiumBorder(),
          splashFactory: NoSplash.splashFactory,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    );
    final identity = Row(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x1415110d),
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            widget.name.isEmpty
                ? '?'
                : widget.name.characters.first.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xff7841f2),
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  height: 1.2,
                  letterSpacing: -.4,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: verified
                      ? const Color(0x4722bd90)
                      : const Color(0x38ffffff),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        'assets/profile/icon-shield.svg',
                        width: 14,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.city.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.city,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xebffffff),
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment(-.42, -.91),
          end: Alignment(.42, .91),
          colors: [Color(0xff7841f2), Color(0xff9b6cff), Color(0xffc4a8ff)],
          stops: [0, .55, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x477841f2),
            offset: Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(20) <= 26;
          final action = edit;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                if (verified) ...[const SizedBox(width: 12), action],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              if (verified) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            ],
          );
        },
      ),
    );
  }
}
