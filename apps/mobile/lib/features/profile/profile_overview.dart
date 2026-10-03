import 'dart:ui' as ui;

import '../../core/reference_focus_outline.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/donor_notification_button.dart';
import '../../core/ui.dart';
import 'rescuer_profile_hero.dart';
import 'rescuer_profile_access.dart';
import 'rescuer_logout_row.dart';
import 'rescuer_settings_verification.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/experience_controller.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../payments/guardian_repository.dart';
import '../payments/payment_repository.dart';

final profilePaymentHistoryProvider =
    Provider<Future<DataPage<Json>> Function()>((ref) {
      return () => ref.read(paymentRepositoryProvider).history(1);
    });

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Profile? profile;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final next = await ref.read(identityRepositoryProvider).loadProfile();
      if (!mounted ||
          next.id != ref.read(identityControllerProvider).identity?.id) {
        return;
      }
      setState(() {
        profile = next;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = identityError(e));
    }
  }

  Future<void> switchMode(bool rescuer) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final owner = ref.read(identityControllerProvider).identity?.id;
    try {
      final next = await ref
          .read(identityRepositoryProvider)
          .setExperience(rescuer ? 'rescuer' : 'donor');
      if (!mounted ||
          owner != ref.read(identityControllerProvider).identity?.id) {
        return;
      }
      ref.read(experienceProvider).applyProfile(next);
      setState(() => profile = next);
      context.go(rescuer ? '/rescuer' : '/adoptions');
    } catch (e) {
      if (mounted) setState(() => error = identityError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(experienceProvider);
    final account = ref.watch(identityControllerProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([experience, account]),
      builder: (context, _) {
        profile = experience.profile ?? profile;
        final rescuer = experience.value == AccountExperience.rescuer;
        if (!rescuer && profile != null) {
          return DonorProfileView(
            profile: profile!,
            busy: busy,
            error: error,
            onSwitch: () => switchMode(true),
          );
        }
        return ProfileFrame(
          title: rescuer ? 'Mi perfil' : 'Perfil',
          rescuerOverview: rescuer,
          children: [
            if (profile == null && error == null)
              const Center(child: CircularProgressIndicator()),
            if (error != null && profile == null) ...[
              Notice(error!, isError: true),
              TextButton(
                onPressed: load,
                child: const Text('Volver a intentar'),
              ),
            ],
            if (profile != null) ...[
              if (rescuer)
                RescuerProfileHero(
                  profile!,
                  contactEmail: account.identity?.id == profile!.id
                      ? account.identity?.email
                      : null,
                  contactPhone: account.identity?.id == profile!.id
                      ? profile!.phone
                      : null,
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: rescuer ? const Color(0xfff3eefc) : yellow,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        foregroundColor: ink,
                        radius: 28,
                        child: Text(
                          profile!.name.isEmpty
                              ? '?'
                              : profile!.name.characters.first.toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile!.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (rescuer)
                              const Text('Tu espacio de rescatista')
                            else
                              const GuardianMembership(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (rescuer) ...[
                const RescuerProfileAccess(),
              ] else ...[
                Text(
                  'Registro de donaciones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const ProfileDonationLog(),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.push('/payments'),
                  child: const Text('Ver más'),
                ),
                const SizedBox(height: 20),
                const SavedPetsRow(),
                const SavedRescuersRow(),
                ProfileRow(
                  title: 'Mi impacto',
                  subtitle: 'Avances de casos que apoyaste',
                  icon: Icons.auto_stories_outlined,
                  path: '/impact',
                ),
              ],
              if (!rescuer)
                ProfileRow(
                  title: 'Configuración',
                  icon: Icons.settings_outlined,
                  path: '/settings',
                ),
              const SizedBox(height: 20),
              if (error != null) Notice(error!, isError: true),
              RescuerDonorModeCard(
                enabled: !busy && profile!.status == 'active',
                onPressed: () => switchMode(false),
              ),
              if (busy)
                const LinearProgressIndicator(
                  semanticsLabel: 'Cambiando experiencia',
                ),
            ],
          ],
        );
      },
    );
  }
}

class RescuerDonorModeCard extends StatelessWidget {
  const RescuerDonorModeCard({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.settings = false,
  });
  final bool enabled, settings;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe3e4ed)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings ? 'Cambiar a usuario donante' : 'Modo donante',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: 0,
                  color: Color(0xff151423),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                settings
                    ? 'Cambia tu experiencia en la app'
                    : 'Adopta, apoya y sigue impacto',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 15.2 / 12,
                  letterSpacing: 0,
                  color: Color(0xff4f4e5c),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: settings
              ? 'Cambiar a usuario donante'
              : 'Cambiar a modo donante',
          toggled: settings,
          enabled: enabled,
          child: ReferenceFocusOutline(
            radius: 99,
            outlineInset: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 14.5,
            ),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(99),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    key: const ValueKey('rescuer-donor-switch'),
                    width: 32,
                    height: 19,
                    padding: const EdgeInsets.all(1),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: settings
                          ? const Color(0xff7841f2)
                          : const Color(0xffdad7d2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: AnimatedContainer(
                      transform: Matrix4.translationValues(
                        settings ? 13 : 0,
                        0,
                        0,
                      ),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.ease,
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class DonorModeDialog extends StatelessWidget {
  const DonorModeDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 361,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Text(
                    '¿Activamos tu modo Rescatista?',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Publica casos de mascotas con necesidad de un hogar.',
                  style: TextStyle(fontSize: 14, height: 1.45, color: muted),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff3cc),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Tu perfil de Adoptante se queda intacto.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff6b5000),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final step in const [
                  (
                    'Cambias de navegación',
                    'Ves Inicio, Casos y Publicar pensados para quien rescata.',
                    'rtab-home.svg',
                  ),
                  (
                    'Armas el perfil del compañerito',
                    'Nombre, fotos e historia para que alguien se enamore de verdad.',
                    'onb-camera.svg',
                  ),
                  (
                    'Publicas cuando estés listo',
                    'Te guiamos paso a paso y puedes pausar cuando quieras.',
                    'rtab-publish.svg',
                  ),
                  (
                    'Vuelves a Adoptante en un toque',
                    'Tu perfil de Adoptante no se borra: regresas cuando lo necesites.',
                    'onb-adopt-heart.svg',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xffe6e2dd)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xfffff8e0),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/profile/${step.$3}',
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xff6b5000),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.$1,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step.$2,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: ink,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sí, cambiar a Rescatista'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ahora no', style: TextStyle(color: muted)),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 0,
            child: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close, size: 22, color: muted),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    ),
  );
}

