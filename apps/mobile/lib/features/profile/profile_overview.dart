import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
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
    return ListenableBuilder(
      listenable: experience,
      builder: (context, _) {
        profile = experience.profile ?? profile;
        final rescuer = experience.value == AccountExperience.rescuer;
        return ProfileFrame(
          title: 'Perfil',
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
                ProfileRow(
                  title: 'Verificación y perfil público',
                  icon: Icons.verified_user_outlined,
                  path: '/rescuer',
                ),
                ProfileRow(
                  title: 'Mis casos',
                  icon: Icons.pets_outlined,
                  path: '/my-cases',
                ),
                ProfileRow(
                  title: 'Mis publicaciones de adopción',
                  icon: Icons.home_outlined,
                  path: '/my-adoptions',
                ),
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
                ProfileRow(
                  title: 'Mi impacto',
                  subtitle: 'Avances de casos que apoyaste',
                  icon: Icons.auto_stories_outlined,
                  path: '/impact',
                ),
              ],
              ProfileRow(
                title: 'Configuración',
                icon: Icons.settings_outlined,
                path: '/settings',
              ),
              const SizedBox(height: 18),
              if (error != null) Notice(error!, isError: true),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffe8e6e2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SwitchListTile.adaptive(
                  title: Text(
                    rescuer
                        ? 'Cambiar a modo donante'
                        : 'Cambiar a modo rescatista',
                  ),
                  subtitle: const Text('Cambia tu experiencia en la app'),
                  value: false,
                  onChanged: busy || profile!.status != 'active'
                      ? null
                      : (_) => switchMode(!rescuer),
                ),
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

class ProfileFrame extends StatelessWidget {
  const ProfileFrame({
    super.key,
    required this.title,
    required this.children,
    this.back = false,
  });
  final String title;
  final List<Widget> children;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      leading: back
          ? IconButton(
              tooltip: 'Regresar',
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            )
          : null,
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      actions: [
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    ),
    bottomNavigationBar: const CommunityNav(4),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: children,
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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ProfileFrame(
    title: 'Configuración',
    back: true,
    children: [
      const ProfileRow(
        title: 'Información básica',
        subtitle: 'Edita tu perfil y datos personales',
        icon: Icons.person_outline,
        path: '/profile/basic-info',
      ),
      if (ref.watch(guardianEnabledProvider)) ...[
        const ProfileRow(
          title: 'Método de pago de Guardián',
          subtitle: 'Consulta o cambia tu tarjeta',
          icon: Icons.credit_card,
          path: '/guardian',
        ),
        const ProfileRow(
          title: 'Suscripción y pagos',
          subtitle: 'Administra tu apoyo mensual',
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
        title: 'Centro de ayuda',
        icon: Icons.help_outline,
        path: '/help',
      ),
      const ProfileRow(
        title: 'Aviso de desarrollo',
        icon: Icons.description_outlined,
        path: '/terms',
      ),
      OutlinedButton(
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
        child: const Text('Cerrar sesión'),
      ),
    ],
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => const ProfileFrame(
    title: 'Centro de ayuda',
    back: true,
    children: [
      ExpansionTile(
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
      ExpansionTile(
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
      ExpansionTile(
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
      ExpansionTile(
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
      ExpansionTile(
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
    ],
  );
}

class PublishChoiceScreen extends StatelessWidget {
  const PublishChoiceScreen({super.key});
  @override
  Widget build(BuildContext context) => ProfileFrame(
    title: '¿Qué quieres publicar?',
    children: [
      const Text('Selecciona el tipo de publicación que deseas crear'),
      const SizedBox(height: 24),
      const ProfileRow(
        title: 'Dar en adopción',
        subtitle: 'Publica una mascota que esté lista para encontrar un hogar',
        icon: Icons.home_outlined,
        path: '/my-adoptions/new',
      ),
      const ProfileRow(
        title: 'Crear caso para recibir aportaciones',
        subtitle: 'El caso y los gastos requieren revisión. Para recibir aportaciones necesitas verificación.',
        icon: Icons.volunteer_activism_outlined,
        path: '/rescue/new?kind=case',
      ),
      TextButton(
        onPressed: () => context.go('/my-cases'),
        child: const Text('Cancelar'),
      ),
    ],
  );
}
