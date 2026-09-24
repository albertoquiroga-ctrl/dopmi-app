import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'community_repository.dart';

class CommunityNav extends StatelessWidget {
  const CommunityNav(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: (i) => context.go(
      ['/adoptions', '/saved', '/my-adoptions', '/messages', '/profile'][i],
    ),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.pets_outlined), label: 'Adoptar'),
      NavigationDestination(
        icon: Icon(Icons.favorite_border),
        label: 'Guardados',
      ),
      NavigationDestination(
        icon: Icon(Icons.add_circle_outline),
        label: 'Publicar',
      ),
      NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        label: 'Mensajes',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Cuenta'),
    ],
  );
}

class CommunityFrame extends StatelessWidget {
  const CommunityFrame({
    super.key,
    required this.children,
    this.index,
    this.back = true,
  });
  final List<Widget> children;
  final int? index;
  final bool back;
  @override
  Widget build(BuildContext context) => PageFrame(
    back: back,
    bottomNavigationBar: index == null ? null : CommunityNav(index!),
    actions: [
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
  });
  final Future<T> Function() load;
  final Widget Function(T data, VoidCallback refresh) builder;
  final List<String> tables;
  final String Function(Object)? errorMessage;
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
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
      );
    }
    if (error != null) {
      return Column(
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
      );
    }
    return widget.builder(data as T, refresh);
  }
}

class AdoptionPhoto extends ConsumerStatefulWidget {
  const AdoptionPhoto(this.path, {super.key, this.height = 240});
  final String path;
  final double height;
  @override
  ConsumerState<AdoptionPhoto> createState() => _AdoptionPhotoState();
}

class _AdoptionPhotoState extends ConsumerState<AdoptionPhoto> {
  late Future<String> url = ref
      .read(communityRepositoryProvider)
      .photoUrl(widget.path);
  @override
  void didUpdateWidget(AdoptionPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      url = ref.read(communityRepositoryProvider).photoUrl(widget.path);
    }
  }

  Widget unavailable() => Container(
    height: widget.height,
    color: const Color(0xffeee7fc),
    child: Center(
      child: TextButton.icon(
        onPressed: () => setState(
          () =>
              url = ref.read(communityRepositoryProvider).photoUrl(widget.path),
        ),
        icon: const Icon(Icons.refresh),
        label: const Text('Cargar foto'),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: FutureBuilder<String>(
      future: url,
      builder: (_, snapshot) {
        if (snapshot.hasError) return unavailable();
        if (!snapshot.hasData) {
          return SizedBox(
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Cargando foto'),
            ),
          );
        }
        return Image.network(
          snapshot.data!,
          height: widget.height,
          width: double.infinity,
          fit: BoxFit.cover,
          semanticLabel: 'Foto de la publicación',
          errorBuilder: (_, _, _) => unavailable(),
        );
      },
    ),
  );
}

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
        Text(
          'Página $page de ${((total + size - 1) ~/ size).clamp(1, 999999)}',
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
