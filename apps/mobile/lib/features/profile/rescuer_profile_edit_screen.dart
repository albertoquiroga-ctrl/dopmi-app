import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import '../adoption/community_repository.dart';
import 'rescuer_profile_repository.dart';
import 'phone_verification_repository.dart';
import 'rescuer_profile_preview.dart';
import '../identity/identity_controller.dart';

final publicProfilePhotoPickerProvider = Provider<Future<XFile?> Function()>((
  ref,
) {
  return () => ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 90,
    requestFullMetadata: false,
  );
});

class RescuerPublicProfileEditScreen extends ConsumerStatefulWidget {
  const RescuerPublicProfileEditScreen({super.key});
  @override
  ConsumerState<RescuerPublicProfileEditScreen> createState() =>
      _RescuerPublicProfileEditState();
}

class _RescuerPublicProfileEditState
    extends ConsumerState<RescuerPublicProfileEditScreen> {
  final name = TextEditingController();
  final bio = TextEditingController();
  final city = TextEditingController();
  final region = TextEditingController();
  final instagram = TextEditingController();
  final facebook = TextEditingController();
  final publicEmail = TextEditingController();
  final publicPhone = TextEditingController();
  final address = TextEditingController();
  final website = TextEditingController();
  bool contactConsent = false;
  Json? profile;
  Uint8List? avatarBytes;
  String? pendingAvatarPath;
  bool avatarDirty = false;
  String? avatarPath, error;
  bool loading = true, busy = false, loadFailed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    city.dispose();
    region.dispose();
    instagram.dispose();
    facebook.dispose();
    publicEmail.dispose();
    publicPhone.dispose();
    address.dispose();
    website.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadFailed = false;
      error = null;
    });
    try {
      final repo = ref.read(rescuerProfileRepositoryProvider);
      final owner = repo.userId;
      final value = await repo.load();
      if (!mounted || repo.userId != owner) return;
      profile = value;
      name.text = value?['display_name'] as String? ?? '';
      bio.text = value?['bio'] as String? ?? '';
      city.text = value?['city'] as String? ?? '';
      region.text = value?['region'] as String? ?? '';
      instagram.text = value?['instagram_url'] as String? ?? '';
      facebook.text = value?['facebook_url'] as String? ?? '';
      publicEmail.text = value?['public_email'] as String? ?? '';
      publicPhone.text = value?['public_phone'] as String? ?? '';
      address.text = value?['public_address'] as String? ?? '';
      website.text = value?['website_url'] as String? ?? '';
      contactConsent = value?['contact_consent'] == true;
      replaceAvatarPath(value?['avatar_path'] as String?);
    } catch (cause) {
      loadFailed = true;
      error = communityError(cause);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void replaceAvatarPath(String? path) {
    final previous = avatarPath;
    if (previous != null && previous != path) {
      ref
          .read(photoRuntimeProvider)
          .invalidate(
            PhotoRef(
              path: previous,
              purpose: MediaPurpose.rescuerAvatar,
              persistence: PhotoPersistence.ordinary,
              sign: () => ref
                  .read(rescuerProfileRepositoryProvider)
                  .avatarUrl(previous),
            ),
            removeDisk: true,
          )
          .ignore();
    }
    avatarPath = path;
  }

  Widget avatarFallback() => Center(
    child: name.text.trim().isEmpty
        ? const Icon(Icons.person_outline, color: purple)
        : Text(
            name.text.trim().characters.first.toUpperCase(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: purple,
            ),
          ),
  );
  Json payload({String? avatarPath}) => {
    'display_name': name.text.trim(),
    'bio': bio.text.trim(),
    'city': city.text.trim(),
    'region': region.text.trim(),
    'instagram_url': instagram.text.trim(),
    'facebook_url': facebook.text.trim(),
    'public_email': publicEmail.text.trim(),
    'public_phone': publicPhone.text.trim(),
    'public_address': address.text.trim(),
    'website_url': website.text.trim(),
    'contact_consent': contactConsent,
    'avatar_path': avatarPath ?? profile?['avatar_path'] ?? '',
  };

  Future<bool> save({bool announce = true}) async {
    if (busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(rescuerProfileRepositoryProvider);
      final owner = repo.userId;
      if (owner == null) {
        throw StateError('Inicia sesión para guardar tu perfil.');
      }
      // Profile Storage requires an owned row. Create the draft during the
      // explicit save before uploading the first selected avatar.
      if (profile == null && avatarDirty && avatarBytes != null) {
        final created = await repo.save(payload(avatarPath: ''), version: null);
        if (!mounted || repo.userId != owner) return false;
        profile = created;
      }
      if (avatarDirty && avatarBytes != null && pendingAvatarPath == null) {
        final path = await repo.uploadAvatar(avatarBytes!);
        if (!mounted || repo.userId != owner) return false;
        pendingAvatarPath = path;
      }
      final saved = await repo.save(
        payload(avatarPath: pendingAvatarPath),
        version: profile?['version'] as int?,
      );
      if (!mounted || repo.userId != owner) return false;
      profile = saved;
      replaceAvatarPath(saved['avatar_path'] as String?);
      avatarDirty = false;
      pendingAvatarPath = null;
      if (mounted && announce) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Guardamos tu borrador.')));
      }
      return true;
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickAvatar() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(rescuerProfileRepositoryProvider);
      final owner = repo.userId;
      if (owner == null) {
        throw StateError('Inicia sesión para cambiar tu foto.');
      }
      final selected = await ref.read(publicProfilePhotoPickerProvider)();
      if (selected == null || !mounted || repo.userId != owner) return;
      final bytes = await selected.readAsBytes();
      if (!mounted || repo.userId != owner) return;
      avatarBytes = bytes;
      avatarDirty = true;
      pendingAvatarPath = null;
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transition(String action) async {
    if (profile == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(rescuerProfileRepositoryProvider);
      final owner = repo.userId;
      final next = await repo.transition(profile!['version'] as int, action);
      if (!mounted || repo.userId != owner) return;
      profile = next;
      if (action == 'revoke_contacts') contactConsent = false;
      if (mounted && action == 'submit') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enviamos tu perfil a revisión.')),
        );
      }
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void leaveEditor() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleAvatarPath = avatarPath;
    final status = profile?['status'] as String? ?? 'draft';
    final editable = [
      'draft',
      'changes_requested',
      'rejected',
      'published',
    ].contains(status);
    final large = MediaQuery.textScalerOf(context).scale(18) > 25;
    final screen = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: ink,
          ),
        ),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: leaveEditor,
          icon: SvgPicture.asset(
            'assets/profile/back.svg',
            width: 20,
            height: 20,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xffe3e4ed)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const Text(
              'Tus cambios públicos se revisan antes de publicarse. Tu identidad verificada se conserva. Elige por separado los contactos que quieres compartir.',
              style: TextStyle(fontSize: 14, height: 1.55, color: ink),
            ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (!loading && loadFailed) ...[
              Notice(error!, isError: true),
              OutlinedButton(
                onPressed: load,
                child: const Text('Volver a intentar'),
              ),
            ],
            if (!loading && !loadFailed) ...[
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xffe3e4ed)),
                ),
                child: InkWell(
                  key: const ValueKey('public-profile-photo'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: editable && !busy ? pickAvatar : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final narrow =
                            bounds.maxWidth < 280 ||
                            MediaQuery.textScalerOf(context).scale(13) > 19;
                        final edit = Tooltip(
                          message: 'Editar foto de perfil',
                          child: OutlinedButton(
                            key: const ValueKey('public-profile-edit-photo'),
                            onPressed: editable && !busy ? pickAvatar : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ink,
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xffe3e4ed)),
                              shape: const StadiumBorder(),
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/profile/icon-edit.svg',
                                  width: 18,
                                  height: 18,
                                  colorFilter: const ColorFilter.mode(
                                    ink,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('Editar'),
                              ],
                            ),
                          ),
                        );
                        return Column(
                          children: [
                            Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: const Color(0xffe9dfff),
                                      foregroundColor: purple,
                                      backgroundImage: avatarBytes != null
                                          ? MemoryImage(avatarBytes!)
                                          : null,
                                      child: avatarBytes != null
                                          ? null
                                          : visibleAvatarPath == null ||
                                                visibleAvatarPath.isEmpty
                                          ? avatarFallback()
                                          : ClipOval(
                                              child: RemotePhoto(
                                                source: PhotoRef(
                                                  path: visibleAvatarPath,
                                                  purpose: MediaPurpose
                                                      .rescuerAvatar,
                                                  persistence:
                                                      PhotoPersistence.ordinary,
                                                  sign: () => ref
                                                      .read(
                                                        rescuerProfileRepositoryProvider,
                                                      )
                                                      .avatarUrl(
                                                        visibleAvatarPath,
                                                      ),
                                                ),
                                                width: 64,
                                                height: 64,
                                                loading: avatarFallback(),
                                                unavailable: (retry) => Tooltip(
                                                  message: 'Reintentar foto de perfil',
                                                  child: InkWell(
                                                    onTap: retry,
                                                    child: avatarFallback(),
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: purple,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: SvgPicture.asset(
                                          'assets/profile/onb-camera.svg',
                                          width: 12,
                                          height: 12,
                                          colorFilter: const ColorFilter.mode(
                                            Colors.white,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Foto de perfil',
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.2,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Cambia tu foto de perfil',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.2,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!narrow) edit,
                              ],
                            ),
                            if (narrow)
                              Align(
                                alignment: Alignment.centerRight,
                                child: edit,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _StatusCard(status, profile?['review_feedback'] as String? ?? ''),
              const SizedBox(height: 12),
              TextFormField(
                initialValue:
                    ref.read(identityControllerProvider).identity?.email ?? '',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Correo de tu cuenta',
                  helperText: 'El correo de identidad no se cambia aquí.',
                ),
              ),
              const SizedBox(height: 16),
              _PhoneVerification(enabled: editable && !busy),
              const SizedBox(height: 16),
              for (final item in [
                ('Nombre', name, 1),
                ('Ciudad', city, 1),
                ('Estado', region, 1),
                ('Correo público', publicEmail, 1),
                ('Teléfono público', publicPhone, 1),
                ('Dirección pública', address, 1),
                ('Instagram (https://)', instagram, 1),
                ('Facebook (https://)', facebook, 1),
                ('Página web (https://)', website, 1),
                ('Sobre ti', bio, 5),
              ]) ...[
                Semantics(
                  label: item.$1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff151423),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: ValueKey(
                          item.$2 == bio
                              ? 'public-profile-Descripción'
                              : 'public-profile-${item.$1}',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                          color: Color(0xff151423),
                        ),
                        onChanged: item.$2 == name
                            ? (_) => setState(() {})
                            : null,
                        controller: item.$2,
                        autofillHints: item.$2 == name
                            ? const [AutofillHints.name]
                            : null,
                        enabled: editable && !busy,
                        minLines: item.$3,
                        maxLines: item.$3 == 1 ? 1 : null,
                        keyboardType:
                            item.$2 == instagram ||
                                item.$2 == facebook ||
                                item.$2 == website
                            ? TextInputType.url
                            : item.$2 == publicEmail
                            ? TextInputType.emailAddress
                            : item.$2 == publicPhone
                            ? TextInputType.phone
                            : null,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: item.$2 == name
                              ? 'Tu nombre o el de tu refugio'
                              : item.$2 == bio
                              ? 'Cuenta quién eres y cómo ayudas a las mascotas'
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xffeaeaf3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: purple,
                              width: 2,
                            ),
                          ),
                          errorText:
                              (profile?['field_feedback']
                                      as Map?)?[switch (item.$2) {
                                    _ when item.$2 == name => 'display_name',
                                    _ when item.$2 == bio => 'bio',
                                    _ when item.$2 == publicEmail =>
                                      'public_email',
                                    _ when item.$2 == publicPhone =>
                                      'public_phone',
                                    _ when item.$2 == address =>
                                      'public_address',
                                    _ when item.$2 == website => 'website_url',
                                    _ when item.$2 == instagram =>
                                      'instagram_url',
                                    _ when item.$2 == facebook =>
                                      'facebook_url',
                                    _ when item.$2 == city => 'city',
                                    _ => 'region',
                                  }]
                                  as String?,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: contactConsent,
                onChanged: editable && !busy
                    ? (value) {
                        if (value == false &&
                            profile?['contact_consent'] == true) {
                          transition('revoke_contacts');
                        } else {
                          setState(() => contactConsent = value ?? false);
                        }
                      }
                    : status == 'submitted' && contactConsent && !busy
                    ? (value) {
                        if (value == false) transition('revoke_contacts');
                      }
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Quiero mostrar estos contactos en mi perfil público.',
                ),
                subtitle: const Text(
                  'Correo, teléfono y dirección públicos se muestran sólo con tu consentimiento y aprobación. Puedes retirarlos durante la revisión; publicarlos de nuevo requiere aprobación.',
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RescuerProfilePreview(
                            ownerId: ref
                                .read(rescuerProfileRepositoryProvider)
                                .userId,
                            payload: payload(avatarPath: avatarPath),
                            avatarBytes: avatarBytes,
                          ),
                        ),
                      ),
                child: const Text('Ver vista previa >'),
              ),
              if (error != null) Notice(error!, isError: true),
              if (busy)
                const LinearProgressIndicator(
                  semanticsLabel: 'Guardando perfil',
                ),
              if (editable) ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: const Color(0xfffbfbff),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: busy ? null : save,
                  child: const Text('Guardar borrador'),
                ),
                const SizedBox(height: 16),
                ActionButton(
                  'Enviar a revisión',
                  busy: busy,
                  onPressed: () async {
                    if (await save(announce: false)) await transition('submit');
                  },
                ),
              ] else if (status == 'submitted')
                OutlinedButton(
                  onPressed: busy ? null : () => transition('withdraw'),
                  child: const Text('Retirar de revisión'),
                ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                minimumSize: const Size(0, 48),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: busy ? null : leaveEditor,
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
    final router = GoRouter.maybeOf(context);
    return PopScope(
      canPop: router?.canPop() ?? true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && router != null) leaveEditor();
      },
      child: screen,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(this.status, this.feedback);
  final String status, feedback;
  @override
  Widget build(BuildContext context) {
    const labels = {
      'draft': 'Borrador',
      'submitted': 'En revisión',
      'changes_requested': 'Necesita correcciones',
      'rejected': 'No aprobado',
      'published': 'Publicado',
    };
    return Notice(
      feedback.isEmpty
          ? 'Estado: ${labels[status] ?? status}'
          : 'Estado: ${labels[status] ?? status}. $feedback',
      isError: ['changes_requested', 'rejected'].contains(status),
    );
  }
}

