import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/ui.dart';
import '../identity/identity_controller.dart';
import 'rescue_repository.dart';

class RescuerSealScreen extends ConsumerStatefulWidget {
  const RescuerSealScreen({super.key});

  static const path = '/rescuer/verification';

  @override
  ConsumerState<RescuerSealScreen> createState() => _RescuerSealScreenState();
}

class _RescuerSealScreenState extends ConsumerState<RescuerSealScreen>
    with WidgetsBindingObserver {
  RescuerSealStatus? _status;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  late final String? _owner;

  bool get _current =>
      mounted &&
      _owner != null &&
      ref.read(identityControllerProvider).identity?.id == _owner;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(identityControllerProvider).identity?.id;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_sending &&
        !_loading &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!_current || _sending) return;
    setState(() {
      _status = null;
      _error = null;
      _loading = true;
    });
    try {
      final status = await ref
          .read(rescueRepositoryProvider)
          .rescuerSealStatus();
      if (_current) setState(() => _status = status);
    } catch (_) {
      if (_current) {
        setState(() {
          _error = 'No pudimos consultar tu verificación. Intenta de nuevo.';
        });
      }
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final status = _status;
    if (_sending ||
        !_current ||
        status == null ||
        status.missing.isNotEmpty ||
        status.pending ||
        status.approved) {
      return;
    }
    final repository = ref.read(rescueRepositoryProvider);
    setState(() {
      _sending = true;
      _error = null;
    });
    RescuerSealStatus? result;
    var confirmedResponse = false;
    try {
      result = await repository.submitRescuerSeal();
      confirmedResponse = true;
    } catch (_) {
      // A timeout can follow a committed submission. Check before offering another send.
      if (_current) {
        try {
          result = await repository.rescuerSealStatus();
        } catch (_) {
          // On uncertainty we offer only a status read.
        }
      }
    }
    if (!_current) return;
    setState(() {
      _sending = false;
      _status = result;
      if (!confirmedResponse &&
          result?.pending != true &&
          result?.approved != true) {
        _error = result == null
            ? 'No pudimos confirmar el envío. Consulta el estado para continuar.'
            : 'No pudimos enviar tu solicitud. Intenta de nuevo.';
      }
    });
    if (result?.pending == true && context.canPop()) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Solicitud de verificación enviada')),
      );
      context.pop();
    }
  }

  void _close() {
    if (!_sending) {
      context.canPop() ? context.pop() : context.go('/profile');
    }
  }

  Future<void> _editProfile() async {
    await context.push<void>('/rescuer/profile/edit?seal=1');
    if (_current) await _load();
  }

  void _openArchive(String recordId) {
    context.push<void>(
      Uri(
        path: '/rescue/$recordId',
        queryParameters: const {'kind': 'verification', 'record': '1'},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) return const SizedBox.shrink();
    final status = _status;
    final archiveId = status?.verificationMethod == 'documents'
        ? status?.recordId
        : null;
    if (!_loading && status != null && !status.approved && !status.pending) {
      final hasGaps = status.missing.isNotEmpty;
      return PopScope(
        canPop: !_sending,
        child: VerificationIntroScreen(
          onContinue: _sending
              ? null
              : hasGaps
              ? _editProfile
              : _send,
          onLater: _sending ? null : _close,
          profileGaps: [
            for (final field in RescuerSealStatus.requiredFields.entries)
              if (status.missing.contains(field.key)) field.value,
          ],
          sending: _sending,
          feedback: status.needsCorrection ? status.feedback : '',
          onEdit: status.needsCorrection && !hasGaps ? _editProfile : null,
          onHistory: archiveId != null && !_sending
              ? () => _openArchive(archiveId)
              : null,
          error: _error,
        ),
      );
    }
    return _VerificationDialog(
      onClose: _close,
      children: [
        _VerificationTitle(
          _loading || status == null
              ? 'Verificación Dopmi'
              : status.approved
              ? 'Cuenta verificada'
              : 'Verificación en proceso',
          iconName: status?.pending == true
              ? 'icon-clock.svg'
              : 'icon-shield.svg',
        ),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Consultando estado de verificación',
            ),
          )
        else if (status == null) ...[
          Notice(
            _error ?? 'No pudimos consultar tu verificación.',
            isError: true,
          ),
          FilledButton(
            onPressed: _load,
            child: const Text('Volver a intentar'),
          ),
        ] else ...[
          Text(
            status.approved
                ? 'Tu perfil público y tus publicaciones pueden mostrar el sello Dopmi.'
                : 'El equipo de Dopmi está revisando tu información. Te avisaremos cuando responda.',
            style: _body,
          ),
          if (archiveId != null)
            TextButton(
              onPressed: () => _openArchive(archiveId),
              child: const Text('Consultar expediente'),
            ),
        ],
        OutlinedButton(onPressed: _close, child: const Text('Cerrar')),
      ],
    );
  }
}

