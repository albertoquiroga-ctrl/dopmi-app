import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';

import '../../core/css_linear_gradient.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_repository.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_repository.dart';

import 'package:url_launcher/url_launcher.dart';

import '../community/content_actions.dart';
import 'rescuer_profile_repository.dart';
import 'social_verification_screen.dart';
import 'rescuer_verification_card.dart';
import 'rescuer_profile_preview.dart';
import 'rescuer_social_dialog.dart' show rescuerSocialDisplayValue;

class RescuerProfileHero extends ConsumerStatefulWidget {
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
  ConsumerState<RescuerProfileHero> createState() => _RescuerProfileHeroState();
}

class _RescuerProfileHeroState extends ConsumerState<RescuerProfileHero> {
  late final IdentityController account;
  String? actor;
  int epoch = 0;
  Profile get profile => widget.profile;
  String? get contactEmail => widget.contactEmail;
  String? get contactPhone => widget.contactPhone;
  @override
  void initState() {
    super.initState();
    account = ref.read(identityControllerProvider);
    actor = account.identity?.id;
    account.addListener(identityChanged);
  }

  void identityChanged() {
    if (actor != account.identity?.id && mounted) {
      setState(() {
        actor = account.identity?.id;
        epoch++;
      });
    }
  }

  @override
  void dispose() {
    account.removeListener(identityChanged);
    super.dispose();
  }