class _PhoneVerification extends ConsumerStatefulWidget {
  const _PhoneVerification({required this.enabled});
  final bool enabled;
  @override
  ConsumerState<_PhoneVerification> createState() => _PhoneVerificationState();
}

class _PhoneVerificationState extends ConsumerState<_PhoneVerification> {
  final number = TextEditingController();
  final code = TextEditingController();
  String? requestedNumber, confirmedNumber, error;
  bool busy = false;
  @override
  void dispose() {
    number.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> perform(String action) async {
    if (busy || !widget.enabled) return;
    final e164 = action == 'request' ? number.text.trim() : requestedNumber;
    if (e164 == null || !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(e164)) {
      setState(
        () => error =
            'Escribe tu número con código de país, por ejemplo +525512345678.',
      );
      return;
    }
    final owner = ref.read(rescuerProfileRepositoryProvider).userId;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(phoneVerificationRepositoryProvider);
      if (action == 'verify') {
        await repo.verifyPhoneCode(e164, code.text.trim());
      } else if (action == 'resend') {
        await repo.resendPhoneCode(e164);
      } else {
        await repo.requestPhoneCode(e164);
      }
      if (!mounted ||
          owner != ref.read(rescuerProfileRepositoryProvider).userId) {
        return;
      }
      setState(() {
        if (action == 'verify') {
          confirmedNumber = repo.verifiedPhone;
          if (confirmedNumber == null) error = 'El número aún no está confirmado. Completa los códigos pendientes.';
        } else {
          requestedNumber = e164;
        }
      });
    } catch (cause) {
      if (mounted) setState(() => error = phoneVerificationError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified =
        confirmedNumber ??
        ref.read(phoneVerificationRepositoryProvider).verifiedPhone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Teléfono de tu cuenta',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        if (verified != null) Text('Vinculado: $verified'),
        const Text(
          'Verifica tu número con un código por SMS. El contacto público se elige por separado.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('profile-sms-phone'),
          controller: number,
          enabled: widget.enabled && !busy,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Número con código de país',
            hintText: '+525512345678',
          ),
        ),
        TextButton(
          onPressed: widget.enabled && !busy ? () => perform('request') : null,
          child: Text(verified == null ? 'Vincular' : 'Cambiar número'),
        ),
        if (requestedNumber != null) ...[
          Text('Enviamos el código a $requestedNumber'),
          TextField(
            key: const ValueKey('profile-sms-code'),
            controller: code,
            enabled: widget.enabled && !busy,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: 'Código por SMS'),
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: widget.enabled && !busy
                    ? () => perform('verify')
                    : null,
                child: const Text('Confirmar código'),
              ),
              TextButton(
                onPressed: widget.enabled && !busy
                    ? () => perform('resend')
                    : null,
                child: const Text('Reenviar código'),
              ),
            ],
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        if (error != null) Notice(error!, isError: true),
      ],
    );
  }
}