class DonorProfileView extends ConsumerWidget {
  const DonorProfileView({
    super.key,
    required this.profile,
    required this.busy,
    required this.onSwitch,
    this.error,
  });
  final Profile profile;
  final bool busy;
  final String? error;
  final VoidCallback onSwitch;

  Future<void> confirmMode(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x7a15110d),
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialogContext) => const DonorModeDialog(),
    );
    if (confirmed == true && context.mounted) onSwitch();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    extendBody: true,
    backgroundColor: Colors.white,
    bottomNavigationBar: const CommunityNav(4),
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/profile/logo-paw.svg',
                width: 40,
                height: 40,
                semanticsLabel: 'Dopmi',
              ),
              const Spacer(),
              const DonorNotificationButton(),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Mi perfil',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 29),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0f15110d),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xfff3f0ea),
                  foregroundColor: ink,
                  child: Text(
                    profile.name.isEmpty
                        ? '?'
                        : profile.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      if (profile.city.isNotEmpty)
                        Text(
                          profile.city,
                          style: const TextStyle(fontSize: 13, color: muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (ref.watch(guardianEnabledProvider)) const DonorGuardianFeature(),
          const SizedBox(height: 20),
          const DonorAccessGroup(
            title: 'Preferencias',
            items: [
              ('Mi cuenta', Icons.person_outline, '/basic-info'),
              ('Mis mascotas', Icons.favorite_border, '/messages'),
            ],
          ),
          const SizedBox(height: 20),
          DonorAccessGroup(
            title: 'Pagos y suscripciones',
            items: [
              if (ref.watch(guardianEnabledProvider)) ...[
                (
                  'Métodos de pago',
                  Icons.credit_card,
                  '/settings/payment-methods',
                ),
                (
                  'Suscripción y pagos',
                  Icons.receipt_long_outlined,
                  '/guardian',
                ),
              ],
              ('Mi historial', Icons.access_time, '/payments'),
            ],
          ),
          const SizedBox(height: 20),
          DonorFeature(
            title: 'Publica un caso de adopción',
            subtitle: 'Cambia tu perfil a modo Rescatista. Siempre podrás regresar a la navegación como Adoptante.',
            icon: Icons.add,
            light: true,
            onPressed: busy || profile.status != 'active'
                ? null
                : () => confirmMode(context),
          ),
          if (busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Cambiando experiencia',
            ),
          if (error != null) Notice(error!, isError: true),
          const SizedBox(height: 20),
          DonorSupportRow(
            title: 'Sobre Nosotros',
            asset: 'icon-doc.svg',
            onPressed: () => context.push('/about'),
          ),
          const SizedBox(height: 10),
          DonorSupportRow(
            title: 'Centro de ayuda',
            asset: 'icon-help.svg',
            onPressed: () => context.push('/help'),
          ),
          const SizedBox(height: 10),
          DonorSupportRow(
            asset: 'icon-logout.svg',
            title: 'Cerrar sesión',
            onPressed: () async {
              try {
                await ref.read(identityControllerProvider).logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(identityError(e))));
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}

class DonorSupportRow extends StatelessWidget {
  const DonorSupportRow({
    super.key,
    required this.title,
    required this.asset,
    required this.onPressed,
  });
  final String title, asset;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0f15110d),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xfff0eeea),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/profile/$asset',
                  width: 20,
                  height: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/profile/icon-chevron-right.svg',
                width: 20,
                height: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DonorGuardianFeature extends ConsumerStatefulWidget {
  const DonorGuardianFeature({super.key});
  @override
  ConsumerState<DonorGuardianFeature> createState() =>
      _DonorGuardianFeatureState();
}

class _DonorGuardianFeatureState extends ConsumerState<DonorGuardianFeature> {
  late Future<Json> state = ref.read(guardianRepositoryProvider).state();
  void reload() {
    final next = ref.read(guardianRepositoryProvider).state();
    setState(() {
      state = next;
    });
  }

  Future<void> open({bool introduction = false, bool impact = false}) async {
    await context.push(
      impact
          ? '/impact'
          : introduction
          ? '/impact/guardian'
          : '/guardian',
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: state,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const DonorFeature(
          title: 'Guardián',
          subtitle: 'Consultando tu membresía…',
          icon: Icons.shield_outlined,
          onPressed: null,
        );
      }
      if (snapshot.hasError) {
        return DonorFeature(
          title: 'Tu membresía Guardián',
          subtitle: 'No pudimos consultar tu estado. Toca para reintentar.',
          icon: Icons.shield_outlined,
          onPressed: reload,
        );
      }
      final active = snapshot.data?['plan']?['status'] == 'active';
      return DonorFeature(
        title: active ? '¡Ya eres Guardián!' : 'Sé un Guardián',
        subtitle: active
            ? 'Consulta mi impacto a la manada'
            : 'Apoyo mensual con reportes de impacto',
        icon: active ? Icons.shield_outlined : Icons.star_border,
        onPressed: () => open(
          impact: active,
          introduction:
              snapshot.data?['plan'] == null &&
              snapshot.data?['activation'] == null,
        ),
      );
    },
  );
}

class DonorFeature extends StatefulWidget {
  const DonorFeature({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.light = false,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool light;
  @override
  State<DonorFeature> createState() => _DonorFeatureState();
}

class _DonorFeatureState extends State<DonorFeature> {
  bool pressed = false;
  String get title => widget.title;
  String get subtitle => widget.subtitle;
  IconData get icon => widget.icon;
  bool get light => widget.light;
  VoidCallback? get onPressed => widget.onPressed;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed && onPressed != null ? .99 : 1,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    curve: Curves.ease,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: light ? const Color(0x1415110d) : const Color(0x4715110d),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: light ? const Color(0xfffff8e0) : const Color(0xff15110d),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          onHighlightChanged: (value) => setState(() => pressed = value),
          splashFactory: NoSplash.splashFactory,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: light ? ink : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: light ? muted : const Color(0xffc3c1c0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: yellow,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59f7cb2d),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/profile/${switch (icon) {
                        Icons.star_border => 'icon-star.svg',
                        Icons.shield_outlined => 'icon-shield.svg',
                        _ => 'rtab-publish.svg',
                      }}',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
                    ),
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

class DonorAccessGroup extends StatelessWidget {
  const DonorAccessGroup({super.key, required this.title, required this.items});
  final String title;
  final List<(String, IconData, String)> items;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1415110d),
          blurRadius: 28,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: items.length == 2 ? 240 : double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items) ...[
                if (item != items.first) const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push(item.$3),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xfff0eeea),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/profile/${switch (item.$2) {
                                  Icons.person_outline => 'icon-user.svg',
                                  Icons.credit_card => 'icon-card.svg',
                                  Icons.receipt_long_outlined => 'icon-billing.svg',
                                  Icons.access_time => 'icon-clock.svg',
                                  Icons.favorite_border => 'icon-heart.svg',
                                  _ => 'icon-user.svg',
                                }}',
                                width: 22,
                                height: 22,
                                colorFilter: const ColorFilter.mode(
                                  ink,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff5c5650),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class ProfileFrame extends StatelessWidget {
  const ProfileFrame({
    super.key,
    required this.title,
    required this.children,
    this.back = false,
    this.rescuerOverview = false,
    this.showNotifications = true,
    this.rescuerSettings = false,
  });
  final String title;
  final List<Widget> children;
  final bool back, rescuerOverview, showNotifications, rescuerSettings;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: rescuerSettings,
    appBar: rescuerOverview
        ? null
        : AppBar(
            automaticallyImplyLeading: false,
            centerTitle: rescuerSettings,
            toolbarHeight: rescuerSettings ? 68 : kToolbarHeight,
            backgroundColor: rescuerSettings ? Colors.transparent : null,
            surfaceTintColor: rescuerSettings ? Colors.transparent : null,
            elevation: rescuerSettings ? 0 : null,
            scrolledUnderElevation: rescuerSettings ? 0 : null,
            flexibleSpace: rescuerSettings
                ? ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: const ColoredBox(
                        color: Color(0xf5ffffff),
                        child: SizedBox.expand(),
                      ),
                    ),
                  )
                : null,
            leadingWidth: rescuerSettings ? 62 : null,
            shape: rescuerSettings
                ? const Border(bottom: BorderSide(color: Color(0xffe3e4ed)))
                : null,
            leading: back
                ? Padding(
                    padding: EdgeInsets.only(left: rescuerSettings ? 14 : 0),
                    child: IconButton(
                      tooltip: 'Regresar',
                      icon: rescuerSettings
                          ? SvgPicture.asset(
                              'assets/profile/back.svg',
                              width: 20,
                              height: 20,
                            )
                          : const Icon(Icons.arrow_back),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/profile'),
                    ),
                  )
                : null,
            title: Text(
              title,
              style: rescuerSettings
                  ? const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: -.36,
                      color: Color(0xff151423),
                    )
                  : Theme.of(context).textTheme.titleLarge,
            ),
            actions: [
              if (showNotifications)
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_none),
                ),
            ],
          ),
    bottomNavigationBar: const CommunityNav(4),
    body: SafeArea(
      top: rescuerOverview,
      child: ListView(
        padding: rescuerOverview
            ? const EdgeInsets.fromLTRB(16, 20, 16, 88)
            : rescuerSettings
            ? EdgeInsets.fromLTRB(
                16,
                88 + MediaQuery.paddingOf(context).top,
                16,
                32,
              )
            : const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (rescuerOverview) ...[
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  height: 1.25,
                  letterSpacing: -.48,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          ...children,
        ],
      ),
    ),
  );
}

