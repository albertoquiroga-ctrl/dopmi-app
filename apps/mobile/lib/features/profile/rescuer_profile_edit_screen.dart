import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import 'profile_overview.dart';
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
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (selected == null || !mounted) return;
    if (profile == null && !await save(announce: false)) return;
    setState(() => busy = true);
    try {
      final repo = ref.read(rescuerProfileRepositoryProvider);
      final path = await repo.uploadAvatar(await selected.readAsBytes());
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
    return ProfileFrame(
      title: 'Editar perfil público',
      back: true,
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
              borderRadius: BorderRadius.circular(20),
              onTap: editable && !busy ? pickAvatar : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xffe9dfff),
                      foregroundColor: purple,
                      backgroundImage: avatarUrl == null
                          ? null
                          : NetworkImage(avatarUrl!),
                      child: avatarUrl == null
                          ? Text(
                              name.text.trim().isEmpty
                                  ? '?'
                                  : name.text
                                        .trim()
                                        .substring(0, 1)
                                        .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
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
          TextField(
            controller: name,
            enabled: editable && !busy,
            decoration: const InputDecoration(labelText: 'Nombre público'),
          ),
          TextField(
            controller: bio,
            enabled: editable && !busy,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          TextField(
            controller: city,
            enabled: editable && !busy,
            decoration: const InputDecoration(labelText: 'Ciudad'),
          ),
          TextField(
            controller: region,
            enabled: editable && !busy,
            decoration: const InputDecoration(labelText: 'Estado'),
          ),
          TextField(
            controller: instagram,
            enabled: editable && !busy,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Instagram (https://)',
            ),
          ),
          TextField(
            controller: facebook,
            enabled: editable && !busy,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Facebook (https://)'),
          ),
          const SizedBox(height: 16),
          if (error != null) Notice(error!, isError: true),
          if (busy)
            const LinearProgressIndicator(semanticsLabel: 'Guardando perfil'),
          if (editable) ...[
            OutlinedButton(
              onPressed: busy ? null : save,
              child: const Text('Guardar borrador'),
            ),
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
      ],
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
