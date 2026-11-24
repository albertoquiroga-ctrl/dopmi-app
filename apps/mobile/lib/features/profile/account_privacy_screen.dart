import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/android_rescuer_acquisition.dart';
import '../../core/ios_cpp_acquisition.dart';
import '../../core/measurement.dart';
import '../../core/meta_ads_measurement.dart';
import '../../core/ui.dart';
import '../adoption/swipe_tutorial_store.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../identity/experience_controller.dart';
import '../payments/contribution_layout.dart';
import 'meta_lifecycle_consent_gate.dart';

class AccountPrivacyScreen extends ConsumerStatefulWidget {
  const AccountPrivacyScreen({super.key});

  @override
  ConsumerState<AccountPrivacyScreen> createState() =>
      _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends ConsumerState<AccountPrivacyScreen> {
  final contentController = ScrollController();
  bool busy = false;
  String? error, message;

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  void revealNotice(String? owner) {
    if (error == null && message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !contentController.hasClients ||
          ModalRoute.of(context)?.isCurrent != true ||
          ref.read(identityRepositoryProvider).current?.id != owner ||
          (error == null && message == null)) {
        return;
      }
      // Mount the notice in the viewport so its live region can announce it.
      // Immediate positioning also respects reduced-motion preferences.
      contentController.jumpTo(0);
    });
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    final owner = ref.read(identityRepositoryProvider).current?.id;
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
      if (mounted) {
        setState(() => busy = false);
        revealNotice(owner);
      }
    }
  }

  Future<void> deleteAccount() async {
    final repo = ref.read(identityRepositoryProvider);
    final deletingActor = repo.current?.id;
    final passwordIdentity = repo.linkedProviders.contains('email');
    final socialProvider = repo.linkedProviders.contains('apple')
        ? 'apple'
        : repo.linkedProviders.contains('google')
        ? 'google'
        : null;
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final route = DialogRoute<bool>(
      context: context,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
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
    final approved = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(route);
    // Keep the field controllers alive until the dialog's exit animation and
    // overlay disposal complete, including an immediate confirmation/cancel.
    await route.completed;
    if (!mounted) {
      password.dispose();
      confirmation.dispose();
      return;
    }
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
      if (state['status'] == 'completado' &&
          state['auth_cleanup'] != 'pending') {
        await ref.read(identityControllerProvider).logout();
        if (repo is SupabaseIdentityRepository && deletingActor != null) {
          try {
            await repo.preferences.remove(
              swipeTutorialPreferenceKey(repo.config, deletingActor),
            );
          } catch (_) {
            // Auth deletion already succeeded. Local presentation cleanup
            // must not misreport that irreversible result as a login error.
          }
        }
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

  Widget metaAdsControl(
    MetaAdsMeasurement measurement, {
    required bool captureAvailable,
  }) {
    final identity = ref.watch(identityControllerProvider);
    return ListenableBuilder(
      listenable: identity,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) {
          final owner = identity.identity?.id;
          if (identity.loading || identity.error != null || owner == null) {
            return const SizedBox.shrink();
          }
          final preference = ref.watch(metaAdsPreferenceProvider(owner));
          final granted = preference.value == true;
          if (!captureAvailable && !granted) return const SizedBox.shrink();
          return Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Medición de anuncios con Meta'),
                subtitle: captureAvailable
                    ? const Text(
                        'Si la activas, Dopmi comparte con Meta tu identificador de publicidad de Android y las versiones de la app y de Android. Comparte también el evento y la hora de tu primer mensaje como adoptante o de tu primera ficha nueva enviada a revisión desde que la activaste. Meta usa estos datos para medir y optimizar anuncios. Puedes desactivarla aquí en cualquier momento.',
                      )
                    : const Text(
                        'Tu cuenta tiene esta preferencia activa para Dopmi en Android. Puedes desactivarla aquí.',
                      ),
                value: granted,
                onChanged: busy || (!granted && preference.asData == null)
                    ? null
                    : (value) {
                        if (value && !captureAvailable) return;
                        perform(() async {
                          try {
                            if (await measurement.setPreference(owner, value) !=
                                value) {
                              throw StateError(
                                'No pudimos guardar la medición de anuncios.',
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              ref.invalidate(metaAdsPreferenceProvider(owner));
                            }
                          }
                        });
                      },
              ),
              if (preference.hasError)
                TextButton(
                  onPressed: () =>
                      ref.invalidate(metaAdsPreferenceProvider(owner)),
                  child: const Text(
                    'Reintentar consulta de medición de anuncios',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final measurement = ref.watch(measurementControllerProvider);
    final metaAds = ref.watch(metaAdsPreferenceServiceProvider);
    final metaAdsCaptureAvailable =
        ref.watch(metaAdsMeasurementProvider) != null;
    final config = ref.watch(configProvider);
    final linked = ref.read(identityRepositoryProvider).linkedProviders;
    final rescuer =
        ref.watch(experienceProvider).value == AccountExperience.rescuer;
    return ContributionFrame(
      title: 'Privacidad y cuenta',
      rescuer: rescuer,
      back: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: ListView(
        controller: contentController,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text(
            'Controla la medición, tus accesos vinculados y la eliminación de tu cuenta.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: rescuer ? const Color(0xff4f4e5c) : muted,
            ),
          ),
          const SizedBox(height: 20),
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
            subtitle: Text(
              'Comparte navegación y conversiones básicas. '
              '${supportsPlayInstallReferrer ? 'En Android, puede vincular la campaña de Google Play con tu primera ficha enviada y aprobada, tu primer saludo automático, tu primer mensaje enviado como adoptante y tu primera respuesta como rescatista. ' : ''}'
              '${supportsIosCppAcquisition ? 'En iPhone, puede vincular la página de App Store desde la que abriste Dopmi con tu primera ficha enviada y aprobada, tu primer saludo automático, tu primer mensaje enviado como adoptante y tu primera respuesta como rescatista. ' : ''}'
              'Los eventos definidos por Dopmi no incluyen el contenido de mensajes, documentos, ubicación, correo ni datos financieros. '
              'Firebase puede estimar una zona aproximada a partir de tu conexión. Puedes desactivarla sin perder las funciones de Dopmi.',
            ),
            value: measurement?.analyticsEnabled ?? false,
            onChanged: measurement == null || measurement.loading || busy
                ? null
                : (value) => perform(() => measurement.setAnalytics(value)),
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
          if (metaAds != null)
            metaAdsControl(metaAds, captureAvailable: metaAdsCaptureAvailable),
          const MetaLifecyclePrivacyControl(),
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
          Text(
            'Eliminar cuenta',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
      ),
    );
  }
}

Future<void> repoLink(WidgetRef ref, String provider) =>
    ref.read(identityRepositoryProvider).linkProvider(provider);
