import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart' show routerProvider;

enum PublicContent { profile, adoption, rescueCase }

String _segment(PublicContent kind) => switch (kind) {
  PublicContent.profile => 'people',
  PublicContent.adoption => 'adoptions',
  PublicContent.rescueCase => 'rescue-cases',
};

Uri publicContentLink(PublicContent kind, String id) => Uri(
  scheme: 'io.dopmi.app',
  host: 'content',
  pathSegments: [_segment(kind), id],
);

String? contentLinkDestination(Uri uri) {
  final parts = uri.pathSegments;
  if (uri.scheme != 'io.dopmi.app' ||
      uri.host != 'content' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment ||
      parts.length != 2 ||
      !['people', 'adoptions', 'rescue-cases'].contains(parts.first) ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(parts.last)) {
    return null;
  }
  return '/${parts.first}/${parts.last}';
}

abstract class ContentLinkSource {
  Future<Uri?> latest();
  Stream<Uri> get events;
}

class PlatformContentLinkSource implements ContentLinkSource {
  final links = AppLinks();
  @override
  Future<Uri?> latest() => links.getLatestLink();
  @override
  Stream<Uri> get events => links.uriLinkStream;
}

final contentLinkSourceProvider = Provider<ContentLinkSource>(
  (ref) => PlatformContentLinkSource(),
);

class ContentLinkListener extends ConsumerStatefulWidget {
  const ContentLinkListener({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<ContentLinkListener> createState() =>
      _ContentLinkListenerState();
}

class _ContentLinkListenerState extends ConsumerState<ContentLinkListener> {
  StreamSubscription<Uri>? subscription;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    final source = ref.read(contentLinkSourceProvider);
    subscription = source.events.listen((uri) {
      revision++;
      open(uri);
    }, onError: (Object _) {});
    unawaited(loadLatest(source));
  }

  Future<void> loadLatest(ContentLinkSource source) async {
    final version = revision;
    try {
      final uri = await source.latest();
      if (mounted && version == revision && uri != null) open(uri);
    } catch (_) {
      // A missing or failed OS link must not prevent normal app startup.
    }
  }

  void open(Uri uri) {
    if (!mounted) return;
    final destination = contentLinkDestination(uri);
    if (destination == null) return;
    final router = ref.read(routerProvider);
    if (router.routerDelegate.currentConfiguration.isEmpty ||
        router.state.uri.toString() != destination) {
      router.go(destination);
    }
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