class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.title,
    required this.icon,
    required this.path,
    this.subtitle,
    this.count,
  });
  final String title, path;
  final String? subtitle;
  final int? count;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null) Text('$count'),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(path),
      ),
    ),
  );
}

class SavedPetsRow extends ConsumerWidget {
  const SavedPetsRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LiveSection<DataPage<Adoption>>(
        tables: const ['dopmi_favorites'],
        load: () =>
            ref.read(communityRepositoryProvider).catalog({'saved': true}, 1),
        builder: (data, _) => ProfileRow(
          title: 'Mascotas guardadas',
          icon: Icons.bookmark_border,
          path: '/saved',
          count: data.total,
        ),
      );
}

class SavedRescuersRow extends ConsumerWidget {
  const SavedRescuersRow({super.key, this.referenceStyle = false});
  final bool referenceStyle;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LiveSection<DataPage<SavedEntry>>(
        tables: const ['dopmi_saved_rescuers'],
        load: () => ref.read(communityRepositoryProvider).savedRescuers(1),
        builder: (data, _) => referenceStyle
            ? RescuerNavigationRow(
                title: 'Rescatistas guardados',
                icon: 'icon-bookmark',
                path: '/saved?kind=rescuer',
                count: data.total,
              )
            : ProfileRow(
                title: 'Rescatistas guardados',
                icon: Icons.bookmark_border,
                path: '/saved?kind=rescuer',
                count: data.total,
              ),
      );
}

