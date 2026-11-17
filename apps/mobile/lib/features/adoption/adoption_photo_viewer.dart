import 'package:flutter/material.dart';

import 'community_ui.dart';

class AdoptionPhotoViewer extends StatefulWidget {
  const AdoptionPhotoViewer({
    super.key,
    required this.petName,
    required this.photos,
    required this.initialIndex,
  });

  final String petName;
  final List<String> photos;
  final int initialIndex;

  @override
  State<AdoptionPhotoViewer> createState() => _AdoptionPhotoViewerState();
}

class _AdoptionPhotoViewerState extends State<AdoptionPhotoViewer> {
  late int index = widget.initialIndex;
  late final controller = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void moveTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(page);
    } else {
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Cerrar fotos',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          'Fotos de ${widget.petName}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => PageView.builder(
                  controller: controller,
                  itemCount: photos.length,
                  onPageChanged: (page) => setState(() => index = page),
                  itemBuilder: (context, page) => AdoptionPhoto(
                    photos[page],
                    height: constraints.maxHeight,
                    radius: 0,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (photos.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Foto anterior',
                    onPressed: index > 0 ? () => moveTo(index - 1) : null,
                    color: Colors.white,
                    disabledColor: Colors.white38,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Foto ${index + 1} de ${photos.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Siguiente foto',
                    onPressed: index < photos.length - 1
                        ? () => moveTo(index + 1)
                        : null,
                    color: Colors.white,
                    disabledColor: Colors.white38,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