  Widget accessIcon(String asset) => Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xfff0eeea),
      shape: BoxShape.circle,
    ),
    child: SvgPicture.asset(
      'assets/profile/$asset',
      width: 22,
      height: 22,
      colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
    ),
  );
  Widget accessLabel(String label) => Text(
    label,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: Color(0xff5c5650),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (actor != profile.id) {
      return const SizedBox.shrink();
    }
    return LiveSection<Json>(
      key: ValueKey('${profile.id}:$epoch'),
      tables: const [
        'dopmi_rescue_records',
        'dopmi_donations',
        'dopmi_rescuer_profiles',
      ],
      load: () async {
        final revision = epoch;
        final requestedOwner = profile.id;
        final repository = ref.read(rescuerProfileRepositoryProvider);
        bool current() =>
            mounted &&
            epoch == revision &&
            profile.id == requestedOwner &&
            account.identity?.id == requestedOwner &&
            repository.userId == requestedOwner;
        if (!current()) {
          throw const FormatException('El perfil no corresponde a tu cuenta.');
        }
        final data = await ref.read(rescueRepositoryProvider).dashboard();
        final draft = await repository.load();
        if (!current() ||
            (draft != null && draft['owner_id'] != requestedOwner)) {
          throw const FormatException('El perfil no corresponde a tu cuenta.');
        }
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
        if (!current()) {
          throw const FormatException(
            'La sesi\u00f3n cambi\u00f3. Abre de nuevo tu perfil.',
          );
        }
        final avatarPath =
            draft?['avatar_path'] as String? ??
            published?['avatar_path'] as String?;
        return {
          ...data,
          'draft_profile': draft,
          'avatar_path': avatarPath,
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
            onEdit: () => context.push('/rescuer/profile/edit'),
          ),
          const SizedBox(height: 18),
          content,
        ],
      ),
      builder: (data, refresh) {
        final published = data['published_profile'] as Json?;
        final draft = data['draft_profile'] as Json?;
        final about =
            draft?['bio'] as String? ?? published?['bio'] as String? ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RescuerIdentityCard(
              name: (draft?['display_name'] as String? ?? '').trim().isNotEmpty
                  ? draft!['display_name'] as String
                  : published?['name'] as String? ?? profile.name,
              city: published == null
                  ? profile.city
                  : [published['city'], published['region']]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(', '),
              status: data['verification_status'] as String?,
              avatarSource: (data['avatar_path'] as String? ?? '').isEmpty
                  ? null
                  : PhotoRef(
                      path: data['avatar_path'] as String,
                      purpose: MediaPurpose.rescuerAvatar,
                      persistence: PhotoPersistence.ordinary,
                      sign: () => ref
                          .read(rescuerProfileRepositoryProvider)
                          .avatarUrl(data['avatar_path'] as String),
                    ),
              onEdit: () async {
                await context.push('/rescuer/profile/edit');
                if (context.mounted) refresh();
              },
            ),
            const SizedBox(height: 12),
            RescuerVerificationCard(
              status: data['verification_status'] as String?,
              onPressed: () => context.push(
                data['verification_status'] == 'approved'
                    ? '/settings'
                    : '/rescue/new?kind=verification',
              ),
            ),
            if (data['avatar_failed'] == true) ...[
              TextButton(
                onPressed: refresh,
                child: const Text('Reintentar foto de perfil'),
              ),
            ],
            if (data['published_profile_failed'] == true) ...[
              const SizedBox(height: 12),
              const Text('No pudimos consultar tu perfil público.'),
              TextButton(
                onPressed: refresh,
                child: const Text('Reintentar perfil público'),
              ),
            ],
            ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('rescuer-profile-about'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffe3e4ed)),
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
                          color: Color(0xff151423),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      about.isEmpty
                          ? 'Cuenta quién eres y cómo ayudas a las mascotas.'
                          : about,
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
                        color: Color(0xff4f4e5c),
                        letterSpacing: 0,
                      ),
                    ),
                    ...[
                      const SizedBox(height: 10),
                      RescuerOwnerContacts(
                        phone: (contactPhone ?? '').isNotEmpty
                            ? contactPhone!
                            : draft?['public_phone'] as String? ?? '',
                        email: contactEmail ?? '',
                        instagram: draft?['instagram_url'] as String? ?? '',
                        facebook: draft?['facebook_url'] as String? ?? '',
                        website: draft?['website_url'] as String? ?? '',
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('owner-social-verification'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const SocialVerificationScreen(),
                ),
              ),
              icon: const Icon(Icons.link),
              label: const Text('Verificar mis redes sociales'),
            ),
            const SizedBox(height: 12),
            ReferenceFocusOutline(
              radius: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('rescuer-public-preview'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RescuerProfilePreview(
                        ownerId: profile.id,
                        payload:
                            draft ??
                            {
                              'display_name': profile.name,
                              'city': profile.city,
                              'bio': '',
                              'contact_consent': false,
                            },
                      ),
                    ),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x477841f2)),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xfff7f2ff), Colors.white],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0x1f7841f2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/profile/icon-user.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              purple,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vista previa de tu perfil público',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Esto es lo que verán los adoptantes.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SvgPicture.asset(
                          'assets/profile/icon-chevron-right.svg',
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                            muted,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1415110d),
                    offset: Offset(0, 10),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pagos y transacciones',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final stacked =
                          MediaQuery.textScalerOf(context).scale(12) > 20;
                      Widget access(String label, String asset, String route) =>
                          ReferenceFocusOutline(
                            radius: 14,
                            child: TextButton(
                              onPressed: () => context.push(route),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 4,
                                ),
                                foregroundColor: ink,
                                minimumSize: const Size(48, 48),
                              ),
                              child: stacked
                                  ? Row(
                                      children: [
                                        accessIcon(asset),
                                        const SizedBox(width: 12),
                                        Expanded(child: accessLabel(label)),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        accessIcon(asset),
                                        const SizedBox(height: 10),
                                        accessLabel(label),
                                      ],
                                    ),
                            ),
                          );
                      final entries = [
                        ('Mi cuenta', 'icon-card.svg', '/connect'),
                        (
                          'Mi historial',
                          'icon-billing.svg',
                          '/rescuer/received-payments',
                        ),
                        ('¿Dudas?', 'icon-help.svg', '/help'),
                      ];
                      return stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final e in entries)
                                  access(e.$1, e.$2, e.$3),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < entries.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  Expanded(
                                    child: access(
                                      entries[i].$1,
                                      entries[i].$2,
                                      entries[i].$3,
                                    ),
                                  ),
                                ],
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class RescuerIdentityCard extends ConsumerStatefulWidget {
  const RescuerIdentityCard({
    super.key,
    required this.name,
    required this.city,
    required this.status,
    required this.onEdit,
    this.avatarUrl,
    this.avatarSource,
  });
  final String name, city;
  final String? status;
  final String? avatarUrl;
  final PhotoRef? avatarSource;
  final VoidCallback onEdit;
  @override
  ConsumerState<RescuerIdentityCard> createState() =>
      _RescuerIdentityCardState();
}

