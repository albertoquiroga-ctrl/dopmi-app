import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const videoMaxBytes = 200 * 1024 * 1024;
const videoMaxDuration = Duration(seconds: 60);
const videoChunkBytes = 6 * 1024 * 1024;
typedef VideoInvoke = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class VideoFailure implements Exception {
  const VideoFailure(this.code);
  final String code;
  @override
  String toString() => 'VideoFailure($code)';
}

/// Capabilities and playback leases stay in memory and are never preferences/cache keys.
class VideoAsset {
  const VideoAsset({
    required this.id,
    required this.state,
    required this.moderation,
    this.duration,
  });
  factory VideoAsset.fromJson(Map<String, dynamic> value) => VideoAsset(
    id: value['id'] as String,
    state: value['technical_state'] as String? ?? 'reserved',
    moderation: value['moderation_state'] as String? ?? 'pending',
    duration: (value['duration'] as num?)?.toDouble(),
  );
  final String id, state, moderation;
  final double? duration;
  bool get ready => state == 'ready';
}

class VideoPolicy {
  const VideoPolicy({
    required this.enabled,
    required this.thanksRequired,
    required this.assets,
    this.urgencyAllowed = false,
  });
  factory VideoPolicy.fromJson(Map<String, dynamic> value) => VideoPolicy(
    enabled: value['enabled'] == true,
    thanksRequired: value['thanks_required'] == true,
    urgencyAllowed: value['urgency_allowed'] == true,
    assets: (value['assets'] as List? ?? [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(),
  );
  final bool enabled, thanksRequired, urgencyAllowed;
  final List<Map<String, dynamic>> assets;
}

class _VideoDigest implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

class VideoLease {
  const VideoLease({
    required this.hls,
    required this.poster,
    required this.expiresAt,
  });
  final Uri hls, poster;
  final DateTime expiresAt;
}

class VideoUploadTask {
  VideoUploadTask({
    required this.parentId,
    required this.parentVersion,
    required this.purpose,
    required this.identity,
    String? requestKey,
    this.expectedBytes,
    this.fileFingerprint,
  }) : requestKey = requestKey ?? const Uuid().v4();
  final String parentId, purpose, identity, requestKey;
  final int parentVersion;
  final int? expectedBytes;
  String? fileFingerprint;
  String? assetId;
  int uploaded = 0;
  bool canceled = false;
  void cancel() {
    canceled = true;
  }
}

class VideoRepository {
  VideoRepository({
    required this.invoke,
    required this.identity,
    this.identityChanges,
    this.policyInvoke,
    http.Client? transport,
  }) : _transport = transport ?? http.Client(),
       _ownsTransport = transport == null;
  factory VideoRepository.supabase(SupabaseClient client) => VideoRepository(
    policyInvoke: (parentId) async {
      final value = await client.rpc(
        'dopmi_video_policy',
        params: {'target_parent': parentId},
      );
      return Map<String, dynamic>.from(value as Map);
    },
    identityChanges: client.auth.onAuthStateChange.map<void>((_) {}),
    identity: () {
      final session = client.auth.currentSession;
      if (session == null) return null;
      try {
        final claims = jsonDecode(
          utf8.decode(
            base64Url.decode(
              base64Url.normalize(session.accessToken.split('.')[1]),
            ),
          ),
        ) as Map<String, dynamic>;
        final sessionId = claims['session_id'];
        return sessionId is String ? '${session.user.id}:$sessionId' : null;
      } catch (_) {
        return null;
      }
    },
    invoke: (body) async {
      final response = await client.functions.invoke('video-media', body: body);
      if (response.data is! Map) throw const VideoFailure('invalid_response');
      final value = Map<String, dynamic>.from(response.data as Map);
      if (value['error'] != null) throw const VideoFailure('request_denied');
      return value;
    },
  );
  final VideoInvoke invoke;
  final Future<Map<String, dynamic>> Function(String parentId)? policyInvoke;
  final String? Function() identity;
  final Stream<void>? identityChanges;
  final http.Client _transport;
  final bool _ownsTransport;
  bool _disposed = false;
  void dispose() {
    _disposed = true;
    if (_ownsTransport) _transport.close();
  }

  void _check(String? expected, [VideoUploadTask? task]) {
    if (_disposed) throw const VideoFailure('disposed');
    if (identity() != expected) throw const VideoFailure('identity_changed');
    if (task?.canceled == true) throw const VideoFailure('canceled');
  }

  Future<Map<String, dynamic>> _call(
    Map<String, dynamic> data,
    String? expected,
  ) async {
    _check(expected);
    final result = await invoke(data);
    _check(expected);
    if (result['error'] != null) throw const VideoFailure('request_denied');
    return result;
  }

  Future<VideoPolicy> policy(String parentId) async {
    final scope = identity();
    _check(scope);
    final result =
        await (policyInvoke?.call(parentId) ??
            invoke({'action': 'policy', 'parent_id': parentId}));
    _check(scope);
    if (result['error'] != null) {
      throw const VideoFailure('request_denied');
    }
    return VideoPolicy.fromJson(result);
  }

  Future<VideoAsset> status(String id) async => VideoAsset.fromJson(
    await _call({'action': 'status', 'id': id}, identity()),
  );
  Future<List<Map<String, dynamic>>> publicVideos(String parentId) async {
    final result = await _call({
      'action': 'public_list',
      'parent_id': parentId,
    }, identity());
    return (result['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<VideoLease> playback(String id) async {
    final value = await _call({'action': 'playback', 'id': id}, identity());
    Uri checked(String key) {
      final url = Uri.parse(value[key] as String);
      if (url.scheme != 'https' ||
          url.host != 'videodelivery.net' ||
          url.userInfo.isNotEmpty) {
        throw const VideoFailure('invalid_playback');
      }
      return url;
    }

    final expires = DateTime.fromMillisecondsSinceEpoch(
      (value['expires_at'] as num).toInt() * 1000,
      isUtc: true,
    );
    if (!expires.isAfter(DateTime.now().toUtc()) ||
        expires.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 3)),
        )) {
      throw const VideoFailure('invalid_lease');
    }
    return VideoLease(
      hls: checked('hls'),
      poster: checked('poster'),
      expiresAt: expires,
    );
  }

  Future<void> cancel(VideoUploadTask task) async {
    task.cancel();
    final id = task.assetId;
    if (id != null) await _call({'action': 'cancel', 'id': id}, task.identity);
  }

  Future<VideoAsset> upload(
    VideoUploadTask task,
    XFile file, {
    void Function(int, int)? onProgress,
  }) async {
    _check(task.identity, task);
    final bytes = await file.length();
    _check(task.identity, task);
    if (bytes < 1 || bytes > videoMaxBytes) {
      throw const VideoFailure('file_size');
    }
    if (task.expectedBytes != null && task.expectedBytes != bytes) {
      throw const VideoFailure('file_changed');
    }
    final digest = _VideoDigest();
    final sink = sha256.startChunkedConversion(digest);
    await for (final part in file.openRead()) {
      _check(task.identity, task);
      sink.add(part);
    }
    sink.close();
    final fingerprint = digest.value!.toString();
    if (task.fileFingerprint != null && task.fileFingerprint != fingerprint) {
      throw const VideoFailure('file_changed');
    }
    task.fileFingerprint = fingerprint;
    final data = await _call({
      'file_fingerprint': fingerprint,
      'action': 'begin',
      'parent_id': task.parentId,
      'parent_version': task.parentVersion,
      'purpose': task.purpose,
      'request_key': task.requestKey,
      'bytes': bytes,
    }, task.identity);
    task.assetId = data['id'] as String? ?? task.assetId;
    if (task.canceled) {
      if (task.assetId != null) {
        await _call({'action': 'cancel', 'id': task.assetId}, task.identity);
      }
      throw const VideoFailure('canceled');
    }
    _check(task.identity, task);
    if (data['upload_state'] == 'provisioning_unknown') {
      throw const VideoFailure('needs_reconciliation');
    }
    final asset = VideoAsset.fromJson(data);
    if ([
      'processing',
      'ready',
      'failed',
      'canceled',
      'deleted',
    ].contains(asset.state)) {
      return asset;
    }
    final location = data['upload_url'];
    if (location is! String) throw const VideoFailure('upload_not_ready');
    final url = Uri.parse(location);
    if (url.scheme != 'https' ||
        ![
          'upload.videodelivery.net',
          'upload.cloudflarestream.com',
        ].contains(url.host) ||
        url.userInfo.isNotEmpty) {
      throw const VideoFailure('invalid_upload');
    }
    final head = http.Request('HEAD', url)..followRedirects = false;
    head.headers['Tus-Resumable'] = '1.0.0';
    final start = await _transport.send(head);
    await start.stream.drain<void>();
    _check(task.identity, task);
    if (start.statusCode != 200 && start.statusCode != 204) {
      throw const VideoFailure('upload_resume_failed');
    }
    final reportedOffset = int.tryParse(start.headers['upload-offset'] ?? '');
    if (reportedOffset == null ||
        reportedOffset < 0 ||
        reportedOffset > bytes) {
      throw const VideoFailure('invalid_offset');
    }
    int offset = reportedOffset;
    if (start.headers['upload-length'] != null &&
        int.tryParse(start.headers['upload-length']!) != bytes) {
      throw const VideoFailure('file_changed');
    }
    task.uploaded = offset;
    onProgress?.call(offset, bytes);
    while (offset < bytes) {
      _check(task.identity, task);
      final end = math.min(offset + videoChunkBytes, bytes);
      final buffer = BytesBuilder(copy: false);
      await for (final part in file.openRead(offset, end)) {
        _check(task.identity, task);
        buffer.add(part);
        if (buffer.length > videoChunkBytes) {
          throw const VideoFailure('chunk_limit');
        }
      }
      if (buffer.length != end - offset) {
        throw const VideoFailure('file_changed');
      }
      final patch = http.Request('PATCH', url)..followRedirects = false;
      patch.headers.addAll({
        'Tus-Resumable': '1.0.0',
        'Upload-Offset': '$offset',
        'Content-Type': 'application/offset+octet-stream',
      });
      patch.bodyBytes = buffer.takeBytes();
      final sent = await _transport.send(patch);
      await sent.stream.drain<void>();
      _check(task.identity, task);
      final actual = int.tryParse(sent.headers['upload-offset'] ?? '');
      if (sent.statusCode != 204 || actual != end) {
        throw const VideoFailure('upload_interrupted');
      }
      offset = end;
      task.uploaded = end;
      onProgress?.call(end, bytes);
    }
    return VideoAsset.fromJson(
      await _call({'action': 'status', 'id': asset.id}, task.identity),
    );
  }
}
