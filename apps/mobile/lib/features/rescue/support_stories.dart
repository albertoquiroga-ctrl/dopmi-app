import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../../core/media/remote_photo.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/moderated_video.dart';
import 'case_update_repository.dart';
import 'rescue_repository.dart';
import 'rescue_public_photo.dart';
import 'rescue_videos.dart';

const _thankYouStyle = TextStyle(
  fontSize: 26,
  height: 1.2,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  shadows: [
    Shadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0xbf000000)),
    Shadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x73000000)),
  ],
);

/// Only approved public snapshot photos; never private evidence or receipts.
List<String> supportStoryPhotos(RescueRecord record) =>
    record.kind == 'case' &&
        (record.status == 'approved' || record.status == 'closed')
    ? (record.publicData['photos'] as List? ?? const [])
          .whereType<String>()
          .where((p) => p.trim().isNotEmpty)
          .toSet()
          .toList()
    : const [];

enum SupportStoryKind {
  hero,
  urgency,
  thanks,
  casePhoto,
  publicUpdate,
  farewell,
}

class SupportStorySegment {
  const SupportStorySegment({
    required this.id,
    required this.kind,
    this.photo,
    this.video,
    this.update,
  });
  final String id;
  final SupportStoryKind kind;
  final String? photo;
  final PublicRescueVideo? video;
  final CaseUpdate? update;
  String get label => switch (kind) {
    SupportStoryKind.hero => 'Historia del caso',
    SupportStoryKind.urgency => 'Urgencia',
    SupportStoryKind.thanks => 'Agradecimiento',
    SupportStoryKind.casePhoto => 'Foto del caso',
    SupportStoryKind.publicUpdate => 'Avance público',
    SupportStoryKind.farewell => 'Despedida',
  };
}

/// Build from approved public snapshots and the public-list/update endpoints.
/// No record.files, private_data, expense receipts or private evidence is read.
List<SupportStorySegment> supportStorySegments(
  RescueRecord record, {
  List<PublicRescueVideo> videos = const [],
  List<CaseUpdate> updates = const [],
}) {
  if (record.kind != 'case' ||
      !{'approved', 'closed'}.contains(record.status)) {
    return const [];
  }
  final photos = supportStoryPhotos(record);
  final result = <SupportStorySegment>[];
  final seenPhotos = <String>{};
  final seenVideos = <String>{};
  final privateOrForeignIds = videos
      .where(
        (video) =>
            video.parentId != record.id ||
            !publicRescueVideoPurposes.contains(video.purpose),
      )
      .map((video) => video.id)
      .toSet();
  void photo(String path, SupportStoryKind kind, {CaseUpdate? update}) {
    if (path.trim().isEmpty || !seenPhotos.add(path)) return;
    result.add(
      SupportStorySegment(
        id: 'photo:$path',
        kind: kind,
        photo: path,
        update: update,
      ),
    );
  }

  void clips(String purpose, SupportStoryKind kind) {
    for (final video in videos) {
      if (video.parentId != record.id ||
          video.purpose != purpose ||
          !publicRescueVideoPurposes.contains(video.purpose) ||
          video.id.trim().isEmpty ||
          video.id != video.id.trim() ||
          privateOrForeignIds.contains(video.id) ||
          !seenVideos.add(video.id)) {
        continue;
      }
      result.add(
        SupportStorySegment(id: 'video:${video.id}', kind: kind, video: video),
      );
    }
  }

  if (photos.isNotEmpty) photo(photos.first, SupportStoryKind.hero);
  final urgencyPhoto = record.publicData['urgency_photo_path'];
  if (urgencyPhoto is String && photos.contains(urgencyPhoto)) {
    photo(urgencyPhoto, SupportStoryKind.urgency);
  }
  clips('urgency', SupportStoryKind.urgency);
  clips('thanks', SupportStoryKind.thanks);
  for (final path in photos.skip(1)) {
    photo(path, SupportStoryKind.casePhoto);
  }
  for (final update in updates) {
    if (update.caseId != record.id || update.publishedAt == null) continue;
    for (final path in update.photos) {
      photo(path, SupportStoryKind.publicUpdate, update: update);
    }
  }
  clips('public_update', SupportStoryKind.publicUpdate);
  clips('farewell', SupportStoryKind.farewell);
  return result;
}