const _body = TextStyle(fontSize: 14, height: 1.5, color: DopmiTokens.muted);
const _heading = TextStyle(
  color: DopmiTokens.ink,
  fontSize: 16,
  height: 1.25,
  fontWeight: FontWeight.w700,
);

class VerificationIntroScreen extends StatelessWidget {
  const VerificationIntroScreen({
    super.key,
    required this.onContinue,
    required this.onLater,
    this.profileGaps = const [],
    this.sending = false,
    this.feedback = '',
    this.onEdit,
    this.onHistory,
    this.error,
  });

  final VoidCallback? onContinue, onLater, onEdit, onHistory;
  final List<String> profileGaps;
  final bool sending;
  final String feedback;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasGaps = profileGaps.isNotEmpty;
    return _VerificationDialog(
      onClose: onLater,
      children: [
        _VerificationTitle(
          hasGaps ? 'Verifica tu cuenta' : '¿Enviar solicitud de verificación?',
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: DopmiTokens.surface,
            border: Border.all(color: DopmiTokens.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasGaps
                      ? 'Confirma tu identidad y experiencia como rescatista'
                      : 'Verifica tu cuenta',
                  style: _heading,
                ),
                const SizedBox(height: 4),
                const Text(
                  'El equipo de Dopmi revisará los datos de tu perfil. Si aprueba tu solicitud, el sello aparecerá en tu perfil y en tus publicaciones.',
                  style: _body,
                ),
              ],
            ),
          ),
        ),
        if (feedback.isNotEmpty) Notice(feedback),
        if (hasGaps) ...[
          const Text('Completa tu info en tu perfil:', style: _heading),
          for (final gap in profileGaps)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: _VerificationIcon('check-circle.svg', size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    gap,
                    style: _body.copyWith(
                      color: DopmiTokens.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ] else ...[
          const Text('Refugios, fundaciones y centros', style: _heading),
          const Text(
            'Si representas a un refugio, fundación o centro de bienestar animal, el sello ayuda a que los adoptantes reconozcan a tu organización.',
            style: _body,
          ),
        ],
        if (error != null) Notice(error!, isError: true),
        FilledButton(
          onPressed: onContinue,
          child: Text(
            sending
                ? 'Enviando solicitud…'
                : hasGaps
                ? 'Completar mi información'
                : 'Enviar solicitud',
            textAlign: TextAlign.center,
          ),
        ),
        if (onEdit != null)
          OutlinedButton(
            onPressed: sending ? null : onEdit,
            child: const Text('Editar perfil'),
          ),
        OutlinedButton(
          onPressed: onLater,
          child: Text(hasGaps ? 'Cerrar' : 'Ahora no'),
        ),
        if (onHistory != null)
          TextButton(
            onPressed: onHistory,
            child: const Text('Consultar expediente'),
          ),
      ],
    );
  }
}

class _VerificationTitle extends StatelessWidget {
  const _VerificationTitle(this.title, {this.iconName = 'icon-shield.svg'});

  final String title, iconName;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: DopmiTokens.sky,
        ),
        child: _VerificationIcon(iconName, size: 28),
      ),
      const SizedBox(height: 16),
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: _heading.copyWith(fontSize: 22),
        ),
      ),
    ],
  );
}

class _VerificationIcon extends StatelessWidget {
  const _VerificationIcon(this.name, {required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/profile/$name',
    width: size,
    height: size,
    colorFilter: const ColorFilter.mode(DopmiTokens.ink, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

class _VerificationDialog extends StatelessWidget {
  const _VerificationDialog({required this.onClose, required this.children});

  final VoidCallback? onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: DopmiTokens.surface,
        elevation: 0,
        child: Theme(
          data: theme.copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: DopmiTokens.orangeButton,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: DopmiTokens.ink,
                minimumSize: const Size(48, 48),
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
              ),
            ),
          ),
          child: SizedBox(
            width: 340,
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: children,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: onClose,
                    tooltip: 'Cerrar',
                    style:
                        IconButton.styleFrom(
                          splashFactory: NoSplash.splashFactory,
                        ).copyWith(
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                        ),
                    icon: const Icon(Icons.close, color: DopmiTokens.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