class GuardianMembership extends ConsumerStatefulWidget {
  const GuardianMembership({super.key});
  @override
  ConsumerState<GuardianMembership> createState() => _GuardianMembershipState();
}

class _GuardianMembershipState extends ConsumerState<GuardianMembership> {
  Future<Json>? state;
  Future<Json> load() async => ref.read(guardianRepositoryProvider).state();
  @override
  void initState() {
    super.initState();
    if (ref.read(guardianEnabledProvider)) {
      state = load();
    }
  }

  @override
  Widget build(BuildContext context) => state == null
      ? const Text('Miembro de la Comunidad')
      : FutureBuilder<Json>(
          future: state,
          builder: (context, result) => Text(
            result.data?['plan']?['status'] == 'active'
                ? 'Guardián'
                : 'Miembro de la Comunidad',
          ),
        );
}

class ProfileDonationLog extends ConsumerStatefulWidget {
  const ProfileDonationLog({super.key});
  @override
  ConsumerState<ProfileDonationLog> createState() => _ProfileDonationLogState();
}

class _ProfileDonationLogState extends ConsumerState<ProfileDonationLog> {
  late Future<DataPage<Json>> data;
  Future<DataPage<Json>> load() async =>
      await ref.read(profilePaymentHistoryProvider)();
  @override
  void initState() {
    super.initState();
    data = load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DataPage<Json>>(
    future: data,
    builder: (context, result) {
      if (result.hasError) {
        return Column(
          children: [
            const Text('No pudimos cargar tus aportaciones.'),
            TextButton(
              onPressed: () => setState(() => data = load()),
              child: const Text('Reintentar historial'),
            ),
          ],
        );
      }
      if (!result.hasData) {
        return const LinearProgressIndicator();
      }
      if (result.data!.items.isEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aquí verás tus aportaciones. Aún no hay movimientos.'),
          ),
        );
      }
      return Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (final row in result.data!.items.take(5))
              ListTile(
                title: Text(row['expense_title'] as String? ?? 'Aportación'),
                subtitle: Text(
                  paymentLabels[row['payment_status']] ?? 'En revisión',
                ),
                trailing: Text(
                  r'$' +
                      ((row['gross_cents'] as num? ?? 0) / 100).toStringAsFixed(
                        2,
                      ),
                ),
                onTap: () => context.push('/payments'),
              ),
          ],
        ),
      );
    },
  );
}