class SupportStories extends ConsumerStatefulWidget {
  const SupportStories({super.key, required this.records});
  final List<RescueRecord> records;
  @override
  ConsumerState<SupportStories> createState() => _SupportStoriesState();
}

class _SupportStoriesState extends ConsumerState<SupportStories>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController progress =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 5200),
      )..addListener(() {
        // Flutter completion status uses elapsed > duration. Reach the
        // endpoint on the frame at 5200 ms rather than waiting another frame.
        if (progress.value >= 1 && !finished && currentVideo == null) next();
      });
  late final queue = widget.records
      .where(
        (r) =>
            r.kind == 'case' &&
            (r.status == 'approved' || r.status == 'closed'),
      )
      .toList();
  int caseIndex = 0, photoIndex = 0;
  bool held = false, manual = false, background = false, displayed = false;
  Offset? pointerStart;
  int? activePointer;
  Timer? holdTimer;
  bool longHeld = false;
  bool finished = false;
  final Set<String> loadedUpdates = {};
  final loadedVideos = <String>{};
  final loadingVideos = <String>{};
  final failedVideos = <String>{};
  final publicVideos = <String, List<PublicRescueVideo>>{};
  final lateSegments = <String, Map<String, List<String>>>{};
  final videoPaused = ValueNotifier<bool>(false);
  final loadingUpdates = <String>{};
  final failedUpdates = <String>{};
  (String, String)? waitingForUpdates;
  final needTypes = <String, Set<String>>{};
  final publicUpdates = <String, List<CaseUpdate>>{};
  RescueRecord get record => queue[caseIndex];
  List<CaseUpdate> get updates => publicUpdates[record.id] ?? const [];
  List<SupportStorySegment> get segments {
    final result = supportStorySegments(
      record,
      videos: publicVideos[record.id] ?? const [],
      updates: updates,
    );
    // A successful retry can reveal an earlier-purpose clip after the user has
    // already reached a later photo. Keep that photo in place, then show the
    // newly recovered segments on the next step instead of jumping or skipping.
    final placements =
        lateSegments[record.id] ?? const <String, List<String>>{};
    for (final placement in placements.entries) {
      final recovered = result
          .where((s) => placement.value.contains(s.id))
          .toList();
      result.removeWhere((s) => placement.value.contains(s.id));
      final anchor = result.indexWhere((s) => s.id == placement.key);
      result.insertAll(anchor < 0 ? result.length : anchor + 1, recovered);
    }
    return result;
  }

  SupportStorySegment? get currentSegment {
    if (queue.isEmpty) return null;
    final items = segments;
    return photoIndex < items.length ? items[photoIndex] : null;
  }

  String? get currentVideo => currentSegment?.video?.id;
  CaseUpdate? get currentUpdate => currentSegment?.update;
  String get currentSegmentId => currentSegment?.id ?? 'empty';

  bool isCurrent(String caseId, String segmentId) =>
      mounted &&
      !finished &&
      queue.isNotEmpty &&
      record.id == caseId &&
      currentSegmentId == segmentId;

  void replacePublicMedia(String id, VoidCallback replace) {
    final active = queue.isNotEmpty && record.id == id;
    final before = active ? segments : const <SupportStorySegment>[];
    final key = active ? currentSegment?.id : null;
    setState(() {
      replace();
      if (!active) return;
      final updated = segments;
      if (key == null) {
        photoIndex = 0;
        if (updated.isNotEmpty) waitingForUpdates = null;
        return;
      }
      final anchor = updated.indexWhere((s) => s.id == key);
      if (anchor < 0) {
        photoIndex = updated.isEmpty
            ? 0
            : photoIndex.clamp(0, updated.length - 1).toInt();
        displayed = false;
        waitingForUpdates = null;
        progress.reset();
        return;
      }
      final known = before.map((s) => s.id).toSet();
      final recovered = updated
          .take(anchor)
          .where((s) => !known.contains(s.id))
          .map((s) => s.id)
          .toList();
      if (recovered.isNotEmpty) {
        final placements = lateSegments.putIfAbsent(id, () => {});
        placements.putIfAbsent(key, () => []).addAll(recovered);
      }
      photoIndex = segments.indexWhere((s) => s.id == key);
    });
  }

  bool get awaitingMedia {
    if (!loadedVideos.contains(record.id)) return true;
    final items = segments;
    final next = photoIndex + 1 < items.length ? items[photoIndex + 1] : null;
    // Public update photos must precede public-update/farewell videos. Earlier
    // photos and urgency/thanks clips can still be viewed while updates load.
    return !loadedUpdates.contains(record.id) &&
        (next == null ||
            next.kind == SupportStoryKind.publicUpdate ||
            next.kind == SupportStoryKind.farewell);
  }

  void advanceWaiting() {
    if (finished ||
        queue.isEmpty ||
        held ||
        background ||
        !TickerMode.valuesOf(context).enabled ||
        waitingForUpdates != (record.id, currentSegmentId) ||
        awaitingMedia) {
      return;
    }
    next();
  }

  Future<void> loadVideos() async {
    if (queue.isEmpty ||
        loadedVideos.contains(record.id) ||
        !loadingVideos.add(record.id)) {
      return;
    }
    final id = record.id;
    final repository = ref.read(rescueVideosRepositoryProvider);
    if (repository == null) {
      loadingVideos.remove(id);
      loadedVideos.add(id);
      return;
    }
    failedVideos.remove(id);
    try {
      final items = await repository.publicVideos(id);
      if (!mounted || finished) return;
      replacePublicMedia(id, () {
        loadingVideos.remove(id);
        loadedVideos.add(id);
        publicVideos[id] = publicRescueVideoMetadata(items, id);
      });
      advanceWaiting();
    } catch (_) {
      if (!mounted || finished) return;
      setState(() {
        loadingVideos.remove(id);
        loadedVideos.add(id);
        failedVideos.add(id);
      });
      advanceWaiting();
    }
  }

  void retryVideos() {
    loadedVideos.remove(record.id);
    loadVideos();
  }

  Future<void> loadUpdates() async {
    if (queue.isEmpty ||
        loadedUpdates.contains(record.id) ||
        !loadingUpdates.add(record.id)) {
      return;
    }
    final id = record.id;
    failedUpdates.remove(id);
    try {
      final result = await ref.read(caseUpdateRepositoryProvider).publicFor(id);
      if (!mounted || finished) return;
      replacePublicMedia(id, () {
        loadingUpdates.remove(id);
        loadedUpdates.add(id);
        publicUpdates[id] = result
            .where((u) => u.caseId == id && u.publishedAt != null)
            .toList();
      });
      advanceWaiting();
    } catch (_) {
      if (!mounted || finished) return;
      setState(() {
        loadingUpdates.remove(id);
        failedUpdates.add(id);
      });
    }
  }

  Future<void> loadNeeds() async {
    if (queue.isEmpty || needTypes.containsKey(record.id)) return;
    final id = record.id;
    final types = <String>{};
    try {
      var page = 1;
      while (mounted && !finished) {
        final result = await ref
            .read(rescueRepositoryProvider)
            .catalog(page, caseId: id);
        for (final expense in result.items) {
          if (expense.kind == 'expense' &&
              expense.parent == id &&
              expense.status == 'approved' &&
              expense.fundedCents < expense.targetCents) {
            final category =
                expense.publicData['category'] ?? expense.publicData['type'];
            if (category is String) types.add(category);
          }
        }
        if (result.items.isEmpty || page * 20 >= result.total) break;
        page++;
      }
      if (mounted && !finished) setState(() => needTypes[id] = types);
    } catch (_) {
      // No icon implies no confirmed public type; never invent a need.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadUpdates();
    loadVideos();
    loadNeeds();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manual =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    resume();
  }

  void resume() {
    videoPaused.value =
        held || background || !TickerMode.valuesOf(context).enabled;
    if (waitingForUpdates != null && !held && !background) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !finished) advanceWaiting();
      });
    }
    if (currentVideo != null) {
      progress.stop();
      return;
    }
    if (!finished &&
        queue.isNotEmpty &&
        displayed &&
        waitingForUpdates == null &&
        !held &&
        !manual &&
        !background &&
        TickerMode.valuesOf(context).enabled) {
      progress.forward();
    } else {
      progress.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    background = state != AppLifecycleState.resumed;
    resume();
  }

  void close([String? detail]) {
    if (finished) return;
    finished = true;
    progress.stop();
    Navigator.of(context).pop(detail);
  }

  void next() {
    if (finished) return;
    if (awaitingMedia) {
      waitingForUpdates = (record.id, currentSegmentId);
      progress.stop();
      setState(() {});
      return;
    }
    waitingForUpdates = null;
    if (photoIndex + 1 < segments.length) {
      setState(() => photoIndex++);
    } else if (caseIndex + 1 < queue.length) {
      setState(() {
        caseIndex++;
        photoIndex = 0;
      });
      loadUpdates();
      loadVideos();
      loadNeeds();
    } else {
      close();
      return;
    }
    displayed = false;
    progress.reset();
    resume();
  }

  void previous() {
    waitingForUpdates = null;
    if (caseIndex == 0 && photoIndex == 0) {
      progress.reset();
      resume();
      return;
    }
    if (photoIndex > 0) {
      setState(() => photoIndex--);
    } else if (caseIndex > 0) {
      setState(() {
        caseIndex--;
        photoIndex = segments.isEmpty ? 0 : segments.length - 1;
      });
    }
    displayed = false;
    progress.reset();
    resume();
  }

  @override
  void dispose() {
    holdTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    progress.dispose();
    videoPaused.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historias')),
        body: const Center(child: Text('No hay fotos públicas disponibles.')),
      );
    }
    if (segments.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historias')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loadingVideos.contains(record.id) ||
                  loadingUpdates.contains(record.id))
                const CircularProgressIndicator()
              else
                const Text('No hay fotos públicas disponibles.'),
              if (failedVideos.contains(record.id))
                TextButton(
                  onPressed: retryVideos,
                  child: const Text('Reintentar videos'),
                ),
              if (caseIndex + 1 < queue.length)
                TextButton(
                  onPressed: next,
                  child: const Text('Siguiente caso'),
                ),
            ],
          ),
        ),
      );
    }
    final visibleSegments = segments;
    final segment = visibleSegments[photoIndex];
    final activeCaseId = record.id;
    final hero = segment.kind == SupportStoryKind.hero;
    return Scaffold(
      backgroundColor: const Color(0xff0d0d0d),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(hero ? 14 : 0),
                  decoration: BoxDecoration(
                    color: hero ? yellow : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(hero ? 22 : 28),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (activePointer != null) return;
                        activePointer = event.pointer;
                        pointerStart = event.position;
                        longHeld = false;
                        holdTimer?.cancel();
                        holdTimer = Timer(
                          const Duration(milliseconds: 350),
                          () => longHeld = true,
                        );
                        held = true;
                        resume();
                      },
                      onPointerCancel: (event) {
                        if (activePointer != event.pointer) return;
                        activePointer = null;
                        holdTimer?.cancel();
                        pointerStart = null;
                        held = false;
                        resume();
                      },
                      onPointerUp: (event) {
                        if (activePointer != event.pointer) return;
                        activePointer = null;
                        holdTimer?.cancel();
                        final start = pointerStart;
                        pointerStart = null;
                        held = false;
                        if (start != null) {
                          final delta = event.position - start;
                          if (delta.dy.abs() >= 72 &&
                              delta.dy.abs() > delta.dx.abs()) {
                            if (delta.dy < 0) {
                              close(record.id);
                            } else {
                              close();
                            }
                            return;
                          }
                        }
                        // The frozen mock restarts a segment on hold release.
                        // Cancellation, lifecycle and accessible pauses retain
                        // their separate resume behavior.
                        if (longHeld &&
                            !manual &&
                            !background &&
                            currentVideo == null) {
                          progress.reset();
                        }
                        resume();
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LayoutBuilder(
                            builder: (surfaceContext, bounds) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (event) {
                                if (longHeld) return;
                                if (event.localPosition.dx <
                                    bounds.maxWidth * .5) {
                                  previous();
                                } else {
                                  next();
                                }
                              },
                              child: currentVideo != null
                                  ? ValueListenableBuilder<bool>(
                                      valueListenable: videoPaused,
                                      builder: (context, paused, _) =>
                                          ModeratedVideo(
                                            key: ValueKey(
                                              '$activeCaseId:${segment.id}',
                                            ),
                                            repository: ref.read(
                                              rescueVideosRepositoryProvider,
                                            )!,
                                            assetId: currentVideo!,
                                            autoplay: !manual,
                                            paused: paused,
                                            semanticLabel:
                                                segment.video!.semanticLabel,
                                            onComplete: () {
                                              if (isCurrent(
                                                activeCaseId,
                                                segment.id,
                                              )) {
                                                next();
                                              }
                                            },
                                            onPlaybackReady: () {
                                              if (!isCurrent(
                                                activeCaseId,
                                                segment.id,
                                              )) {
                                                return;
                                              }
                                              displayed = true;
                                              resume();
                                            },
                                            onProgress: (value) {
                                              if (isCurrent(
                                                activeCaseId,
                                                segment.id,
                                              )) {
                                                progress.value = value.clamp(
                                                  0.0,
                                                  .999999,
                                                );
                                              }
                                            },
                                          ),
                                    )
                                  : _StoryPhoto(
                                      segment.photo!,
                                      isUpdate: currentUpdate != null,
                                      key: ValueKey(
                                        '$activeCaseId:${segment.id}',
                                      ),
                                      semanticLabel:
                                          segment.kind ==
                                              SupportStoryKind.urgency
                                          ? 'Foto de urgencia'
                                          : currentUpdate != null
                                          ? 'Foto del avance público'
                                          : 'Foto pública del caso',
                                      onDisplayed: () {
                                        if (!isCurrent(
                                          activeCaseId,
                                          segment.id,
                                        )) {
                                          return;
                                        }
                                        displayed = true;
                                        resume();
                                      },
                                    ),
                            ),
                          ),
                          const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x730d0d0d),
                                    Color(0xf70d0d0d),
                                  ],
                                  stops: [0.38, 0.7, 1],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: hero ? 6 : 12,
                            left: hero ? 6 : 12,
                            right: hero ? 6 : 12,
                            child: AnimatedBuilder(
                              animation: progress,
                              builder: (_, _) => Row(
                                children: [
                                  for (
                                    var i = 0;
                                    i < visibleSegments.length;
                                    i++
                                  )
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: i < photoIndex
                                              ? 1
                                              : i == photoIndex
                                              ? progress.value
                                              : 0,
                                          minHeight: 3,
                                          color: Colors.white,
                                          backgroundColor: Colors.white38,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: hero ? 0 : 14,
                            child: IconButton(
                              tooltip: 'Cerrar historias',
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x730d0d0d),
                                shape: const CircleBorder(),
                              ),
                              onPressed: close,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: currentVideo == null ? 0 : 64,
                            left: 0,
                            right: 0,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                20,
                                18,
                                22,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (segment.kind == SupportStoryKind.thanks)
                                    Semantics(
                                      label: 'Agradecimiento',
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Da un pequeño gesto,',
                                            style: _thankYouStyle,
                                          ),
                                          SizedBox(height: 4),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(text: 'haz una '),
                                                TextSpan(
                                                  text: 'GRAN',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: .52,
                                                  ),
                                                ),
                                                TextSpan(text: ' diferencia.'),
                                              ],
                                            ),
                                            style: _thankYouStyle,
                                          ),
                                        ],
                                      ),
                                    )
                                  else ...[
                                    Text(
                                      record.title,
                                      style: const TextStyle(
                                        fontSize: 34,
                                        height: 1.05,
                                        letterSpacing: -.68,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                            color: Color(0xa6000000),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (segment.kind ==
                                        SupportStoryKind.urgency) ...[
                                      const SizedBox(height: 8),
                                      Semantics(
                                        label: 'Urgencia',
                                        child: Row(
                                          children: [
                                            SvgPicture.asset(
                                              'assets/profile/icon-alert-circle.svg',
                                              width: 20,
                                              height: 20,
                                              excludeFromSemantics: true,
                                              colorFilter:
                                                  const ColorFilter.mode(
                                                    Color(0xffffb020),
                                                    BlendMode.srcIn,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Flexible(
                                              child: Text(
                                                'Apoyo urgente',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  height: 1.3,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                      offset: Offset(0, 1),
                                                      blurRadius: 2,
                                                      color: Color(0xbf000000),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else if (!hero)
                                      Text(
                                        segment.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                  if (currentUpdate != null)
                                    Text(
                                      currentUpdate!.body,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  if (loadingUpdates.contains(record.id))
                                    const Text(
                                      'Cargando avances…',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  if (failedUpdates.contains(record.id))
                                    TextButton(
                                      onPressed: () {
                                        setState(() {});
                                        loadUpdates();
                                      },
                                      child: const Text('Reintentar avances'),
                                    ),
                                  if (failedVideos.contains(record.id))
                                    TextButton(
                                      onPressed: retryVideos,
                                      child: const Text('Reintentar videos'),
                                    ),
                                  TextButton(
                                    onPressed: () => close(record.id),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final type
                                            in (needTypes[record.id] ??
                                                const <String>{}))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: Semantics(
                                              label: switch (type) {
                                                'food' => 'Alimento',
                                                'medicine' => 'Medicamentos',
                                                'veterinary' => 'Veterinario',
                                                _ => 'Otra necesidad',
                                              },
                                              child:
                                                  [
                                                    'food',
                                                    'medicine',
                                                    'veterinary',
                                                  ].contains(type)
                                                  ? SvgPicture.asset(
                                                      'assets/profile/need-$type.svg',
                                                      width: 22,
                                                      height: 22,
                                                      excludeFromSemantics:
                                                          true,
                                                    )
                                                  : const Icon(
                                                      Icons.pets_outlined,
                                                      size: 22,
                                                      color: Colors.white,
                                                    ),
                                            ),
                                          ),
                                        const Flexible(
                                          child: Text('Conoce su historia'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (segment.kind != SupportStoryKind.thanks &&
                                      segment.kind !=
                                          SupportStoryKind.urgency) ...[
                                    LinearProgressIndicator(
                                      value: record.targetCents <= 0
                                          ? 0
                                          : (record.fundedCents /
                                                    record.targetCents)
                                                .clamp(0.0, 1.0),
                                      color: yellow,
                                      backgroundColor: Colors.white24,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${pesos(record.fundedCents)} de ${pesos(record.targetCents)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                label: 'Historias: siguiente o anterior',
                onIncrease: next,
                onDecrease: previous,
                child: TextButton(
                  onPressed: () => close(record.id),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotatedBox(
                        quarterTurns: 3,
                        child: SvgPicture.asset(
                          'assets/profile/icon-chevron-right.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(child: Text('Desliza hacia arriba')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryPhoto extends ConsumerWidget {
  const _StoryPhoto(
    this.path, {
    super.key,
    required this.onDisplayed,
    required this.isUpdate,
    this.semanticLabel = 'Foto pública del caso',
  });
  final String semanticLabel;
  final String path;
  final bool isUpdate;
  final VoidCallback onDisplayed;
  @override
  Widget build(BuildContext context, WidgetRef ref) => RemotePhoto(
    source: isUpdate
        ? PhotoRef(
            path: path,
            purpose: MediaPurpose.caseUpdatePhoto,
            persistence: PhotoPersistence.ordinary,
            sign: () => ref.read(caseUpdateRepositoryProvider).photoUrl(path),
          )
        : rescuePhotoSource(ref.read(rescueRepositoryProvider), path),
    onDisplayed: onDisplayed,
    semanticLabel: semanticLabel,
    loading: const Center(
      child: CircularProgressIndicator(semanticsLabel: 'Cargando foto'),
    ),
    unavailable: (retry) => Padding(
      // Keep recovery above the bottom case metadata, including at 200% text.
      // The top inset also leaves room for story segments and the close action.
      padding: const EdgeInsets.fromLTRB(12, 56, 12, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Foto no disponible',
              style: TextStyle(color: Colors.white),
            ),
            TextButton(onPressed: retry, child: const Text('Reintentar foto')),
          ],
        ),
      ),
    ),
  );
}
