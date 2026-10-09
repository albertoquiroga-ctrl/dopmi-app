import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../../core/media/remote_photo.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import 'case_update_repository.dart';
import 'rescue_repository.dart';
import 'rescue_public_photo.dart';

/// Only approved public snapshot photos; never private evidence or receipts.
List<String> supportStoryPhotos(RescueRecord record) =>
    record.status == 'approved'
    ? (record.publicData['photos'] as List? ?? const [])
          .whereType<String>()
          .where((p) => p.trim().isNotEmpty)
          .toSet()
          .toList()
    : const [];

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
        if (progress.value >= 1 && !finished) next();
      });
  late final queue = widget.records
      .where((r) => supportStoryPhotos(r).isNotEmpty)
      .toList();
  int caseIndex = 0, photoIndex = 0;
  bool held = false, manual = false, background = false, displayed = false;
  Offset? pointerStart;
  int? activePointer;
  Timer? holdTimer;
  bool longHeld = false;
  bool finished = false;
  final Set<String> loadedUpdates = {};
  final loadingUpdates = <String>{};
  final failedUpdates = <String>{};
  (String, int)? waitingForUpdates;
  final needTypes = <String, Set<String>>{};
  final publicUpdates = <String, List<CaseUpdate>>{};
  RescueRecord get record => queue[caseIndex];
  List<CaseUpdate> get updates => publicUpdates[record.id] ?? const [];
  List<String> get photos => <String>{
    ...supportStoryPhotos(record),
    ...updates.expand((u) => u.photos),
  }.toList();
  CaseUpdate? get currentUpdate {
    final path = photos[photoIndex];
    if (supportStoryPhotos(record).contains(path)) return null;
    for (final update in updates) {
      if (update.photos.contains(path)) return update;
    }
    return null;
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
      setState(() {
        loadingUpdates.remove(id);
        loadedUpdates.add(id);
        publicUpdates[id] = result
            .where((u) => u.caseId == id && u.publishedAt != null)
            .toList();
      });
      if (waitingForUpdates == (id, photoIndex) && record.id == id) {
        waitingForUpdates = null;
        next();
      }
    } catch (_) {
      if (!mounted || finished) return;
      setState(() {
        loadingUpdates.remove(id);
        failedUpdates.add(id);
        if (waitingForUpdates?.$1 == id) waitingForUpdates = null;
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
    if (photoIndex + 1 >= photos.length && !loadedUpdates.contains(record.id)) {
      waitingForUpdates = (record.id, photoIndex);
      progress.stop();
      setState(() {});
      return;
    }
    waitingForUpdates = null;
    if (photoIndex + 1 < photos.length) {
      setState(() => photoIndex++);
    } else if (caseIndex + 1 < queue.length) {
      setState(() {
        caseIndex++;
        photoIndex = 0;
      });
      loadUpdates();
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
        photoIndex = photos.length - 1;
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
    return Scaffold(
      backgroundColor: const Color(0xff0d0d0d),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: yellow,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
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
                        resume();
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LayoutBuilder(
                            builder: (surfaceContext, bounds) =>
                                GestureDetector(
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
                                  child: _StoryPhoto(
                                    photos[photoIndex],
                                    isUpdate: currentUpdate != null,
                                    key: ValueKey('${record.id}:$photoIndex'),
                                    onDisplayed: () {
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
                            top: 6,
                            left: 6,
                            right: 6,
                            child: AnimatedBuilder(
                              animation: progress,
                              builder: (_, _) => Row(
                                children: [
                                  for (var i = 0; i < photos.length; i++)
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
                            right: 0,
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
                            bottom: 0,
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
                                  Text(
                                    record.title,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      height: 1.05,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
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
  });
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
    semanticLabel: 'Foto pública del caso',
    loading: const Center(
      child: CircularProgressIndicator(semanticsLabel: 'Cargando foto'),
    ),
    unavailable: (retry) => Center(
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
  );
}