class _RescuerIdentityCardState extends ConsumerState<RescuerIdentityCard> {
  @override
  void didUpdateWidget(RescuerIdentityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarSource != null &&
        oldWidget.avatarSource?.identity != widget.avatarSource?.identity) {
      ref
          .read(photoRuntimeProvider)
          .invalidate(oldWidget.avatarSource!, removeDisk: true)
          .ignore();
    }
  }

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
    final visualEditHeight =
        (MediaQuery.textScalerOf(context).scale(13) * 16 / 13 + 16).clamp(
          44.0,
          double.infinity,
        );
    final editInset = ((48 - visualEditHeight) / 2).clamp(0.0, 2.0);
    final edit = Transform.translate(
      offset: Offset(0, -editInset),
      child: AnimatedScale(
        scale: pressed ? .97 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.ease,
        child: ReferenceFocusOutline(
          radius: 99,
          outlineInset: EdgeInsets.symmetric(vertical: editInset),
          child: TextButton(
            key: const ValueKey('rescuer-profile-edit'),
            onPressed: widget.onEdit,
            statesController: states,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xf2ffffff),
              foregroundColor: const Color(0xff7841f2),
              minimumSize: const Size(48, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
              overlayColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: const StadiumBorder(),
              splashFactory: NoSplash.splashFactory,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 16 / 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
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
                const SizedBox(width: 6),
                const Text('Editar'),
              ],
            ),
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
    final avatar = Container(
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
        child: widget.avatarSource != null
            ? RemotePhoto(
                source: widget.avatarSource!,
                key: const ValueKey('rescuer-profile-avatar'),
                width: 72,
                height: 72,
                excludeFromSemantics: true,
                loading: initial,
                unavailable: (retry) => Tooltip(
                  message: 'Reintentar foto de perfil',
                  child: InkWell(onTap: retry, child: initial),
                ),
              )
            : widget.avatarUrl == null
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
    );
    final identityCopy = Column(
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
        if (!verified) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      height: 15.2 / 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.city.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.city,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 16 / 13,
              color: Color(0xebffffff),
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
    final identity = MediaQuery.textScalerOf(context).scale(20) > 26
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [avatar, const SizedBox(height: 14), identityCopy],
          )
        : Row(
            children: [
              avatar,
              const SizedBox(width: 14),
              Expanded(child: identityCopy),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                action,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              ...[
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
  const RescuerOwnerContacts({
    super.key,
    required this.phone,
    this.email,
    this.address = '',
    this.instagram = '',
    this.facebook = '',
    this.website = '',
  });
  final String phone, address, instagram, facebook, website;
  final String? email;
  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        'icon-phone',
        phone.trim(),
        phone.trim().isEmpty ? null : Uri(scheme: 'tel', path: phone.trim()),
      ),
      (
        'icon-mail',
        (email ?? '').trim(),
        (email ?? '').trim().isEmpty
            ? null
            : Uri(scheme: 'mailto', path: email!.trim()),
      ),
      ('icon-instagram', instagram.trim(), null),
      ('icon-facebook', facebook.trim(), null),
      ('globe', website.trim(), null),
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
                  child: InkWell(
                    onTap: entries[i].$2.isEmpty
                        ? null
                        : i >= 2
                        ? () => openPublicSocialUrl(context, entries[i].$2)
                        : entries[i].$3 != null
                        ? () async {
                            try {
                              await launchUrl(
                                entries[i].$3!,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No pudimos abrir este contacto.',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        : () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Direcci\u00f3n'),
                              content: SelectableText(entries[i].$2),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          ),
                    child: Text(
                      entries[i].$2.isEmpty
                          ? 'Por completar'
                          : i == 2
                          ? rescuerSocialDisplayValue(
                              'instagram_url',
                              entries[i].$2,
                            )
                          : i == 3
                          ? rescuerSocialDisplayValue(
                              'facebook_url',
                              entries[i].$2,
                            )
                          : entries[i].$2,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        letterSpacing: 0,
                        color: Color(0xff151423),
                      ),
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
