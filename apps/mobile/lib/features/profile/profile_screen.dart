import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../payments/guardian_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      city = TextEditingController();
  Profile? profile;
  bool loading = true, busy = false, consent = false;
  String mode = 'donor';
  String? error, message;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ref.read(identityRepositoryProvider).loadProfile();
      if (mounted) {
        setState(() {
          profile = result;
          name.text = result.name;
          phone.text = result.phone;
          city.text = result.city;
          mode = result.mode;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await action();
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    await perform(() async {
      final result = await ref
          .read(identityRepositoryProvider)
          .saveProfile(
            name: name.text,
            phone: phone.text,
            city: city.text,
            mode: mode,
          );
      if (mounted) {
        setState(() {
          profile = result;
          message = 'Guardamos los cambios de tu perfil.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.read(identityControllerProvider).identity;
    final suspended = profile?.status == 'suspended';
    final accepted = profile?.termsVersion == developmentTermsVersion;
    return PageFrame(
      back: false,
      bottomNavigationBar: const CommunityNav(4),
      children: [
        const Heading(
          'Tu perfil,\ntu forma de ayudar.',
          'Este es tu espacio en Dopmi.',
          eyebrow: 'MI CUENTA',
        ),
        if (loading)
          const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Cargando perfil'),
          ),
        if (!loading && profile == null) ...[
          Notice(error ?? 'No pudimos cargar tu perfil.', isError: true),
          ActionButton('Volver a intentar', onPressed: load),
        ],
        if (!loading && profile != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: yellow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 27,
                  backgroundColor: cream,
                  child: Icon(Icons.person_outline, color: ink, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile!.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        identity?.email ?? '',
                        style: const TextStyle(color: ink),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.verified_outlined, size: 16, color: ink),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Correo confirmado',
                              style: TextStyle(color: ink),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (suspended)
            const Notice(
              'Tu cuenta está suspendida. Contacta al equipo Dopmi para revisar tu acceso.',
              isError: true,
            ),
          if (!accepted && !suspended) ...[
            const Notice(
              'Antes de continuar, revisa el aviso de esta versión de desarrollo.',
            ),
            TextButton(
              onPressed: () => context.push('/terms'),
              child: const Text('Leer aviso de desarrollo'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: consent,
              onChanged: busy
                  ? null
                  : (value) => setState(() => consent = value ?? false),
              title: const Text('Leí y acepto el aviso de desarrollo.'),
            ),
            ActionButton(
              'Confirmar y continuar',
              busy: busy,
              onPressed: consent
                  ? () => perform(() async {
                      await ref.read(identityRepositoryProvider).acceptTerms();
                      await load();
                    })
                  : null,
            ),
            const SizedBox(height: 24),
          ],
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mis datos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: name,
                  enabled: !suspended && accepted && !busy,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Escribe tu nombre.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phone,
                  enabled: !suspended && accepted && !busy,
                  maxLength: 24,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: city,
                  enabled: !suspended && accepted && !busy,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad (opcional)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Mi experiencia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usa la misma cuenta para adoptar, ayudar o compartir tu labor como rescatista.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Quiero usar Dopmi como',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'donor',
                      child: Text('Donante / adoptante'),
                    ),
                    DropdownMenuItem(
                      value: 'rescuer',
                      child: Text('Rescatista'),
                    ),
                  ],
                  onChanged: suspended || !accepted || busy
                      ? null
                      : (value) => setState(() => mode = value!),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Elegir rescatista no equivale a obtener una verificación. Envía tus documentos al equipo desde tu espacio de rescates.',
                ),
                TextButton.icon(
                  onPressed: suspended || !accepted
                      ? null
                      : () => context.push('/rescuer'),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Verificación, casos y gastos'),
                ),
                TextButton.icon(
                  onPressed: suspended || !accepted
                      ? null
                      : () => context.push('/payments'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Mis aportaciones y cobros'),
                ),
                if (ref.watch(guardianEnabledProvider))
                  TextButton.icon(
                    onPressed: () => context.push('/guardian'),
                    icon: const Icon(Icons.favorite_outline),
                    label: const Text('Mi plan Guardián'),
                  ),
                if (error != null) Notice(error!, isError: true),
                if (message != null) Notice(message!),
                const SizedBox(height: 24),
                ActionButton(
                  'Guardar cambios',
                  busy: busy,
                  onPressed: suspended || !accepted ? null : save,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => perform(
                  () => ref.read(identityControllerProvider).logout(),
                ),
          child: const Text('Cerrar sesión'),
        ),
        TextButton(
          onPressed: () => context.push('/terms'),
          child: const Text('Aviso de desarrollo'),
        ),
      ],
    );
  }
}
