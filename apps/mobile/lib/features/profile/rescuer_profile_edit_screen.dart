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
      title: 'Perfil público',
      back: true,
      children: [
        const Text(
          'Tu nombre público, foto, descripción, ciudad y enlaces serán visibles después de la revisión. No mostramos domicilio, teléfono ni correo.',
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (!loading) ...[
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: yellow,
              backgroundImage: avatarUrl == null
                  ? null
                  : NetworkImage(avatarUrl!),
              child: avatarUrl == null
                  ? const Icon(Icons.person_outline, size: 48, color: ink)
                  : null,
            ),
          ),
          TextButton.icon(
            onPressed: editable && !busy ? pickAvatar : null,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Elegir foto pública'),
          ),
          _StatusCard(status, profile?['review_feedback'] as String? ?? ''),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            enabled: editable,
            decoration: const InputDecoration(labelText: 'Nombre público'),
          ),
          TextField(
            controller: bio,
            enabled: editable,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          TextField(
            controller: city,
            enabled: editable,
            decoration: const InputDecoration(labelText: 'Ciudad'),
          ),
          TextField(
            controller: region,
            enabled: editable,
            decoration: const InputDecoration(labelText: 'Estado'),
          ),
          TextField(
            controller: instagram,
            enabled: editable,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Instagram (https://)',
            ),
          ),
          TextField(
            controller: facebook,
            enabled: editable,
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
