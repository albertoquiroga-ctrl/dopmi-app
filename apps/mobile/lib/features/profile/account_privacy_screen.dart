import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/measurement.dart';
import '../../core/ui.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';

class AccountPrivacyScreen extends ConsumerStatefulWidget {
  const AccountPrivacyScreen({super.key});

  @override
  ConsumerState<AccountPrivacyScreen> createState() =>
      _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends ConsumerState<AccountPrivacyScreen> {
  bool busy = false;
  String? error, message;

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
        content: SingleChildScrollView(
          child: Column(
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
                decoration: const InputDecoration(
                  labelText: 'Escribe ELIMINAR',
                ),
              ),
            ],
          ),
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
    final measurement = ref.watch(measurementControllerProvider);
    final config = ref.watch(configProvider);
    final linked = ref.read(identityRepositoryProvider).linkedProviders;
    return PageFrame(
      back: true,
      children: [
        const Heading(
          'Privacidad y cuenta',
          'Controla la medición, tus accesos vinculados y la eliminación de tu cuenta.',
          eyebrow: 'CONFIGURACIÓN',
        ),
        if (error != null) Notice(error!, isError: true),
        if (message != null) Notice(message!),
        TextButton(
          onPressed: () => context.push('/terms'),
          child: const Text('Términos y aviso de privacidad'),
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
        if (config.measurementTestEnabled &&
            measurement?.lastAnalyticsEvent != null) ...[
          const SizedBox(height: 4),
          Notice(
            measurement!.lastAnalyticsResult == 'aceptado_por_sdk'
                ? 'Prueba interna: Firebase aceptó ${measurement.lastAnalyticsEvent}.'
                : measurement.lastAnalyticsResult ==
                      'omitido_sin_consentimiento'
                ? 'Prueba interna: ${measurement.lastAnalyticsEvent} no se envió porque la analítica estaba apagada.'
                : 'Prueba interna: Firebase rechazó ${measurement.lastAnalyticsEvent} (${measurement.lastAnalyticsResult}).',
            isError: measurement.lastAnalyticsResult != 'aceptado_por_sdk',
          ),
        ],
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
        if (config.measurementTestEnabled &&
            measurement?.diagnosticsEnabled == true)
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => perform(() async {
                    await measurement!.diagnosticTest();
                    if (mounted) {
                      setState(
                        () => message =
                            'Enviamos el diagnóstico interno de prueba.',
                      );
                    }
                  }),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Enviar diagnóstico de prueba'),
          ),
        if ((config.googleEnabled && !linked.contains('google')) ||
            (config.appleNativeAvailable && !linked.contains('apple'))) ...[
          const SizedBox(height: 18),
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
                  : () => perform(() => repoLink(ref, 'google')),
              child: const Text('Vincular Google'),
            ),
          if (config.appleNativeAvailable && !linked.contains('apple'))
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => perform(() => repoLink(ref, 'apple')),
              child: const Text('Vincular Apple'),
            ),
        ],
        const SizedBox(height: 28),
        Text('Eliminar cuenta', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Puedes iniciar la eliminación desde la app. Este proceso no elimina tu cuenta externa de Google o Apple.',
        ),
        TextButton(
          onPressed: busy ? null : deleteAccount,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Eliminar mi cuenta'),
        ),
        if (busy) const LinearProgressIndicator(semanticsLabel: 'Procesando'),
      ],
    );
  }
}

Future<void> repoLink(WidgetRef ref, String provider) =>
    ref.read(identityRepositoryProvider).linkProvider(provider);
