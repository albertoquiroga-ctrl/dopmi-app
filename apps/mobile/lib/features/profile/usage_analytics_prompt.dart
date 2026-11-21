import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../identity/auth_ui.dart';

/// A preselected control is only a proposed choice. The caller owns consent
/// persistence and collection; this screen never changes either on its own.
class UsageAnalyticsPrompt extends StatefulWidget {
  const UsageAnalyticsPrompt({
    super.key,
    required this.onConfirm,
    required this.onPrivacy,
  });

  final Future<void> Function(bool) onConfirm;
  final VoidCallback onPrivacy;

  @override
  State<UsageAnalyticsPrompt> createState() => _UsageAnalyticsPromptState();
}

class _UsageAnalyticsPromptState extends State<UsageAnalyticsPrompt> {
  bool selected = true;
  bool saving = false;
  bool saved = false;
  String? error;

  bool get busy => saving || saved;

  Future<void> confirm(bool value) async {
    if (busy) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onConfirm(value);
      if (mounted) setState(() => saved = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'No pudimos guardar tu elección. Inténtalo de nuevo o '
              'continúa sin analítica.';
        });
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
              'Tú decides qué compartes',
              'La analítica es opcional. Dopmi funciona igual si la desactivas.',
            ),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: const Text('Analítica de uso'),
                subtitle: Text(
                  selected
                      ? 'Se activa sólo al guardar tu elección.'
                      : 'La analítica permanecerá apagada.',
                ),
                value: selected,
                onChanged: busy
                    ? null
                    : (value) => setState(() => selected = value),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Firebase y Dopmi miden navegación, conversiones y qué campañas '
              'llevan a primeras fichas y mensajes enviados. Estas métricas no '
              'incluyen el contenido de tus mensajes.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Firebase puede estimar una zona aproximada a partir de tu '
              'conexión. Puedes apagar la analítica en Cuenta y privacidad.',
            ),
            const SizedBox(height: 12),
            Text(
              'Los errores técnicos y la medición de publicaciones se eligen '
              'por separado.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: busy ? null : widget.onPrivacy,
              child: const Text('Leer el aviso de privacidad'),
            ),
            if (error != null) Notice(error!, isError: true),
            const SizedBox(height: 12),
            ActionButton(
              'Guardar elección y continuar',
              busy: saving,
              onPressed: busy ? null : () => confirm(selected),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: busy ? null : () => confirm(false),
              child: const Text('Continuar sin analítica'),
            ),
          ],
        ),
      ),
    ),
  );
}
