import '../../core/css_linear_gradient.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_repository.dart';
import '../rescue/rescue_repository.dart';
import 'rescuer_profile_metrics.dart';
import 'rescuer_profile_repository.dart';
import 'rescuer_profile_activity.dart';
import 'rescuer_verification_card.dart';

class RescuerProfileHero extends ConsumerWidget {
  const RescuerProfileHero(
    this.profile, {
    super.key,
    this.contactEmail,
    this.contactPhone,
  });
  final Profile profile;
  // Supplied only by the authenticated owner route, never by public projection.
  final String? contactEmail, contactPhone;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LiveSection<Json>(
    tables: const [
      'dopmi_rescue_records',
      'dopmi_donations',
      'dopmi_rescuer_profiles',
    ],
    load: () async {
      final data = await ref.read(rescueRepositoryProvider).dashboard();
      Json? published;
      var publicFailed = false;
      if (data['verification_status'] == 'approved') {
        try {
          published = await ref
              .read(communityRepositoryProvider)
              .publicProfile(profile.id);
          if (published != null && published['id'] != profile.id) {
            throw const FormatException(
              'El perfil público no corresponde a tu cuenta.',
            );
          }
        } catch (_) {
          published = null;
          publicFailed = true;
        }
      }
      String? avatarUrl;
      var avatarFailed = false;
      final avatarPath = published?['avatar_path'] as String?;
      if (avatarPath != null && avatarPath.isNotEmpty) {
        try {
          avatarUrl = await ref
              .read(rescuerProfileRepositoryProvider)
              .avatarUrl(avatarPath);
        } catch (_) {
          avatarFailed = true;
        }
      }
      return {
        ...data,
        'avatar_url': avatarUrl,
        'avatar_failed': avatarFailed,
        'published_profile': published,
        'published_profile_failed': publicFailed,
      };
    },
    statusFrame: (content) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RescuerIdentityCard(
          name: profile.name,
          city: profile.city,
          status: 'unavailable',
          onEdit: () {},
        ),
        const SizedBox(height: 18),
        content,
      ],
    ),
    builder: (data, refresh) {
      final published = data['published_profile'] as Json?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RescuerIdentityCard(
            name: published?['name'] as String? ?? profile.name,
            city: published == null
                ? profile.city
                : [published['city'], published['region']]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(', '),
            status: data['verification_status'] as String?,
            avatarUrl: data['avatar_url'] as String?,
            onEdit: () async {
              await context.push('/rescuer/profile/edit');
              if (context.mounted) refresh();
            },
          ),
          const SizedBox(height: 18),
          RescuerProfileMetrics(
            data: data,
            onCases: () => context.go('/my-cases'),
            onTransfers: () => context.go('/rescuer'),
          ),
          const SizedBox(height: 18),
          RescuerVerificationCard(
            status: data['verification_status'] as String?,
            onPressed: () => context.push('/rescue/new?kind=verification'),
          ),
          if (data['avatar_failed'] == true) ...[
            TextButton(
              onPressed: refresh,
              child: const Text('Reintentar foto de perfil'),
            ),
          ],
          if (data['published_profile_failed'] == true) ...[
            const SizedBox(height: 18),
            const Text('No pudimos consultar tu perfil público.'),
            TextButton(
              onPressed: refresh,
              child: const Text('Reintentar perfil público'),
            ),
          ],
          if ((published?['bio'] as String? ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xffe6e2dd)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      'Sobre ti',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff15110d),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    published!['bio'] as String,
                    maxLines: MediaQuery.textScalerOf(context).scale(14) > 20
                        ? null
                        : 3,
                    overflow: MediaQuery.textScalerOf(context).scale(14) > 20
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xff554e48),
                      letterSpacing: 0,
                    ),
                  ),
                  if ((contactPhone ?? '').trim().isNotEmpty ||
                      (contactEmail ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RescuerOwnerContacts(
                      phone: contactPhone ?? '',
                      email: contactEmail,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          RescuerProfileActivity(
            data: data,
            onHome: () => context.go('/rescuer'),
            onExpense: (id) => context.push(
              Uri(
                path: '/rescue/$id',
                queryParameters: {'kind': 'expense', 'record': '1'},
              ).toString(),
            ),
            onStart: () => context.push(
              data['verification_status'] == 'approved'
                  ? '/rescue/new?kind=case'
                  : '/rescue/new?kind=verification',
            ),
          ),
        ],
      );
    },
  );
}

class RescuerIdentityCard extends StatefulWidget {
  const RescuerIdentityCard({
    super.key,
    required this.name,
    required this.city,
    required this.status,
    required this.onEdit,
    this.avatarUrl,
  });
  final String name, city;
  final String? status;
  final String? avatarUrl;
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
      null || 'draft' || 'not_started' => 'Sin verificar',
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
    final initial = Text(
      widget.name.isEmpty ? '?' : widget.name.characters.first.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Color(0xff7841f2),
        letterSpacing: 0,
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
          child: ClipOval(
            child: widget.avatarUrl == null
                ? initial
                : Image.network(
                    widget.avatarUrl!,
                    key: const ValueKey('rescuer-profile-avatar'),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    frameBuilder: (context, child, frame, synchronous) =>
                        frame == null && !synchronous ? initial : child,
                    errorBuilder: (context, error, stack) => initial,
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
        gradient: const CssLinearGradient(
          degrees: 155,
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

/// Private account contacts shown only within the owner's profile screen.
class RescuerOwnerContacts extends StatelessWidget {
  const RescuerOwnerContacts({super.key, required this.phone, this.email});
  final String phone;
  final String? email;
  @override
  Widget build(BuildContext context) {
    final entries = [
      if (phone.trim().isNotEmpty) ('icon-phone', phone.trim()),
      if ((email ?? '').trim().isNotEmpty) ('icon-mail', email!.trim()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    'assets/profile/${entries[i].$1}.svg',
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(
                      Color(0xff7841f2),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entries[i].$2,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                      letterSpacing: 0,
                      color: Color(0xff15110d),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
