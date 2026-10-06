import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/navigation.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import '../identity/experience_controller.dart';
import 'community_repository.dart';

class CommunityNav extends ConsumerWidget {
  const CommunityNav(this.index, {super.key, this.selectedPath});
  final int index;
  final String? selectedPath;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(experienceProvider);
    return ListenableBuilder(
      listenable: experience,
      builder: (context, _) {
        final rescuer = experience.value == AccountExperience.rescuer;
        final destinations = rescuer ? rescuerDestinations : donorDestinations;
        final path = GoRouterState.of(context).uri.path;
        final selected =
            selectedPath ??
            (destinations.any((item) => item.path == path) ? path : '/profile');
        return DopmiBottomBar(
          rescuer: rescuer,
          selectedPath: selected,
          onSelected: (destination) {
            final shell = DopmiNavigationHost.of(context);
            if (shell != null) {
              // A shell root can be opened imperatively (for example,
              // Mis match used to push /messages over Adoptar). In that case
              // the visible path and the shell's current branch disagree, so
              // goBranch(currentIndex) is a no-op. Route explicitly whenever
              // the requested destination is already the recorded branch.
              if (shell.currentIndex == destination.branch &&
                  path != destination.path) {
                context.go(destination.path);
              } else {
                shell.goBranch(destination.branch);
              }
            } else {
              context.go(destination.path);
            }
          },
        );
      },
    );
  }
}

class CommunityFrame extends StatelessWidget {
  const CommunityFrame({
    super.key,
    required this.children,
    this.index,
    this.back = true,
    this.showNotifications = true,
    this.showMatches = false,
    this.showAppBar = true,
  });
  final List<Widget> children;
  final int? index;
  final bool back;
  final bool showNotifications;
  final bool showMatches;
  final bool showAppBar;
  @override
  Widget build(BuildContext context) => PageFrame(
    back: back,
    bottomNavigationBar: index == null ? null : CommunityNav(index!),
    showAppBar: showAppBar,
    actions: [
      if (showMatches)
        IconButton(
          tooltip: 'Mis match',
          onPressed: () => context.go('/messages'),
          icon: const Icon(Icons.favorite_border),
        ),
      if (showNotifications)
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_outlined),
        ),
    ],
    children: children,
  );
}

/// Re-reads persisted data on subscription/reconnection, foreground and a bounded fallback interval.
/// Failed reads discard the prior response, including after permissions are revoked.
class LiveSection<T> extends ConsumerStatefulWidget {
  const LiveSection({
    super.key,
    required this.load,
    required this.builder,
    this.tables = const [],
    this.errorMessage,
    this.statusFrame,
  });
  final Future<T> Function() load;
  final Widget Function(T data, VoidCallback refresh) builder;
  final List<String> tables;
  final String Function(Object)? errorMessage;
  final Widget Function(Widget content)? statusFrame;
  @override
  ConsumerState<LiveSection<T>> createState() => _LiveSectionState<T>();
}

class _LiveSectionState<T> extends ConsumerState<LiveSection<T>>
    with WidgetsBindingObserver {
  T? data;
  Object? error;
  bool loading = true, foreground = true;
  int generation = 0;
  Timer? timer;
  VoidCallback? cancel;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    cancel = ref
        .read(communityRepositoryProvider)
        .watch(widget.tables, refresh);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (foreground) refresh();
    });
  }

  Future<void> refresh() async {
    final current = ++generation;
    try {
      final result = await widget.load();
      if (mounted && current == generation) {
        setState(() {
          data = result;
          error = null;
          loading = false;
        });
      }
    } catch (cause) {
      if (mounted && current == generation) {
        setState(() {
          data = null;
          error = cause;
          loading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) refresh();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    cancel?.call();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget frame(Widget content) =>
        widget.statusFrame?.call(content) ?? content;
    if (loading) {
      return frame(
        const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
        ),
      );
    }
    if (error != null) {
      return frame(
        Column(
          children: [
            Notice(
              (widget.errorMessage ?? communityError)(error!),
              isError: true,
            ),
            TextButton(
              onPressed: refresh,
              child: const Text('Volver a intentar'),
            ),
          ],
        ),
      );
    }
    return widget.builder(data as T, refresh);
  }
}

class AdoptionPhoto extends ConsumerWidget {
  const AdoptionPhoto(
    this.path, {
    super.key,
    this.height = 240,
    this.radius = 20,
    this.source,
    this.preview = false,
    this.onDisplayed,
  });
  final String path;
  final PhotoRef? source;
  final bool preview;
  final VoidCallback? onDisplayed;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(communityRepositoryProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: RemotePhoto(
        preview: preview,
        onDisplayed: onDisplayed,
        source: source ?? adoptionPhotoSource(repository, path),
        height: height,
        width: double.infinity,
        semanticLabel: 'Foto de la publicación',
        loading: preview
            ? const ColoredBox(
                color: Color(0xffeeeae5),
                child: Icon(Icons.pets, size: 80),
              )
            : SizedBox(
                height: height,
                child: const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Cargando foto',
                  ),
                ),
              ),
        unavailable: unavailable,
      ),
    );
  }

  Widget unavailable(VoidCallback reload) {
    return Container(
      height: height,
      color: const Color(0xffeee7fc),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth < 120 || constraints.maxHeight < 80
              ? IconButton(
                  tooltip: 'Cargar foto',
                  onPressed: reload,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.refresh),
                )
              : TextButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cargar foto'),
                ),
        ),
      ),
    );
  }
}

PhotoRef adoptionPhotoSource(CommunityRepository repository, String path) =>
    PhotoRef(
      path: path,
      purpose: MediaPurpose.adoptionPhoto,
      persistence: PhotoPersistence.ordinary,
      sign: () => repository.photoUrl(path),
    );

class PageControls extends StatelessWidget {
  const PageControls({
    super.key,
    required this.page,
    required this.total,
    required this.size,
    required this.change,
  });
  final int page, total, size;
  final ValueChanged<int> change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Página anterior',
          onPressed: page > 1 ? () => change(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Página $page de ${((total + size - 1) ~/ size).clamp(1, 999999)}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: page * size < total ? () => change(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

String localDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
