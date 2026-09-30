import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'prepare_photo.dart';

/// Gives private media enough time to load after navigation or a brief app
/// suspension while keeping each generated URL short-lived.
const mediaSignedUrlLifetimeSeconds = 10 * 60;

enum MediaPurpose {
  adoptionPhoto,
  rescuePhoto,
  rescueDocument,
  caseUpdatePhoto,
  rescuerAvatar,
}

extension MediaPolicy on MediaPurpose {
  String get bucket => switch (this) {
    MediaPurpose.adoptionPhoto => 'dopmi-adoption-photos',
    MediaPurpose.caseUpdatePhoto => 'dopmi-case-update-media',
    MediaPurpose.rescuerAvatar => 'dopmi-rescuer-profile-media',
    _ => 'dopmi-rescue-evidence',
  };
  bool get isDocument => this == MediaPurpose.rescueDocument;
  int get inputLimit =>
      this == MediaPurpose.adoptionPhoto ? 15 * 1024 * 1024 : 5 * 1024 * 1024;
}

@immutable
class PreparedMedia {
  const PreparedMedia(this.bytes, this.contentType, this.extension);
  final Uint8List bytes;
  final String contentType;
  final String extension;
}

/// Current formats only. Future video support requires its own policy/processor.
PreparedMedia prepareMedia((MediaPurpose, Uint8List) input) {
  final (purpose, bytes) = input;
  if (bytes.isEmpty || bytes.length > purpose.inputLimit) {
    throw FormatException(
      'Elige un archivo de hasta ${purpose.inputLimit ~/ (1024 * 1024)} MB.',
    );
  }
  if (purpose.isDocument) {
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const FormatException('El archivo no es un PDF válido.');
    }
    return PreparedMedia(bytes, 'application/pdf', 'pdf');
  }
  final photo = preparePhoto(bytes);
  if (photo.length > 5 * 1024 * 1024) {
    throw const FormatException('La foto procesada supera el límite de 5 MB.');
  }
  return PreparedMedia(photo, 'image/jpeg', 'jpg');
}

/// Centralizes client validation and upload paths. PostgreSQL/Storage enforce
/// ownership and record state; selecting a purpose never grants authorization.
class MediaStore {
  MediaStore(this.client);
  final SupabaseClient client;

  Future<String> upload(
    String recordId,
    Uint8List bytes,
    MediaPurpose purpose,
  ) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const FormatException('Inicia sesión para adjuntar archivos.');
    }
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(recordId)) {
      throw const FormatException(
        'Guarda el borrador antes de adjuntar archivos.',
      );
    }
    final prepared = await compute(prepareMedia, (purpose, bytes));
    if (client.auth.currentUser?.id != owner) {
      throw const FormatException(
        'La sesión cambió. Vuelve a adjuntar el archivo.',
      );
    }
    final path = '$owner/$recordId/${const Uuid().v4()}.${prepared.extension}';
    await client.storage
        .from(purpose.bucket)
        .uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            contentType: prepared.contentType,
            cacheControl: '0',
            upsert: false,
          ),
        );
    return path;
  }

  Future<String> signedUrl(String path, MediaPurpose purpose) =>
      client.storage
          .from(purpose.bucket)
          .createSignedUrl(path, mediaSignedUrlLifetimeSeconds);
}
