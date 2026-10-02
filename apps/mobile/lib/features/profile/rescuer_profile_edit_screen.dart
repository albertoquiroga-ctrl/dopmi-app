import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import 'rescuer_profile_repository.dart';

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
  Json? profile;
  String? avatarUrl, error;
  bool loading = true, busy = false;

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
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value = await ref.read(rescuerProfileRepositoryProvider).load();
      if (!mounted) return;
      profile = value;
      name.text = value?['display_name'] as String? ?? '';
      bio.text = value?['bio'] as String? ?? '';
      city.text = value?['city'] as String? ?? '';
      region.text = value?['region'] as String? ?? '';
      instagram.text = value?['instagram_url'] as String? ?? '';
      facebook.text = value?['facebook_url'] as String? ?? '';
      final path = value?['avatar_path'] as String?;
      if (path != null && path.isNotEmpty) {
        avatarUrl = await ref
            .read(rescuerProfileRepositoryProvider)
            .avatarUrl(path);
      }
    } catch (cause) {
      error = communityError(cause);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Json payload({String? avatarPath}) => {
    'display_name': name.text.trim(),
    'bio': bio.text.trim(),
    'city': city.text.trim(),
    'region': region.text.trim(),
    'instagram_url': instagram.text.trim(),
    'facebook_url': facebook.text.trim(),
    'avatar_path': avatarPath ?? profile?['avatar_path'] ?? '',
  };

  Future<bool> save({bool announce = true}) async {
    if (busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      profile = await ref
          .read(rescuerProfileRepositoryProvider)
          .save(payload(), version: profile?['version'] as int?);
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
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (selected == null || !mounted) return;
      final repo = ref.read(rescuerProfileRepositoryProvider);
      if (profile == null) {
        profile = await repo.save(payload());
        if (!mounted) return;
      }
      final path = await repo.uploadAvatar(await selected.readAsBytes());
      if (!mounted) return;
      profile = await repo.save(
        payload(avatarPath: path),
        version: profile?['version'] as int?,
      );
      avatarUrl = await repo.avatarUrl(path);
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
      profile = await ref
          .read(rescuerProfileRepositoryProvider)
          .transition(profile!['version'] as int, action);
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

  @override
  Widget build(BuildContext context) {
    final status = profile?['status'] as String? ?? 'draft';
    final editable = [
      'draft',
      'changes_requested',
      'rejected',
    ].contains(status);
    final large = MediaQuery.textScalerOf(context).scale(18) > 25;
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: large
            ? MediaQuery.textScalerOf(context).scale(18) * 2.6 + 16
            : 67,
        title: Text(
          'Editar perfil público',
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
          onPressed: () => context.go('/rescuer/profile'),
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
            const Text(
              'Tu nombre público, foto, descripción, ciudad y enlaces serán visibles después de la revisión. No mostramos domicilio, teléfono ni correo.',
            ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (!loading) ...[
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xffe6e2dd)),
                ),
                child: InkWell(
                  key: const ValueKey('public-profile-photo'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: editable && !busy ? pickAvatar : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xffe9dfff),
                              foregroundColor: purple,
                              backgroundImage: avatarUrl == null
                                  ? null
                                  : NetworkImage(avatarUrl!),
                              child: avatarUrl == null
                                  ? name.text.trim().isEmpty
                                        ? const Icon(
                                            Icons.person_outline,
                                            color: purple,
                                          )
                                        : Text(
                                            name.text
                                                .trim()
                                                .characters
                                                .first
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          )
                                  : null,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto de perfil',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Cambia tu foto de perfil',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _StatusCard(status, profile?['review_feedback'] as String? ?? ''),
              const SizedBox(height: 12),
              for (final item in [
                ('Nombre', name, 1),
                ('Descripción', bio, 5),
                ('Ciudad', city, 1),
                ('Estado', region, 1),
                ('Instagram (https://)', instagram, 1),
                ('Facebook (https://)', facebook, 1),
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
                        key: ValueKey('public-profile-${item.$1}'),
                        onChanged: item.$2 == name
                            ? (_) => setState(() {})
                            : null,
                        controller: item.$2,
                        enabled: editable && !busy,
                        minLines: item.$3,
                        maxLines: item.$3 == 1 ? 1 : null,
                        keyboardType:
                            item.$2 == instagram || item.$2 == facebook
                            ? TextInputType.url
                            : null,
                        decoration: const InputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (error != null) Notice(error!, isError: true),
              if (busy)
                const LinearProgressIndicator(
                  semanticsLabel: 'Guardando perfil',
                ),
              if (editable) ...[
                OutlinedButton(
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
              onPressed: busy ? null : () => context.go('/rescuer/profile'),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
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
