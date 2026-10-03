import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../identity/identity_controller.dart';
import 'rescuer_profile_repository.dart';

String rescuerSocialDisplayValue(String field, String value) {
  final trimmed = value.trim();
  if (field != 'instagram_url') return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      uri.scheme != 'https' ||
      !['instagram.com', 'www.instagram.com'].contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return trimmed;
  }
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (segments.length != 1 ||
      !RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(segments.single)) {
    return trimmed;
  }
  return '@${segments.single}';
}

Future<bool?> editRescuerSocial(
  BuildContext context,
  Json profile,
  String field,
) => showGeneralDialog<bool>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Cerrar edición de red social',
  barrierColor: const Color(0xff15110d).withValues(alpha: .48),
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) =>
      RescuerSocialDialog(profile: profile, field: field),
);

class RescuerSocialDialog extends ConsumerStatefulWidget {
  const RescuerSocialDialog({
    super.key,
    required this.profile,
    required this.field,
  });
  final Json profile;
  final String field;
  @override
  ConsumerState<RescuerSocialDialog> createState() =>
      _RescuerSocialDialogState();
}

class _RescuerSocialDialogState extends ConsumerState<RescuerSocialDialog> {
  late final owner = widget.profile['owner_id'] as String?;
  bool get instagram => widget.field == 'instagram_url';
  String get network => instagram ? 'Instagram' : 'Facebook';
  late final input = TextEditingController(text: initialValue());
  final inputFocus = FocusNode();
  bool busy = false;
  String? error;
  String initialValue() => rescuerSocialDisplayValue(
    widget.field,
    widget.profile[widget.field] as String? ?? '',
  );

  String? normalized() {
    final value = input.text.trim();
    if (value.isEmpty) return null;
    if (instagram && RegExp(r'^@?[A-Za-z0-9._]{1,30}$').hasMatch(value)) {
      return 'https://www.instagram.com/${value.replaceFirst(RegExp(r'^@'), '')}';
    }
    final uri = Uri.tryParse(value);
    final host = instagram ? 'instagram.com' : 'facebook.com';
    if (uri == null ||
        uri.scheme != 'https' ||
        ![host, 'www.$host'].contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path.length < 2 ||
        value.length > 500) {
      return null;
    }
    return value;
  }

  bool owns(RescuerProfileRepository repo) =>
      owner != null &&
      repo.userId == owner &&
      ref.read(identityControllerProvider).identity?.id == owner;
  Future<void> save() async {
    final value = normalized();
    if (busy || value == null) return;
    final repo = ref.read(rescuerProfileRepositoryProvider);
    if (!owns(repo)) {
      setState(
        () => error = 'La sesión cambió. Cierra este diálogo para continuar.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.save({
        for (final key in [
          'display_name',
          'bio',
          'city',
          'region',
          'instagram_url',
          'facebook_url',
          'avatar_path',
        ])
          key: widget.profile[key] ?? '',
        widget.field: value,
      }, version: widget.profile['version'] as int?);
      if (!mounted || !owns(repo)) return;
      setState(() => busy = false);
      // Re-enable route dismissal after the write has completed.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !owns(repo)) return;
      Navigator.pop(context, true);
    } catch (cause) {
      if (mounted && owns(repo)) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    inputFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    inputFocus.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ref.watch(identityControllerProvider),
    builder: (context, _) => owns(ref.watch(rescuerProfileRepositoryProvider))
        ? content(context)
        : AlertDialog(
            title: const Text('La sesión cambió'),
            content: const Text(
              'Cierra este diálogo para continuar con tu cuenta actual.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
  );

  Widget content(BuildContext context) {
    final allowed = owns(ref.watch(rescuerProfileRepositoryProvider));
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffe3e4ed)),
    );
    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.sizeOf(context).height * .88,
                ),
                child: Material(
                  key: const ValueKey('rescuer-social-card'),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Editar $network',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 22,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff151423),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                instagram
                                    ? 'Usuario de Instagram'
                                    : 'Perfil de Facebook',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xff151423),
                                  height: 17 / 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  TextField(
                                    key: const ValueKey('rescuer-social-input'),
                                    controller: input,
                                    focusNode: inputFocus,
                                    cursorColor: const Color(0xff151423),
                                    autofocus: true,
                                    enabled: !busy && allowed,
                                    maxLength: 500,
                                    onChanged: (_) => setState(() {}),
                                    keyboardType: instagram
                                        ? TextInputType.text
                                        : TextInputType.url,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Color(0xff151423),
                                      height: 18 / 14,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      isDense: true,
                                      enabledBorder: inputBorder,
                                      focusedBorder: inputBorder,
                                      disabledBorder: inputBorder,
                                      hintText: instagram
                                          ? '@tuusuario'
                                          : 'https://www.facebook.com/tuperfil',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 13,
                                          ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xffe3e4ed),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (inputFocus.hasFocus)
                                    Positioned(
                                      left: -5,
                                      right: -5,
                                      top: -5,
                                      bottom: -5,
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0x4d7841f2),
                                              width: 3,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              19,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                instagram ? 'Usa el @ de tu cuenta pública.' : 'Usa el enlace https de tu página o perfil.',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  height: 1.55,
                                  color: Color(0xff4f4e5c),
                                ),
                              ),
                              if (!allowed || error != null) ...[
                                const SizedBox(height: 12),
                                Notice(
                                  !allowed
                                      ? 'La sesión cambió. Cierra este diálogo para continuar.'
                                      : error!,
                                  isError: true,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Opacity(
                                opacity:
                                    !busy && allowed && normalized() != null
                                    ? 1
                                    : .5,
                                child: FilledButton(
                                  onPressed:
                                      !busy && allowed && normalized() != null
                                      ? save
                                      : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xff7841f2),
                                    foregroundColor: const Color(0xfffbfbff),
                                    disabledBackgroundColor: const Color(
                                      0xff7841f2,
                                    ),
                                    disabledForegroundColor: const Color(
                                      0xfffbfbff,
                                    ),
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      height: 20 / 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(busy ? 'Guardando…' : 'Guardar'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                  foregroundColor: const Color(0xff151423),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xffe3e4ed),
                                  ),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Cerrar',
                            onPressed: busy
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