class RescuerSettingsModeSwitch extends ConsumerStatefulWidget {
  const RescuerSettingsModeSwitch({super.key});
  @override
  ConsumerState<RescuerSettingsModeSwitch> createState() =>
      _RescuerSettingsModeSwitchState();
}

class _RescuerSettingsModeSwitchState
    extends ConsumerState<RescuerSettingsModeSwitch> {
  bool busy = false;
  String? error;
  Future<void> changeMode() async {
    if (busy) return;
    final owner = ref.read(identityControllerProvider).identity?.id;
    if (owner == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await ref
          .read(identityRepositoryProvider)
          .setExperience('donor');
      if (!mounted ||
          ref.read(identityControllerProvider).identity?.id != owner) {
        return;
      }
      ref.read(experienceProvider).applyProfile(next);
      context.go('/adoptions');
    } catch (cause) {
      if (mounted &&
          ref.read(identityControllerProvider).identity?.id == owner) {
        setState(() => error = identityError(cause));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error != null) Notice(error!, isError: true),
      RescuerDonorModeCard(
        settings: true,
        enabled:
            !busy && ref.watch(experienceProvider).profile?.status == 'active',
        onPressed: changeMode,
      ),
      if (busy)
        const LinearProgressIndicator(semanticsLabel: 'Cambiando experiencia'),
      const SizedBox(height: 10),
    ],
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(configProvider).versionLabel;
    Future<void> logout() async {
      try {
        await ref.read(identityControllerProvider).logout();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(identityError(e))));
        }
      }
    }

    if (ref.watch(experienceProvider).value == AccountExperience.rescuer) {
      return ProfileFrame(
        title: 'Configuración',
        back: true,
        showNotifications: false,
        rescuerSettings: true,
        children: [
          const RescuerSettingsVerification(),
          const RescuerSettingsModeSwitch(),
          const RescuerNavigationRow(
            standardSettings: true,
            title: 'Centro de ayuda',
            icon: 'icon-help',
            path: '/help',
          ),
          const SizedBox(height: 10),
          RescuerLogoutRow(onLogout: logout),
          TextButton(
            onPressed: () => context.push('/settings/account'),
            child: const Text('Cuenta y privacidad'),
          ),
        ],
      );
    }
    return ProfileFrame(
      title: 'Configuración',
      back: true,
      showNotifications: false,
      rescuerSettings: true,
      children: [
        const RescuerNavigationRow(
          standardSettings: true,
          title: 'Información básica',
          subtitle: 'Edita tu perfil y datos personales',
          icon: 'icon-user',
          path: '/basic-info',
        ),
        if (ref.watch(guardianEnabledProvider)) ...[
          const SizedBox(height: 12),
          const RescuerNavigationRow(
            standardSettings: true,
            title: 'Métodos de pago',
            subtitle: 'Administra tus tarjetas y métodos de pago',
            icon: 'icon-card',
            path: '/settings/payment-methods',
          ),
          const SizedBox(height: 12),
          const RescuerNavigationRow(
            standardSettings: true,
            title: 'Suscripción y pagos',
            subtitle: 'Consulta tu suscripción, pagos y facturación',
            icon: 'icon-billing',
            path: '/guardian',
          ),
        ],
        const SizedBox(height: 24),
        const _SettingsHeading('Ayuda'),
        const SizedBox(height: 12),
        const RescuerNavigationRow(
          standardSettings: true,
          title: 'Centro de ayuda',
          icon: 'icon-help',
          path: '/help',
        ),
        const SizedBox(height: 24),
        const _SettingsHeading('Cuenta'),
        const SizedBox(height: 12),
        const DonorSettingsModeSwitch(),
        const SizedBox(height: 12),
        const RescuerNavigationRow(
          standardSettings: true,
          title: 'Historial de aportaciones',
          icon: 'icon-billing',
          path: '/payments',
        ),
        const SizedBox(height: 12),
        const SavedRescuersRow(referenceStyle: true),
        const SizedBox(height: 12),
        const RescuerNavigationRow(
          standardSettings: true,
          title: 'Términos y privacidad',
          icon: 'icon-billing',
          path: '/terms',
        ),
        const SizedBox(height: 12),
        const RescuerNavigationRow(
          standardSettings: true,
          title: 'Privacidad y eliminación',
          subtitle: 'Medición, accesos vinculados y eliminación de cuenta',
          icon: 'icon-shield',
          path: '/account-privacy',
        ),
        const SizedBox(height: 12),
        RescuerLogoutRow(onLogout: logout),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Versión $version',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class DonorSettingsModeSwitch extends ConsumerStatefulWidget {
  const DonorSettingsModeSwitch({super.key});
  @override
  ConsumerState<DonorSettingsModeSwitch> createState() =>
      _DonorSettingsModeSwitchState();
}

class _DonorSettingsModeSwitchState
    extends ConsumerState<DonorSettingsModeSwitch> {
  bool busy = false;
  String? error;
  Future<void> changeMode() async {
    if (busy) return;
    final owner = ref.read(identityControllerProvider).identity?.id;
    if (owner == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await ref
          .read(identityRepositoryProvider)
          .setExperience('rescuer');
      if (!mounted ||
          ref.read(identityControllerProvider).identity?.id != owner) {
        return;
      }
      ref.read(experienceProvider).applyProfile(next);
      context.go('/rescuer');
    } catch (cause) {
      if (mounted &&
          ref.read(identityControllerProvider).identity?.id == owner) {
        setState(() => error = identityError(cause));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error != null) Notice(error!, isError: true),
      RescuerNavigationRow(
        standardSettings: true,
        key: const ValueKey('donor-settings-mode-switch'),
        title: 'Cambiar tipo de cuenta',
        subtitle: 'Ir a cuenta Rescatista',
        icon: 'icon-shield',
        path: '/rescuer',
        onPressed: changeMode,
        enabled:
            !busy && ref.watch(experienceProvider).profile?.status == 'active',
      ),
      if (busy)
        const LinearProgressIndicator(semanticsLabel: 'Cambiando experiencia'),
    ],
  );
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: Color(0xff15110d),
      ),
    ),
  );
}

