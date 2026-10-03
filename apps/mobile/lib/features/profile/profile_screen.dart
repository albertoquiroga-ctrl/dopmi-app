import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/measurement.dart';
import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import 'account_photo_card.dart';
import 'account_photo_repository.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../identity/experience_controller.dart';

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
      phone = TextEditingController(),
      city = TextEditingController();
  Profile? profile;
  bool loading = true, busy = false;
  String mode = 'donor';
  String? error, message;
  Uint8List? photoBytes;
  String? photoUrl, photoPath, pendingPhotoPath, photoError;
  bool photoLoading = false, photoDirty = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    lastName.dispose();
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
        ref.read(experienceProvider).applyProfile(result);
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
            height: 1.2,
            letterSpacing: 0,
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
          icon: SvgPicture.asset(
            'assets/profile/back.svg',
            width: 20,
            height: 20,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xffe6e2dd)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            if (loading)
              const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Cargando perfil',
                ),
              ),
            if (!loading && profile == null) ...[
              Notice(error ?? 'No pudimos cargar tu perfil.', isError: true),
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
                        decoration: const InputDecoration(counterText: ''),
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
                        decoration: const InputDecoration(counterText: ''),
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
                      child: InputDecorator(
                        decoration: const InputDecoration(),
                        child: SelectableText(
                          identity?.email ?? '',
                          style: const TextStyle(fontSize: 14, color: ink),
                        ),
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
                        decoration: const InputDecoration(counterText: ''),
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
                        decoration: const InputDecoration(counterText: ''),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (error != null) Notice(error!, isError: true),
                    if (message != null) Notice(message!),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
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
                            : const Text('Guardar cambios'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              for (final shortcut in const [
                ('Guardados', '/saved', Icons.favorite_border),
                ('Mis mensajes', '/messages', Icons.chat_bubble_outline),
                ('Mis publicaciones', '/my-adoptions', Icons.pets_outlined),
                (
                  'Rescatistas guardados',
                  '/saved?kind=rescuer',
                  Icons.bookmark_border,
                ),
                ('Mi impacto', '/impact', Icons.auto_stories_outlined),
                ('Configuración', '/settings', Icons.settings_outlined),
              ])
                ListTile(
                  leading: Icon(shortcut.$3),
                  title: Text(shortcut.$1),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(shortcut.$2),
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
          ],
        ),
      ),
    );
  }
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
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    ),
  );
}

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, this.onTerms, this.onPrivacy});
  final VoidCallback? onTerms, onPrivacy;

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
  Widget build(BuildContext context) => PageFrame(
    back: false,
    children: [
      const Heading(
        'Antes de continuar',
        'Dopmi es exclusivamente para personas mayores de 18 años.',
        eyebrow: 'TU CUENTA',
      ),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (!loading) ...[
        const Notice(
          'Revisa y acepta los términos y el aviso de privacidad vigentes para usar Dopmi.',
        ),
        TextButton(
          onPressed: widget.onTerms ?? () => context.push('/terms'),
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
          onPressed: widget.onPrivacy ?? () => context.push('/account-privacy'),
          child: const Text('Privacidad y eliminación de cuenta'),
        ),
      ],
      if (!loading && error != null)
        TextButton(onPressed: load, child: const Text('Volver a intentar')),
    ],
  );
}
