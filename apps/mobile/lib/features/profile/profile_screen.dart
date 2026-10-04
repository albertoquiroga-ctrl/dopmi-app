import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/measurement.dart';
import '../../core/reference_input_border.dart';
import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import 'account_photo_card.dart';
import 'account_photo_repository.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../identity/experience_controller.dart';
import '../identity/auth_ui.dart';

final accountPhotoPickerProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return picked?.readAsBytes();
  },
);

class BasicInfoScreen extends ConsumerStatefulWidget {
  const BasicInfoScreen({super.key});
  @override
  ConsumerState<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends ConsumerState<BasicInfoScreen>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      lastName = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      city = TextEditingController();
  Profile? profile;
  bool loading = true, busy = false;
  String mode = 'donor';
  String? error, message;
  Uint8List? photoBytes;
  String? photoUrl, photoPath, pendingPhotoPath, photoError;
  bool photoLoading = false, photoDirty = false;
  String? pendingEmail;
  Timer? savedTimer;
  bool showSaved = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    savedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    city.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        profile?.status == 'active' &&
        !busy &&
        !photoDirty) {
      unawaited(loadPhoto());
    }
  }

  Future<void> loadPhoto() async {
    if (photoLoading || profile?.status != 'active') return;
    setState(() {
      photoLoading = true;
      photoError = null;
    });
    try {
      final repo = ref.read(accountPhotoRepositoryProvider);
      final path = await repo.loadPath();
      final url = path == null ? null : await repo.signedUrl(path);
      if (!mounted ||
          ref.read(identityRepositoryProvider).current?.id != profile?.id) {
        return;
      }
      setState(() {
        photoPath = path;
        photoUrl = url;
        if (!photoDirty) photoBytes = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => photoError = 'No pudimos cargar tu foto de perfil.');
      }
    } finally {
      if (mounted) setState(() => photoLoading = false);
    }
  }

  Future<void> choosePhoto() async {
    final actor = profile?.id;
    await perform(() async {
      final bytes = await ref.read(accountPhotoPickerProvider)();
      if (bytes == null || !mounted) return;
      final prepared = await compute(prepareMedia, (
        MediaPurpose.accountAvatar,
        bytes,
      ));
      if (!mounted ||
          actor == null ||
          ref.read(identityRepositoryProvider).current?.id != actor) {
        return;
      }
      setState(() {
        photoBytes = prepared.bytes;
        photoDirty = true;
        pendingPhotoPath = null;
      });
    });
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ref.read(identityRepositoryProvider).loadProfile();
      final names = result.status == 'active'
          ? await ref.read(identityRepositoryProvider).loadAccountNames()
          : AccountNames(result.name, '', saved: false);
      if (mounted) {
        ref.read(experienceProvider).applyProfile(result);
        setState(() {
          profile = result;
          name.text = names.firstName;
          lastName.text = names.lastName;
          email.text =
              ref.read(identityRepositoryProvider).current?.email ?? '';
          phone.text = result.phone;
          city.text = result.city;
          mode = result.mode;
        });
        if (result.status == 'active') unawaited(loadPhoto());
      }
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    savedTimer?.cancel();
    setState(() {
      showSaved = false;
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
          .saveAccountNames(
            firstName: name.text,
            lastName: lastName.text,
            phone: phone.text,
            city: city.text,
          );
      if (photoDirty) {
        if (ref.read(identityRepositoryProvider).current?.id != result.id) {
          throw StateError('profile_owner_changed');
        }
        final photos = ref.read(accountPhotoRepositoryProvider);
        pendingPhotoPath ??= await photos.uploadPhoto(photoBytes!);
        await photos.savePath(pendingPhotoPath);
        if (!mounted ||
            ref.read(identityRepositoryProvider).current?.id != result.id) {
          return;
        }
        photoPath = pendingPhotoPath;
        pendingPhotoPath = null;
        photoDirty = false;
      }
      if (mounted) {
        final identities = ref.read(identityRepositoryProvider);
        if (identities.current?.id != result.id) {
          throw StateError('profile_owner_changed');
        }
        final targetEmail = email.text.trim();
        if (targetEmail.toLowerCase() !=
                identities.current?.email.toLowerCase() &&
            targetEmail.toLowerCase() != pendingEmail?.toLowerCase()) {
          final status = await identities.changeEmail(targetEmail);
          if (!mounted || identities.current?.id != result.id) return;
          pendingEmail = status == EmailChangeStatus.pendingConfirmation
              ? targetEmail
              : null;
        }
        ref.read(experienceProvider).applyProfile(result);
        setState(() {
          profile = result;
          showSaved = pendingEmail == null;
          message = pendingEmail == null ? null : 'Guardamos tu perfil. Revisa los correos de confirmación para completar el cambio de correo electrónico.';
        });
        if (showSaved) {
          savedTimer = Timer(const Duration(milliseconds: 2600), () {
            if (mounted) setState(() => showSaved = false);
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suspended = profile?.status == 'suspended';
    final large = MediaQuery.textScalerOf(context).scale(18) > 25;
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: large
            ? MediaQuery.textScalerOf(context).scale(18) * 2.6 + 16
            : 67,
        title: Text(
          'Información básica',
          maxLines: large ? 3 : 1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            height: 1.25,
            letterSpacing: -0.36,
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            tooltip: 'Volver',
            style: IconButton.styleFrom(overlayColor: Colors.transparent),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/settings'),
            icon: SvgPicture.asset(
              'assets/profile/back.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xffe6e2dd)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                if (loading)
                  const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando perfil',
                    ),
                  ),
                if (!loading && profile == null) ...[
                  Notice(
                    error ?? 'No pudimos cargar tu perfil.',
                    isError: true,
                  ),
                  ActionButton('Volver a intentar', onPressed: load),
                ],
                if (!loading && profile != null) ...[
                  if (suspended)
                    const Notice(
                      'Tu cuenta está suspendida. Contacta al equipo Dopmi para revisar tu acceso.',
                      isError: true,
                    ),
                  Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AccountPhotoCard(
                          name: name.text,
                          bytes: photoBytes,
                          url: photoUrl,
                          onEdit:
                              suspended ||
                                  busy ||
                                  photoLoading ||
                                  photoError != null
                              ? null
                              : choosePhoto,
                        ),
                        if (photoLoading)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Cargando foto de perfil',
                          ),
                        if (photoError != null) ...[
                          Notice(photoError!, isError: true),
                          TextButton(
                            onPressed: busy ? null : loadPhoto,
                            child: const Text('Volver a cargar foto'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _BasicInfoField(
                          label: 'Nombre',
                          child: TextFormField(
                            controller: name,
                            onChanged: (_) => setState(() {}),
                            enabled: !suspended && !busy,
                            maxLength: 80,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: ink,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14.8,
                              ),
                              constraints: BoxConstraints(minHeight: 44),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Escribe tu nombre.'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _BasicInfoField(
                          label: 'Apellido',
                          child: TextFormField(
                            controller: lastName,
                            enabled: !suspended && !busy,
                            maxLength: 80,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: ink,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14.8,
                              ),
                              constraints: BoxConstraints(minHeight: 44),
                            ),
                            validator: (_) =>
                                '${name.text.trim()} ${lastName.text.trim()}'
                                        .trim()
                                        .length >
                                    80
                                ? 'El nombre y apellido deben sumar hasta 80 caracteres.'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _BasicInfoField(
                          label: 'Correo electrónico',
                          child: TextFormField(
                            controller: email,
                            enabled: !suspended && !busy,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            maxLength: 254,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: ink,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14.8,
                              ),
                              constraints: BoxConstraints(minHeight: 44),
                            ),
                            validator: (value) =>
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch((value ?? '').trim())
                                ? null
                                : 'Escribe un correo electrónico válido.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _BasicInfoField(
                          label: 'Teléfono',
                          child: TextFormField(
                            controller: phone,
                            enabled: !suspended && !busy,
                            maxLength: 24,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: ink,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14.8,
                              ),
                              constraints: BoxConstraints(minHeight: 44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _BasicInfoField(
                          label: 'Ciudad / estado',
                          child: TextFormField(
                            controller: city,
                            enabled: !suspended && !busy,
                            maxLength: 100,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: ink,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14.8,
                              ),
                              constraints: BoxConstraints(minHeight: 44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (error != null) Notice(error!, isError: true),
                        if (message != null) Notice(message!),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              splashFactory: NoSplash.splashFactory,
                              overlayColor: Colors.transparent,
                              animationDuration: Duration.zero,
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            onPressed: suspended || busy ? null : save,
                            child: busy
                                ? Semantics(
                                    label: 'Procesando',
                                    child: const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Guardar cambios',
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (showSaved)
              const Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: _BasicInfoSavedToast(),
              ),
          ],
        ),
      ),
    );
  }
}

class _BasicInfoSavedToast extends StatelessWidget {
  const _BasicInfoSavedToast();
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e2dd)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2415110d),
            offset: Offset(0, 12),
            blurRadius: 32,
          ),
        ],
      ),
      child: Row(
        children: [
          SvgPicture.asset('assets/profile/check.svg', width: 16, height: 16),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Cambios guardados',
              style: TextStyle(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BasicInfoField extends StatelessWidget {
  const _BasicInfoField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: Theme.of(context).inputDecorationTheme
                .copyWith(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xffe6e2dd)),
                  ),
                  focusedBorder: const ReferenceInputBorder(
                    borderSide: BorderSide(color: Color(0xffe6e2dd)),
                  ),
                  focusedErrorBorder: ReferenceInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                ),
          ),
          child: child,
        ),
      ],
    ),
  );
}

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({
    super.key,
    this.onTerms,
    this.onPrivacy,
    this.onPrivacyNotice,
  });
  final VoidCallback? onTerms, onPrivacy, onPrivacyNotice;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool loading = true, busy = false, consent = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final profile = await ref.read(identityRepositoryProvider).loadProfile();
      if (!mounted) return;
      ref.read(experienceProvider).applyProfile(profile);
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> accept() async {
    if (busy || !consent) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(identityRepositoryProvider).acceptTerms();
      await ref.read(measurementControllerProvider)?.event('sign_up_completed');
      await load();
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    back: false,
    sheet: true,
    intent: ref.watch(experienceProvider).profile?.intent ?? 'adopt',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthHeading(
          'Antes de continuar',
          'Dopmi es exclusivamente para personas mayores de 18 años.',
          sheet: true,
          largeTitleFontSize: 24,
        ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (!loading) ...[
          const Notice(
            'Revisa y acepta los términos y el aviso de privacidad vigentes para usar Dopmi.',
          ),
          const SizedBox(height: 12),
          AuthConsentRow(
            value: consent,
            onChanged: busy ? null : (value) => setState(() => consent = value),
            onOpenTerms: widget.onTerms ?? () => context.push('/terms'),
            onOpenPrivacy:
                widget.onPrivacyNotice ?? () => context.push('/privacy-notice'),
          ),
          const SizedBox(height: 16),
          if (error != null) Notice(error!, isError: true),
          ActionButton(
            'Confirmar y continuar',
            busy: busy,
            onPressed: consent ? accept : null,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => ref.read(identityControllerProvider).logout(),
            child: const Text('Cerrar sesión'),
          ),
          TextButton(
            onPressed:
                widget.onPrivacy ?? () => context.push('/account-privacy'),
            child: const Text('Privacidad y eliminación de cuenta'),
          ),
        ],
        if (!loading && error != null)
          TextButton(onPressed: load, child: const Text('Volver a intentar')),
      ],
    ),
  );
}