class RescuerAccountOptionsScreen extends ConsumerWidget {
  const RescuerAccountOptionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ProfileFrame(
    title: 'Cuenta y privacidad',
    back: true,
    showNotifications: false,
    children: [
      const ProfileRow(
        title: 'Verificación',
        icon: Icons.shield_outlined,
        path: '/rescue/new?kind=verification',
      ),
      const ProfileRow(
        title: 'Editar perfil público',
        icon: Icons.edit_outlined,
        path: '/rescuer/profile/edit',
      ),
      if (ref.watch(identityControllerProvider).identity != null)
        ProfileRow(
          title: 'Ver mi perfil público',
          icon: Icons.public,
          path: '/people/${ref.watch(identityControllerProvider).identity!.id}',
        ),
      const ProfileRow(
        title: 'Mis publicaciones de adopción',
        icon: Icons.home_outlined,
        path: '/my-adoptions',
      ),
      const ProfileRow(
        title: 'Información básica',
        subtitle: 'Edita tu perfil y datos personales',
        icon: Icons.person_outline,
        path: '/basic-info',
      ),
      if (ref.watch(guardianEnabledProvider)) ...[
        const ProfileRow(
          title: 'Métodos de pago',
          subtitle: 'Administra tus tarjetas y métodos de pago',
          icon: Icons.credit_card,
          path: '/settings/payment-methods',
        ),
        const ProfileRow(
          title: 'Suscripción y pagos',
          subtitle: 'Consulta tu suscripción, pagos y facturación',
          icon: Icons.receipt_long_outlined,
          path: '/guardian',
        ),
      ],
      const ProfileRow(
        title: 'Historial de aportaciones',
        icon: Icons.history,
        path: '/payments',
      ),
      const ProfileRow(
        title: 'Términos y privacidad',
        icon: Icons.description_outlined,
        path: '/terms',
      ),
      const ProfileRow(
        title: 'Privacidad y eliminación',
        subtitle: 'Medición, accesos vinculados y eliminación de cuenta',
        icon: Icons.privacy_tip_outlined,
        path: '/account-privacy',
      ),
      const ProfileRow(
        title: 'Configurar pagos con Stripe',
        icon: Icons.account_balance_outlined,
        path: '/connect',
      ),
      Center(
        child: Text(
          'Versión ${ref.watch(configProvider).versionLabel}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => ProfileFrame(
    title: 'Centro de ayuda',
    back: true,
    children: [
      const ExpansionTile(
        title: Text('¿Cómo contacto por una adopción?'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Abre la mascota y confirma que deseas contactar. La conversación sólo es visible para sus participantes.',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('¿Qué gastos puedo apoyar?'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Gastos ya pagados, documentados y aprobados. Dopmi cobra una comisión del 2 % del aporte; también se descuentan los costos de Stripe.',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('¿Cuándo cobra Guardián?'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'El primer cobro ocurre al activar. Los siguientes son mensuales sólo cuando el neto puede asignarse completo. Un mes omitido no genera deuda.',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('¿Cómo cancelo mi apoyo mensual?'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'En Configuración abre Suscripción y pagos. Cancelar detiene ciclos futuros y conserva el historial del ciclo actual.',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('¿Cambiar de modo me verifica como rescatista?'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No. Cambiar de modo sólo cambia la experiencia. La verificación requiere enviar información y recibir la revisión del equipo.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text(
        '¿Necesitas más ayuda?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Escríbenos desde el correo de tu cuenta. No envíes contraseñas, códigos de acceso ni datos completos de tarjeta.',
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.mail_outline),
        label: const Text('Escribir a soporte@dopmi.org'),
        onPressed: () async {
          final opened = await launchUrl(
            Uri(
              scheme: 'mailto',
              path: 'soporte@dopmi.org',
              queryParameters: {'subject': 'Ayuda con Dopmi'},
            ),
          );
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No pudimos abrir tu correo. Escribe a soporte@dopmi.org.',
                ),
              ),
            );
          }
        },
      ),
    ],
  );
}
