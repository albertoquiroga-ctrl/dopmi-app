import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import '../adoption/community_repository.dart';
import '../adoption/public_profile_body.dart';
import 'rescuer_profile_repository.dart';
import '../identity/identity_controller.dart';

/// A local draft preview: opening this route never saves, uploads or publishes.
class RescuerProfilePreview extends ConsumerStatefulWidget {
  const RescuerProfilePreview({
    super.key,
    required this.payload,
    this.avatarBytes,
    this.ownerId,
  });
  final String? ownerId;
  final Json payload;
  final Uint8List? avatarBytes;
  @override
  ConsumerState<RescuerProfilePreview> createState() =>
      _RescuerProfilePreviewState();
}

class _RescuerProfilePreviewState extends ConsumerState<RescuerProfilePreview> {
  Json? published;
  String? error;
  bool loading = true;
  late final String? owner;
  late final IdentityController identity;
  bool invalidated = false;

  bool get current =>
      !invalidated &&
      owner != null &&
      identity.identity?.id == owner &&
      ref.read(rescuerProfileRepositoryProvider).userId == owner;

  void identityChanged() {
    if (identity.identity?.id != owner && mounted) {
      setState(() {
        invalidated = true;
        published = null;
      });
    }
  }

  @override
  void dispose() {
    identity.removeListener(identityChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    owner = widget.ownerId ?? ref.read(rescuerProfileRepositoryProvider).userId;
    identity = ref.read(identityControllerProvider);
    identity.addListener(identityChanged);
    load();
  }

  Future<void> load() async {
    if (!current) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = owner == null
          ? null
          : await ref.read(communityRepositoryProvider).publicProfile(owner!);
      if (!mounted || !current) {
        return;
      }
      if (value != null && value['id'] != owner) {
        throw StateError('Profile owner mismatch');
      }
      setState(() {
        published = value;
        error = null;
        loading = false;
      });
    } catch (_) {
      if (mounted && current) {
        setState(() {
          error = 'No pudimos cargar tus publicaciones y métricas públicas.';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!current) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vista previa')),
        body: const Center(
          child: Text('La sesión cambió. Abre de nuevo tu perfil.'),
        ),
      );
    }
    final payload = widget.payload;
    final avatarBytes = widget.avatarBytes;
    final name = payload['display_name'] as String? ?? '';
    final path = payload['avatar_path'] as String? ?? '';
    final fallback = CircleAvatar(
      radius: 44,
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
    );
    final avatar = avatarBytes != null
        ? CircleAvatar(radius: 44, backgroundImage: MemoryImage(avatarBytes))
        : path.isEmpty
        ? fallback
        : ClipOval(
            child: RemotePhoto(
              source: PhotoRef(
                path: path,
                purpose: MediaPurpose.rescuerAvatar,
                persistence: PhotoPersistence.ordinary,
                sign: () =>
                    ref.read(rescuerProfileRepositoryProvider).avatarUrl(path),
              ),
              width: 88,
              height: 88,
              loading: fallback,
              unavailable: (_) => fallback,
            ),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Notice(
            'Borrador privado. Esta vista previa no guarda ni publica cambios.',
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            Notice(error!, isError: true),
            TextButton(
              onPressed: load,
              child: const Text('Reintentar publicaciones'),
            ),
          ],
          PublicProfileBody(
            profile: {
              ...?published,
              'id': owner,
              'name': name,
              'bio': payload['bio'] ?? '',
              'city': payload['city'] ?? '',
              'region': payload['region'] ?? '',
              'instagram_url': payload['instagram_url'] ?? '',
              'facebook_url': payload['facebook_url'] ?? '',
              'public_email': payload['contact_consent'] == true
                  ? payload['public_email'] ?? ''
                  : '',
              'public_phone': payload['contact_consent'] == true
                  ? payload['public_phone'] ?? ''
                  : '',
              'public_address': payload['contact_consent'] == true
                  ? payload['public_address'] ?? ''
                  : '',
              'website_url': payload['contact_consent'] == true
                  ? payload['website_url'] ?? ''
                  : '',
            },
            avatar: avatar,
            interactive: false,
          ),
        ],
      ),
    );
  }
}
