import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rescue_repository.dart';

class RescuePublicPhoto extends ConsumerStatefulWidget {
  const RescuePublicPhoto(
    this.path, {
    super.key,
    this.height = 220,
    this.radius = 20,
    this.compact = false,
  });
  final String path;
  final double height, radius;
  final bool compact;
  @override
  ConsumerState<RescuePublicPhoto> createState() => _RescuePublicPhotoState();
}

class _RescuePublicPhotoState extends ConsumerState<RescuePublicPhoto> {
  late Future<String> url = _load();
  Future<String> _load() {
    final result = Future<String>.sync(
      () => ref.read(rescueRepositoryProvider).fileUrl(widget.path),
    );
    result.ignore();
    return result;
  }

  @override
  void didUpdateWidget(RescuePublicPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) url = _load();
  }

  Widget unavailable() => widget.compact
      ? SizedBox(
          height: widget.height,
          child: Center(
            child: IconButton(
              tooltip: 'Foto no disponible. Reintentar foto',
              onPressed: () => setState(() {
                url = _load();
              }),
              icon: const Icon(Icons.refresh),
            ),
          ),
        )
      : SizedBox(
          height: widget.height,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Foto no disponible'),
                TextButton(
                  onPressed: () => setState(() {
                    url = _load();
                  }),
                  child: const Text('Reintentar foto'),
                ),
              ],
            ),
          ),
        );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.radius),
    child: SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FutureBuilder<String>(
        key: ObjectKey(url),
        future: url,
        builder: (_, snapshot) => snapshot.hasData
            ? Image.network(
                snapshot.data!,
                height: widget.height,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => unavailable(),
              )
            : snapshot.hasError
            ? unavailable()
            : widget.compact
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Cargando foto',
                  ),
                ),
              )
            : const Center(child: Text('Cargando foto…')),
      ),
    ),
  );
}
