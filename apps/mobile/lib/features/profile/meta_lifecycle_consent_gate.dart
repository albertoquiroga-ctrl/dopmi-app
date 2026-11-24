import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/meta_lifecycle_notice.dart';
import '../../core/meta_lifecycle_measurement.dart';
import '../../core/meta_lifecycle_provider.dart';
import '../../core/ui.dart';
import '../identity/auth_ui.dart';

/// Keeps the router mounted and offers a separate device choice before login.
class MetaLifecycleConsentGate extends ConsumerStatefulWidget {
  const MetaLifecycleConsentGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MetaLifecycleConsentGate> createState() =>
      _MetaLifecycleConsentGateState();
}

class _MetaLifecycleConsentGateState
    extends ConsumerState<MetaLifecycleConsentGate> {
  bool skipped = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(metaLifecycleControllerProvider);
    if (controller == null) return widget.child;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (skipped || controller.loading || !controller.needsChoice) {
          return widget.child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(child: ExcludeSemantics(child: widget.child)),
            MetaLifecyclePrompt(
              onConfirm: (enabled) async {
                if (enabled) {
                  await controller.setConsent(true);
                  if (WidgetsBinding.instance.lifecycleState ==
                      AppLifecycleState.resumed) {
                    unawaited(controller.foreground());
                  }
                } else {
                  try {
                    await controller.setConsent(false);
                  } catch (_) {
                    // OFF already cancels and revokes in RAM. A failed local
                    // write must never trap someone in optional measurement.
                  } finally {
                    if (mounted) setState(() => skipped = true);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class MetaLifecyclePrompt extends StatefulWidget {
  const MetaLifecyclePrompt({super.key, required this.onConfirm});
  final Future<void> Function(bool) onConfirm;

  @override
  State<MetaLifecyclePrompt> createState() => _MetaLifecyclePromptState();
}

class _MetaLifecyclePromptState extends State<MetaLifecyclePrompt> {
  bool saving = false, saved = false, noticeVisible = false;
  String? error;

  Future<void> confirm(bool enabled) async {
    if (saving || saved) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onConfirm(enabled);
      if (mounted) setState(() => saved = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No pudimos guardar tu elección. Intenta de nuevo o continúa sin activar.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    back: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Heading(
              'Ayúdanos a medir los anuncios',
              'Tú decides. Dopmi funciona igual si continúas sin activar esta medición.',
            ),
            Text(
              'Instalaciones y aperturas con Meta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(metaLifecyclePurpose),
            const SizedBox(height: 12),
            const Text(
              'Esta elección corresponde a este dispositivo. Puedes cambiarla '
              'en Cuenta y privacidad. Analítica de uso y los eventos de '
              'adopción con Meta se eligen por separado.',
            ),
            TextButton(
              onPressed: saving || saved
                  ? null
                  : () => setState(() => noticeVisible = !noticeVisible),
              child: const Text('Leer el aviso de esta medición'),
            ),
            if (noticeVisible) const Text(metaLifecycleNotice),
            if (error != null) Notice(error!, isError: true),
            const SizedBox(height: 16),
            ActionButton(
              'Permitir medición de anuncios',
              busy: saving,
              onPressed: saving || saved ? null : () => confirm(true),
            ),
            TextButton(
              onPressed: saving || saved ? null : () => confirm(false),
              child: const Text('Continuar sin activar'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Revokes this device permission without changing the account CAPI preference.
class MetaLifecyclePrivacyControl extends ConsumerStatefulWidget {
  const MetaLifecyclePrivacyControl({super.key});

  @override
  ConsumerState<MetaLifecyclePrivacyControl> createState() =>
      _MetaLifecyclePrivacyControlState();
}

class _MetaLifecyclePrivacyControlState
    extends ConsumerState<MetaLifecyclePrivacyControl> {
  bool busy = false, noticeVisible = false;
  String? error;

  Future<void> save(MetaLifecycleController controller, bool enabled) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await controller.setConsent(enabled);
      if (enabled &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(controller.foreground());
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = enabled
              ? 'No pudimos guardar esta elección. La medición sigue apagada.'
              : 'La medición se apagó para esta sesión, pero no pudimos guardar la elección. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(metaLifecycleControllerProvider);
    if (controller == null || (!controller.available && error == null)) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Instalaciones y aperturas con Meta'),
            subtitle: const Text(
              '$metaLifecyclePurpose Puedes apagarla aquí; la preferencia '
              'de los eventos de adopción con Meta se controla por separado.',
            ),
            value: controller.consent,
            onChanged:
                busy ||
                    controller.loading ||
                    (!controller.available && !controller.consent)
                ? null
                : (enabled) => save(controller, enabled),
          ),
          TextButton(
            onPressed: () => setState(() => noticeVisible = !noticeVisible),
            child: const Text('Aviso de instalaciones y aperturas'),
          ),
          if (noticeVisible) const Text(metaLifecycleNotice),
          if (error != null) Notice(error!, isError: true),
          if (error != null && !controller.consent)
            TextButton(
              onPressed: busy ? null : () => save(controller, false),
              child: const Text('Volver a guardar desactivado'),
            ),
        ],
      ),
    );
  }
}
