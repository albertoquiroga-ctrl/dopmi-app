import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../../core/measurement.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../identity/experience_controller.dart';

class BasicInfoScreen extends ConsumerStatefulWidget {
  const BasicInfoScreen({super.key});
  @override
  ConsumerState<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends ConsumerState<BasicInfoScreen> {
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
        ref.read(experienceProvider).applyProfile(result);
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
          .saveProfile(name: name.text, phone: phone.text, city: city.text);
      if (mounted) {
        ref.read(experienceProvider).applyProfile(result);
        setState(() {
          profile = result;
          message = 'Guardamos los cambios de tu perfil.';
        });
      }
    });
  }

  Future<void> deleteAccount() async {
    final repo = ref.read(identityRepositoryProvider);
    final passwordIdentity = repo.linkedProviders.contains('email');
    final socialProvider = repo.linkedProviders.contains('apple')
        ? 'apple'
        : repo.linkedProviders.contains('google')
        ? 'google'
        : null;
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar mi cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bloquearemos el acceso, retiraremos tus publicaciones y cancelaremos futuras renovaciones. La evidencia necesaria de pagos y disputas se conservará con acceso restringido.',
            ),
            const SizedBox(height: 16),
            if (passwordIdentity) ...[
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña para confirmar',
                ),
              ),
              const SizedBox(height: 12),
            ] else if (socialProvider != null) ...[
              Text(
                'Después de confirmar volveremos a validar tu acceso con ${socialProvider == 'apple' ? 'Apple' : 'Google'}.',
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: confirmation,
              decoration: const InputDecoration(labelText: 'Escribe ELIMINAR'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar cuenta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              confirmation.text.trim() == 'ELIMINAR',
            ),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (approved != true) {
      password.dispose();
      confirmation.dispose();
      return;
    }
    await perform(() async {
      if (passwordIdentity) {
        await repo.reauthenticate(password.text);
      } else if (socialProvider != null) {
        await repo.reauthenticateWithProvider(socialProvider);
      } else {
        throw const AuthException('recent_sign_in_required');
      }
      final state = await repo.requestAccountDeletion(const Uuid().v4());
      if (state['status'] == 'completado') {
        await ref.read(identityControllerProvider).logout();
        if (mounted) context.go('/login', extra: 'Tu cuenta fue eliminada.');
      } else if (mounted) {
        setState(
          () => message = 'Tu cuenta quedó bloqueada y la eliminación requiere atención de soporte.',
        );
      }
    });
    password.dispose();
    confirmation.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.read(identityControllerProvider).identity;
    final suspended = profile?.status == 'suspended';
    final accepted =
        profile?.termsVersion == currentTermsVersion &&
        profile?.privacyVersion == currentPrivacyVersion &&
        profile?.adultConfirmed == true;
    final measurement = ref.watch(measurementControllerProvider);
    final config = ref.watch(configProvider);
    final linked = ref.read(identityRepositoryProvider).linkedProviders;
    return PageFrame(
      back: true,
      bottomNavigationBar: const CommunityNav(4),
      children: [
        const Heading(
          'Información básica',
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
              'Antes de continuar, revisa y acepta los términos y el aviso de privacidad vigentes.',
            ),
            TextButton(
              onPressed: () => context.push('/terms'),
              child: const Text('Leer términos y privacidad'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: consent,
              onChanged: busy
                  ? null
                  : (value) => setState(() => consent = value ?? false),
              title: const Text(
                'Confirmo que tengo 18 años o más y acepto los términos y el aviso de privacidad.',
              ),
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
          for (final shortcut in const [
            ('Guardados', '/saved', Icons.favorite_border),
            ('Mis mensajes', '/messages', Icons.chat_bubble_outline),
            ('Mis publicaciones', '/my-adoptions', Icons.pets_outlined),
          ])
            ListTile(
              leading: Icon(shortcut.$3),
              title: Text(shortcut.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(shortcut.$2),
            ),
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
          child: const Text('Términos y privacidad'),
        ),
        const SizedBox(height: 12),
        Text(
          'Privacidad de medición',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Analítica de uso'),
          subtitle: const Text(
            'Comparte navegación y conversiones básicas. No incluye mensajes, documentos, ubicación, correo ni datos financieros.',
          ),
          value: measurement?.analyticsEnabled ?? false,
          onChanged: measurement == null || measurement.loading
              ? null
              : measurement.setAnalytics,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Diagnóstico de errores'),
          subtitle: const Text(
            'Envía fallos técnicos para ayudarnos a corregir la app. Puedes desactivarlo en cualquier momento.',
          ),
          value: measurement?.diagnosticsEnabled ?? false,
          onChanged: measurement == null || measurement.loading
              ? null
              : measurement.setDiagnostics,
        ),
        if ((config.googleEnabled && !linked.contains('google')) ||
            (config.appleNativeAvailable && !linked.contains('apple'))) ...[
          const SizedBox(height: 12),
          Text(
            'Accesos vinculados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Vincula un proveedor sólo desde esta sesión. Dopmi no combina cuentas por parecido de correo.',
          ),
          if (config.googleEnabled && !linked.contains('google'))
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => perform(
                      () => ref
                          .read(identityRepositoryProvider)
                          .linkProvider('google'),
                    ),
              child: const Text('Vincular Google'),
            ),
          if (config.appleNativeAvailable && !linked.contains('apple'))
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => perform(
                      () => ref
                          .read(identityRepositoryProvider)
                          .linkProvider('apple'),
                    ),
              child: const Text('Vincular Apple'),
            ),
        ],
        TextButton(
          onPressed: busy ? null : deleteAccount,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Eliminar mi cuenta'),
        ),
      ],
    );
  }
}
